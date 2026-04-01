package com.arystan.almasuly.sunnadandroid.sync

import com.arystan.almasuly.sunnadandroid.core.local.OwnerScope
import com.arystan.almasuly.sunnadandroid.core.local.OwnerScopeResolver
import com.arystan.almasuly.sunnadandroid.data.local.dao.CompletionDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.GroupDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.HabitDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.OutboxDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.QuoteDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.SavedQuoteDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.SyncCursorDao
import com.arystan.almasuly.sunnadandroid.data.local.entity.OutboxEventEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.QuoteEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.SavedQuoteEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.SyncCursorEntity
import com.arystan.almasuly.sunnadandroid.data.local.mappers.completionStorageKey
import com.arystan.almasuly.sunnadandroid.features.habits.canonicalHabitIconKey
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.Instant
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.UUID

interface SyncCoordinator {
    suspend fun setSignedInUserId(userId: UUID?)
    suspend fun promoteGuestDataIfNeeded(toUserId: UUID)
    suspend fun promoteLocalDataIfNeeded()
    suspend fun runSyncCycle(trigger: SyncTrigger)
    suspend fun enqueueHabitUpsert(habitId: UUID)
    suspend fun enqueueHabitDelete(habitId: UUID)
    suspend fun enqueueCompletionUpsert(habitId: UUID, dayDate: LocalDate)
    suspend fun enqueueSavedQuoteInsert(quoteId: UUID)
    suspend fun enqueueSavedQuoteDelete(quoteId: UUID)
    suspend fun enqueueGroupSharedHabitUpsert(groupId: UUID, habitId: UUID, shared: Boolean)
}

class NoOpSyncCoordinator : SyncCoordinator {
    override suspend fun setSignedInUserId(userId: UUID?) = Unit
    override suspend fun promoteGuestDataIfNeeded(toUserId: UUID) = Unit
    override suspend fun promoteLocalDataIfNeeded() = Unit
    override suspend fun runSyncCycle(trigger: SyncTrigger) = Unit
    override suspend fun enqueueHabitUpsert(habitId: UUID) = Unit
    override suspend fun enqueueHabitDelete(habitId: UUID) = Unit
    override suspend fun enqueueCompletionUpsert(habitId: UUID, dayDate: LocalDate) = Unit
    override suspend fun enqueueSavedQuoteInsert(quoteId: UUID) = Unit
    override suspend fun enqueueSavedQuoteDelete(quoteId: UUID) = Unit
    override suspend fun enqueueGroupSharedHabitUpsert(groupId: UUID, habitId: UUID, shared: Boolean) = Unit
}

class SupabaseSyncCoordinator(
    private val outboxDao: OutboxDao,
    private val syncCursorDao: SyncCursorDao,
    private val ownerScopeResolver: OwnerScopeResolver,
    private val habitDao: HabitDao,
    private val completionDao: CompletionDao,
    private val quoteDao: QuoteDao,
    private val savedQuoteDao: SavedQuoteDao,
    private val groupDao: GroupDao,
    private val client: SupabaseClient?
) : SyncCoordinator {
    private val json = Json { ignoreUnknownKeys = true }
    private val maxAttempts = 5
    private var activeUserId: UUID? = null
    private var isRunning = false

    override suspend fun setSignedInUserId(userId: UUID?) {
        activeUserId = userId
    }

    override suspend fun promoteGuestDataIfNeeded(toUserId: UUID) {
        val guestScope = OwnerScope.Guest.rawValue
        val userScope = OwnerScope.User(toUserId).rawValue

        habitDao.fetchByScope(guestScope).forEach { guest ->
            habitDao.upsert(
                guest.copy(
                    ownerScope = userScope,
                    updatedAtEpochMillis = System.currentTimeMillis()
                )
            )
        }

        completionDao.fetchByScope(guestScope).forEach { guest ->
            val nextId = completionStorageKey(
                ownerScope = userScope,
                habitId = UUID.fromString(guest.habitId),
                dayDateIso = guest.dayDateIso
            )
            completionDao.upsert(
                guest.copy(
                    id = nextId,
                    ownerScope = userScope,
                    updatedAtEpochMillis = System.currentTimeMillis()
                )
            )
        }

        savedQuoteDao.fetchByScope(guestScope).forEach { guest ->
            savedQuoteDao.upsert(
                guest.copy(
                    ownerScope = userScope
                )
            )
        }

        outboxDao.fetchPending(guestScope).forEach { event ->
            outboxDao.insert(event.copy(id = 0, ownerScope = userScope))
            outboxDao.delete(event.id)
        }
    }

    override suspend fun promoteLocalDataIfNeeded() = Unit

    override suspend fun runSyncCycle(trigger: SyncTrigger) {
        trigger.rawName()
        val userId = activeUserId ?: return
        val syncClient = client ?: return
        if (isRunning) return
        isRunning = true
        try {
            val ownerScope = ownerScopeResolver.currentOwnerScopeRaw
            val pending = outboxDao.fetchPending(ownerScope)
            pending.forEach { event ->
                val result = runCatching { pushEvent(syncClient, userId, ownerScope, event) }
                if (result.isSuccess) {
                    outboxDao.delete(event.id)
                } else {
                    outboxDao.incrementAttempts(event.id)
                    if (event.attempts + 1 >= maxAttempts) {
                        outboxDao.delete(event.id)
                    }
                }
            }
            pullRemoteState(syncClient, userId, ownerScope)
            syncCursorDao.upsert(
                SyncCursorEntity(
                    resource = "last_sync_epoch_millis",
                    cursorEpochMillis = System.currentTimeMillis()
                )
            )
        } finally {
            isRunning = false
        }
    }

    override suspend fun enqueueHabitUpsert(habitId: UUID) {
        enqueueEvent(
            type = OutboxEventType.UPSERT_HABIT,
            payload = buildJsonObject {
                put("habit_id", habitId.toString())
            }
        )
    }

    override suspend fun enqueueHabitDelete(habitId: UUID) {
        enqueueEvent(
            type = OutboxEventType.DELETE_HABIT,
            payload = buildJsonObject {
                put("habit_id", habitId.toString())
            }
        )
    }

    override suspend fun enqueueCompletionUpsert(habitId: UUID, dayDate: LocalDate) {
        enqueueEvent(
            type = OutboxEventType.UPSERT_COMPLETION,
            payload = buildJsonObject {
                put("habit_id", habitId.toString())
                put("day_date", dayDate.toString())
            }
        )
    }

    override suspend fun enqueueSavedQuoteInsert(quoteId: UUID) {
        enqueueEvent(
            type = OutboxEventType.INSERT_SAVED_QUOTE,
            payload = buildJsonObject {
                put("quote_id", quoteId.toString())
            }
        )
    }

    override suspend fun enqueueSavedQuoteDelete(quoteId: UUID) {
        enqueueEvent(
            type = OutboxEventType.DELETE_SAVED_QUOTE,
            payload = buildJsonObject {
                put("quote_id", quoteId.toString())
            }
        )
    }

    override suspend fun enqueueGroupSharedHabitUpsert(groupId: UUID, habitId: UUID, shared: Boolean) {
        enqueueEvent(
            type = OutboxEventType.UPSERT_GROUP_SHARED_HABIT,
            payload = buildJsonObject {
                put("group_id", groupId.toString())
                put("habit_id", habitId.toString())
                put("shared", shared)
            }
        )
    }

    private suspend fun enqueueEvent(type: OutboxEventType, payload: kotlinx.serialization.json.JsonObject) {
        outboxDao.insert(
            OutboxEventEntity(
                ownerScope = ownerScopeResolver.currentOwnerScopeRaw,
                eventType = type.name,
                payloadJson = payload.toString(),
                createdAtEpochMillis = System.currentTimeMillis(),
                attempts = 0
            )
        )
    }

    private suspend fun pushEvent(
        syncClient: SupabaseClient,
        userId: UUID,
        ownerScope: String,
        event: OutboxEventEntity
    ) {
        when (runCatching { OutboxEventType.valueOf(event.eventType) }.getOrNull()) {
            OutboxEventType.UPSERT_HABIT -> {
                val payload = json.parseToJsonElement(event.payloadJson).jsonObject
                val habitId = payload["habit_id"]?.jsonPrimitive?.contentOrNull ?: return
                val local = habitDao.findById(ownerScope, habitId) ?: return
                val weekdays = local.weekdaysIsoCsv.split(",")
                    .mapNotNull { value -> value.trim().toIntOrNull() }

                syncClient.from("habits").upsert(
                    value = buildJsonObject {
                        put("id", local.id)
                        put("user_id", userId.toString())
                        put("name", local.name)
                        put("icon", local.icon)
                        put("icon_key", local.iconKey ?: canonicalHabitIconKey(local.icon, local.name))
                        put("preset_category", local.category.lowercase())
                        put("category_custom", local.categoryCustom)
                        put("type", local.type.lowercase())
                        put("target_count", local.targetCount)
                        put("schedule", local.scheduleFrequency)
                        put("weekdays", weekdays.joinToString(prefix = "{", postfix = "}"))
                        put("reminder_enabled", local.reminderHour != null && local.reminderMinute != null)
                        put("reminder_time", local.reminderTime())
                        put("sort_order", local.sortOrder)
                        put("archived", local.archived)
                        put("created_at", local.createdAtEpochMillis.toIsoTimestamp())
                        put("updated_at", local.updatedAtEpochMillis.toIsoTimestamp())
                    }
                )
            }

            OutboxEventType.DELETE_HABIT -> {
                val payload = json.parseToJsonElement(event.payloadJson).jsonObject
                val habitId = payload["habit_id"]?.jsonPrimitive?.contentOrNull ?: return
                syncClient.from("habits").delete {
                    filter {
                        eq("id", habitId)
                        eq("user_id", userId.toString())
                    }
                }
            }

            OutboxEventType.UPSERT_COMPLETION -> {
                val payload = json.parseToJsonElement(event.payloadJson).jsonObject
                val habitId = payload["habit_id"]?.jsonPrimitive?.contentOrNull ?: return
                val dayDate = payload["day_date"]?.jsonPrimitive?.contentOrNull ?: return
                val key = completionStorageKey(ownerScope, UUID.fromString(habitId), dayDate)
                val local = completionDao.findById(key) ?: return

                syncClient.from("habit_completions").upsert(
                    value = buildJsonObject {
                        put("user_id", userId.toString())
                        put("habit_id", local.habitId)
                        put("day_date", local.dayDateIso)
                        put("value", local.value)
                        put("completed_at", local.completedAtEpochMillis?.toIsoTimestamp())
                        put("updated_at", local.updatedAtEpochMillis.toIsoTimestamp())
                    }
                )
            }

            OutboxEventType.INSERT_SAVED_QUOTE -> {
                val payload = json.parseToJsonElement(event.payloadJson).jsonObject
                val quoteId = payload["quote_id"]?.jsonPrimitive?.contentOrNull ?: return
                val local = savedQuoteDao.findByQuoteId(ownerScope, quoteId) ?: return

                syncClient.from("saved_quotes").upsert(
                    value = buildJsonObject {
                        put("user_id", userId.toString())
                        put("quote_id", quoteId)
                        put("saved_at", local.savedAtEpochMillis.toIsoTimestamp())
                    }
                )
            }

            OutboxEventType.DELETE_SAVED_QUOTE -> {
                val payload = json.parseToJsonElement(event.payloadJson).jsonObject
                val quoteId = payload["quote_id"]?.jsonPrimitive?.contentOrNull ?: return
                syncClient.from("saved_quotes").delete {
                    filter {
                        eq("user_id", userId.toString())
                        eq("quote_id", quoteId)
                    }
                }
            }

            OutboxEventType.UPSERT_GROUP_SHARED_HABIT -> {
                val payload = json.parseToJsonElement(event.payloadJson).jsonObject
                val groupId = payload["group_id"]?.jsonPrimitive?.contentOrNull ?: return
                val habitId = payload["habit_id"]?.jsonPrimitive?.contentOrNull ?: return
                val shared = payload["shared"]?.jsonPrimitive?.contentOrNull?.toBooleanStrictOrNull() ?: false

                syncClient.from("group_shared_habits").upsert(
                    value = buildJsonObject {
                        put("group_id", groupId)
                        put("user_id", userId.toString())
                        put("habit_id", habitId)
                        put("shared", shared)
                    }
                )
            }

            null -> Unit
        }
    }

    private fun Long.toIsoTimestamp(): String {
        return java.time.Instant.ofEpochMilli(this).atOffset(ZoneOffset.UTC)
            .format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
    }

    private suspend fun pullRemoteState(syncClient: SupabaseClient, userId: UUID, ownerScope: String) {
        val habits = syncClient.from("habits")
            .select {
                filter { eq("user_id", userId.toString()) }
            }
            .decodeList<RemoteHabitRow>()
        habits.forEach { remote ->
            val remoteUpdatedAt = remote.updatedAt.toEpochMillisSafe()
            val local = habitDao.findById(ownerScope, remote.id)
            // Last-write-wins: skip if local version is newer than remote
            if (local != null && local.updatedAtEpochMillis > remoteUpdatedAt) return@forEach

            val reminder = remote.reminderTime?.let { parseReminder(it) }
            habitDao.upsert(
                com.arystan.almasuly.sunnadandroid.data.local.entity.HabitEntity(
                    id = remote.id,
                    ownerScope = ownerScope,
                    name = remote.name,
                    icon = remote.icon ?: remote.iconKey ?: "check_circle",
                    iconKey = remote.iconKey ?: remote.icon,
                    category = remote.presetCategory?.uppercase() ?: "SPIRITUAL",
                    categoryCustom = remote.categoryCustom,
                    type = remote.type.uppercase(),
                    targetCount = remote.targetCount,
                    scheduleFrequency = remote.schedule,
                    weekdaysIsoCsv = remote.weekdays.joinToString(","),
                    reminderHour = reminder?.first,
                    reminderMinute = reminder?.second,
                    selectedDhikrKey = local?.selectedDhikrKey ?: com.arystan.almasuly.sunnadandroid.core.model.Habit.DEFAULT_DHIKR_KEY,
                    dhikrCountsJson = local?.dhikrCountsJson ?: "{}",
                    sortOrder = remote.sortOrder,
                    archived = remote.archived,
                    createdAtEpochMillis = remote.createdAt.toEpochMillisSafe(),
                    updatedAtEpochMillis = remoteUpdatedAt
                )
            )
        }

        val completions = syncClient.from("habit_completions")
            .select {
                filter { eq("user_id", userId.toString()) }
            }
            .decodeList<RemoteCompletionRow>()
        completions.forEach { remote ->
            val remoteUpdatedAt = remote.updatedAt.toEpochMillisSafe()
            val id = completionStorageKey(ownerScope, UUID.fromString(remote.habitId), remote.dayDate)
            val local = completionDao.findById(id)
            // Last-write-wins: skip if local version is newer than remote
            if (local != null && local.updatedAtEpochMillis > remoteUpdatedAt) return@forEach

            completionDao.upsert(
                com.arystan.almasuly.sunnadandroid.data.local.entity.CompletionEntity(
                    id = id,
                    ownerScope = ownerScope,
                    habitId = remote.habitId,
                    dayDateIso = remote.dayDate,
                    value = remote.value,
                    completedAtEpochMillis = remote.completedAt?.toEpochMillisSafe(),
                    updatedAtEpochMillis = remoteUpdatedAt
                )
            )
        }

        val remoteQuotes = syncClient.from("quotes")
            .select {
                filter { eq("active", true) }
            }
            .decodeList<RemoteQuoteRow>()
        if (remoteQuotes.isNotEmpty()) {
            quoteDao.replaceAll(
                remoteQuotes.mapIndexed { index, remote ->
                    QuoteEntity(
                        id = remote.id,
                        locale = remote.locale.ifBlank { "en" },
                        text = remote.text,
                        source = remote.source,
                        sortOrder = remote.sortOrder ?: index,
                        active = remote.active,
                        createdAtEpochMillis = remote.createdAt.toEpochMillisSafe(),
                        updatedAtEpochMillis = remote.updatedAt.toEpochMillisSafe()
                    )
                }
            )
        }
        val quotesById = remoteQuotes.associateBy { it.id.lowercase() }

        val savedQuotes = syncClient.from("saved_quotes")
            .select {
                filter { eq("user_id", userId.toString()) }
            }
            .decodeList<RemoteSavedQuoteRow>()

        savedQuotes.forEach { remote ->
            val quote = quotesById[remote.quoteId.lowercase()]
            savedQuoteDao.upsert(
                SavedQuoteEntity(
                    id = remote.quoteId,
                    ownerScope = ownerScope,
                    quoteId = remote.quoteId,
                    text = quote?.text ?: "",
                    author = quote?.source ?: "Adat",
                    savedAtEpochMillis = remote.savedAt.toEpochMillisSafe()
                )
            )
        }
    }

    private fun parseReminder(value: String): Pair<Int, Int>? {
        val parsed = runCatching { LocalTime.parse(value) }.getOrNull() ?: return null
        return parsed.hour to parsed.minute
    }

    private fun com.arystan.almasuly.sunnadandroid.data.local.entity.HabitEntity.reminderTime(): String? {
        val hour = reminderHour ?: return null
        val minute = reminderMinute ?: return null
        return "%02d:%02d:00".format(hour.coerceIn(0, 23), minute.coerceIn(0, 59))
    }

    private fun SyncTrigger.rawName(): String = name

    private fun String.toEpochMillisSafe(): Long {
        val parsedInstant = runCatching { Instant.parse(this) }.getOrNull()
        if (parsedInstant != null) return parsedInstant.toEpochMilli()
        val parsedDateTime = runCatching { LocalDateTime.parse(this) }.getOrNull()
        if (parsedDateTime != null) return parsedDateTime.toInstant(ZoneOffset.UTC).toEpochMilli()
        return System.currentTimeMillis()
    }
}

@Serializable
private data class RemoteHabitRow(
    val id: String,
    val name: String,
    val icon: String? = null,
    @SerialName("icon_key") val iconKey: String? = null,
    @SerialName("preset_category") val presetCategory: String? = null,
    @SerialName("category_custom") val categoryCustom: String? = null,
    val type: String,
    @SerialName("target_count") val targetCount: Int? = null,
    val schedule: String,
    val weekdays: List<Int> = emptyList(),
    @SerialName("reminder_time") val reminderTime: String? = null,
    @SerialName("sort_order") val sortOrder: Int = 0,
    val archived: Boolean = false,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
private data class RemoteCompletionRow(
    @SerialName("habit_id") val habitId: String,
    @SerialName("day_date") val dayDate: String,
    val value: Int,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
private data class RemoteSavedQuoteRow(
    @SerialName("quote_id") val quoteId: String,
    @SerialName("saved_at") val savedAt: String
)

@Serializable
private data class RemoteQuoteRow(
    val id: String,
    val locale: String = "en",
    val text: String,
    val source: String? = null,
    @SerialName("sort_order") val sortOrder: Int? = null,
    val active: Boolean = true,
    @SerialName("created_at") val createdAt: String = "",
    @SerialName("updated_at") val updatedAt: String = ""
)
