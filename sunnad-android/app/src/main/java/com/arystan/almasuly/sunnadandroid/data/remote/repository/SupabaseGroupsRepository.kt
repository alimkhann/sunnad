package com.arystan.almasuly.sunnadandroid.data.remote.repository

import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.core.model.GroupMember
import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
import com.arystan.almasuly.sunnadandroid.core.model.GroupProgressDisplayMode
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.core.model.HabitCompletion
import com.arystan.almasuly.sunnadandroid.core.model.HabitReminder
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.HabitType
import com.arystan.almasuly.sunnadandroid.core.model.SharedHabit
import com.arystan.almasuly.sunnadandroid.core.rules.StreakCalculator
import com.arystan.almasuly.sunnadandroid.data.remote.generated.GroupMemberRowDto
import com.arystan.almasuly.sunnadandroid.data.remote.generated.GroupRowDto
import com.arystan.almasuly.sunnadandroid.data.remote.generated.GroupSharedHabitRowDto
import com.arystan.almasuly.sunnadandroid.data.remote.generated.HabitRowDto
import com.arystan.almasuly.sunnadandroid.domain.repository.GroupsRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.storage.storage
import io.ktor.client.call.body
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.coroutines.delay
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneOffset
import java.util.UUID

class SupabaseGroupsRepository(
    private val client: SupabaseClient
) : GroupsRepository {
    private var supportsProgressDisplayModeRpc: Boolean? = null
    override suspend fun fetchGroups(): List<Group> {
        val currentUserId = currentUserId()
            ?: throw IllegalStateException("Authentication session is still loading. Please refresh.")
        val today = LocalDate.now(ZoneOffset.UTC)
        val memberships = runCatching {
            client.from("group_members")
            .select {
                filter { eq("user_id", currentUserId.toString()) }
            }
            .decodeList<GroupMemberRowDto>()
        }.getOrElse { error ->
            throw IllegalStateException("Unable to fetch group memberships.", error)
        }

        if (memberships.isEmpty()) return emptyList()

        val habitRows = runCatching {
            client.from("habits")
                .select {
                    filter { eq("archived", false) }
                }
                .decodeList<HabitRowDto>()
        }.getOrDefault(emptyList())
        val habitsById = habitRows.associateBy { it.id.lowercase() }

        val groups = mutableListOf<Group>()
        val groupIds = memberships.map { it.groupId }.distinct()
        for (groupId in groupIds) {
            val groupRow = runCatching {
                client.from("groups")
                .select {
                    filter { eq("id", groupId) }
                }
                .decodeList<GroupRowDto>()
                .firstOrNull()
            }.getOrNull() ?: continue

            val memberRows = runCatching {
                client.from("group_members")
                .select {
                    filter { eq("group_id", groupId) }
                }
                .decodeList<GroupMemberRowDto>()
            }.getOrDefault(emptyList())
            val sharedRows = runCatching {
                client.from("group_shared_habits")
                .select {
                    filter { eq("group_id", groupId) }
                }
                .decodeList<GroupSharedHabitRowDto>()
                .filter { it.shared }
            }.getOrDefault(emptyList())

            val members = memberRows.mapNotNull { member ->
                val memberId = runCatching { UUID.fromString(member.userId) }.getOrNull() ?: return@mapNotNull null
                val profile = runCatching {
                    client.from("profiles")
                    .select {
                        filter { eq("id", member.userId) }
                    }
                    .decodeList<ProfileRow>()
                    .firstOrNull()
                }.getOrNull()

                val memberSharedRows = sharedRows
                    .filter { it.userId == member.userId }
                val memberHabitIds = memberSharedRows.mapNotNull { shared ->
                    runCatching { UUID.fromString(shared.habitId) }.getOrNull()
                }.toSet()
                val completionsByHabit = runCatching {
                    fetchCompletionHistoryByHabit(member.userId, memberHabitIds)
                }.getOrDefault(emptyMap())
                val groupCreated = parseDateOrNull(groupRow.createdAt) ?: today

                val memberSharedWithDue = memberSharedRows.mapNotNull { shared ->
                    val habitId = runCatching { UUID.fromString(shared.habitId) }.getOrNull() ?: return@mapNotNull null
                    val habitRow = habitsById[shared.habitId.lowercase()]
                    val habit = habitRow?.toDomainHabit(habitId) ?: return@mapNotNull (
                        SharedHabit(
                            habitId = habitId,
                            title = "Shared habit",
                            icon = "star.fill",
                            completedToday = false,
                            streak = 0,
                            rollingCompletionPercent = 0
                        ) to false
                    )
                    val history = completionsByHabit[habitId].orEmpty()
                    val streak = StreakCalculator.streak(habit, history, today)
                    val completedToday = history.maxByOrNull { it.updatedAt }?.takeIf { it.dayDate == today }?.isCompleted(habit)
                        ?: false
                    val rollingPercent = rollingCompletionPercent(
                        habit = habit,
                        completions = history,
                        groupCreatedAt = groupCreated,
                        today = today
                    )
                    val sharedHabit = SharedHabit(
                        habitId = habitId,
                        title = habit.name,
                        icon = habit.iconKey ?: habit.icon,
                        completedToday = completedToday,
                        streak = streak,
                        rollingCompletionPercent = rollingPercent
                    )
                    sharedHabit to habit.isDue(today)
                }
                val memberShared = memberSharedWithDue.map { it.first }
                val memberDueToday = memberSharedWithDue.filter { it.second }

                GroupMember(
                    id = memberId,
                    name = profile?.username ?: "Member",
                    avatarUrl = avatarUrlFromPath(profile?.avatarPath),
                    completedToday = memberDueToday.count { it.first.completedToday },
                    totalSharedHabits = memberDueToday.size,
                    sharedHabits = memberShared
                )
            }

            val currentUserSharedIds = sharedRows
                .filter { it.userId == currentUserId.toString() }
                .mapNotNull { runCatching { UUID.fromString(it.habitId) }.getOrNull() }
                .toSet()

            val parsedGroupId = runCatching { UUID.fromString(groupRow.id) }.getOrNull() ?: continue
            val ownerMemberId = runCatching { UUID.fromString(groupRow.ownerId) }.getOrNull() ?: currentUserId

            groups += Group(
                id = parsedGroupId,
                name = groupRow.name,
                code = groupRow.code,
                joinLocked = groupRow.joinLocked,
                members = members,
                sharedHabitIds = currentUserSharedIds,
                ownerMemberId = ownerMemberId,
                currentUserMemberId = currentUserId,
                progressDisplayMode = memberRows
                    .firstOrNull { it.userId == currentUserId.toString() }
                    ?.progressDisplayMode
                    .toGroupProgressDisplayMode()
            )
        }
        return groups
    }

    override suspend fun createGroup(name: String): Group {
        val response = client.postgrest.rpc(
            function = "create_group_with_owner",
            parameters = buildJsonObject { put("group_name", name.trim()) }
        )
        val groupId = parseUuidFromRpcResponse(response.data)
            ?: throw IllegalStateException("Group id missing from create_group_with_owner response.")
        return refreshGroup(groupId)
            ?: throw IllegalStateException("Created group could not be fetched.")
    }

    override suspend fun joinGroup(code: String): Group {
        val response = client.postgrest.rpc(
            function = "join_group_by_code",
            parameters = buildJsonObject { put("invite_code", code.trim().uppercase()) }
        )
        val groupId = parseUuidFromRpcResponse(response.data)
            ?: throw IllegalStateException("Group id missing from join_group_by_code response.")
        return refreshGroup(groupId)
            ?: throw IllegalStateException("Joined group could not be fetched.")
    }

    override suspend fun renameGroup(groupId: UUID, name: String) {
        client.postgrest.rpc(
            function = "rename_group",
            parameters = buildJsonObject {
                put("p_group_id", groupId.toString())
                put("p_name", name.trim())
            }
        )
    }

    override suspend fun setJoinLock(groupId: UUID, locked: Boolean) {
        client.postgrest.rpc(
            function = "set_group_join_lock",
            parameters = buildJsonObject {
                put("p_group_id", groupId.toString())
                put("p_locked", locked)
            }
        )
    }

    override suspend fun rotateInviteCode(groupId: UUID): String {
        val response = client.postgrest.rpc(
            function = "rotate_group_invite_code",
            parameters = buildJsonObject { put("p_group_id", groupId.toString()) }
        )
        return parseStringFromRpcResponse(response.data)
            ?: throw IllegalStateException("Invite code missing from rotate_group_invite_code response.")
    }

    override suspend fun updateSharing(groupId: UUID, habitIds: Set<UUID>) {
        val currentUserId = currentUserId() ?: return
        client.from("group_shared_habits")
            .update(
                value = buildJsonObject { put("shared", false) }
            ) {
                filter {
                    eq("group_id", groupId.toString())
                    eq("user_id", currentUserId.toString())
                }
            }

        if (habitIds.isEmpty()) return

        val validHabitIds = client.from("habits")
            .select {
                filter {
                    eq("user_id", currentUserId.toString())
                    eq("archived", false)
                }
            }
            .decodeList<HabitRowDto>()
            .mapNotNull { runCatching { UUID.fromString(it.id) }.getOrNull() }
            .toSet()
        val filteredIds = habitIds.intersect(validHabitIds)
        if (filteredIds.isEmpty()) return

        val rows = filteredIds.map {
            GroupSharingRow(
                groupId = groupId.toString(),
                userId = currentUserId.toString(),
                habitId = it.toString(),
                shared = true
            )
        }
        client.from("group_shared_habits")
            .upsert(rows) {
                onConflict = "group_id,user_id,habit_id"
            }
    }

    override suspend fun leaveGroup(groupId: UUID) {
        val currentUserId = currentUserId() ?: return
        client.from("group_members")
            .delete {
                filter {
                    eq("group_id", groupId.toString())
                    eq("user_id", currentUserId.toString())
                }
            }
    }

    override suspend fun deleteGroup(groupId: UUID) {
        client.from("groups")
            .delete {
                filter { eq("id", groupId.toString()) }
            }
    }

    override suspend fun kickMember(groupId: UUID, memberUserId: UUID) {
        client.from("group_members")
            .delete {
                filter {
                    eq("group_id", groupId.toString())
                    eq("user_id", memberUserId.toString())
                }
            }
    }

    override suspend fun setProgressDisplayMode(groupId: UUID, mode: GroupProgressDisplayMode) {
        if (supportsProgressDisplayModeRpc == false) return
        try {
            client.postgrest.rpc(
                function = "set_group_progress_display_mode",
                parameters = buildJsonObject {
                    put("p_group_id", groupId.toString())
                    put("p_mode", mode.toStorageValue())
                }
            )
            supportsProgressDisplayModeRpc = true
        } catch (error: Throwable) {
            if (isMissingProgressDisplayModeRpc(error)) {
                // Older or partially-migrated backends may not expose this RPC yet.
                supportsProgressDisplayModeRpc = false
                return
            }
            throw error
        }
    }

    override suspend fun refreshGroup(groupId: UUID): Group? {
        return fetchGroups().firstOrNull { it.id == groupId }
    }

    override suspend fun sendNudge(groupId: UUID, toUserId: UUID, habitId: UUID): GroupNudgeStatus {
        val payload = buildJsonObject {
            put("group_id", groupId.toString())
            put("to_user_id", toUserId.toString())
            put("habit_id", habitId.toString())
        }
        return runCatching {
            val parsed = invokeNudgeFunction(payload)
            mapNudgeStatus(parsed.status)
        }.getOrDefault(GroupNudgeStatus.ERROR)
    }

    private suspend fun invokeNudgeFunction(payload: JsonObject): NudgeFunctionResponse {
        return runCatching { callNudgeFunction(payload) }
            .recoverCatching { error ->
                if (isUnauthorized(error)) {
                    runCatching { client.auth.refreshCurrentSession() }
                    callNudgeFunction(payload)
                } else {
                    throw error
                }
            }
            .getOrThrow()
    }

    private suspend fun callNudgeFunction(payload: JsonObject): NudgeFunctionResponse {
        val response = client.functions.invoke(
            function = "send-nudge-push",
            body = payload,
            headers = Headers.build {
                append(HttpHeaders.ContentType, "application/json")
            }
        )
        return response.body()
    }

    private fun isUnauthorized(error: Throwable): Boolean {
        val message = error.message.orEmpty().lowercase()
        return message.contains("401") || message.contains("unauthorized")
    }

    private suspend fun currentUserId(): UUID? {
        repeat(4) { attempt ->
            val direct = client.auth.currentUserOrNull()?.id ?: client.auth.currentSessionOrNull()?.user?.id
            if (!direct.isNullOrBlank()) {
                return runCatching { UUID.fromString(direct) }.getOrNull()
            }

            if (attempt == 0) {
                runCatching { client.auth.refreshCurrentSession() }
            }
            delay(200)
        }
        return null
    }

    private fun avatarUrlFromPath(path: String?): String? {
        val trimmed = path?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
        return runCatching {
            client.storage.from("avatars").publicUrl(trimmed)
        }.getOrDefault(trimmed)
    }

    private suspend fun fetchCompletionHistoryByHabit(
        userId: String,
        habitIds: Set<UUID>
    ): Map<UUID, List<HabitCompletion>> {
        if (habitIds.isEmpty()) return emptyMap()
        val rows = client.from("habit_completions")
            .select {
                filter { eq("user_id", userId) }
            }
            .decodeList<CompletionHistoryRow>()

        return rows.mapNotNull { row ->
            val habitId = runCatching { UUID.fromString(row.habitId) }.getOrNull() ?: return@mapNotNull null
            if (!habitIds.contains(habitId)) return@mapNotNull null
            val day = parseDateOrNull(row.dayDate) ?: return@mapNotNull null
            val updatedAt = parseInstantOrNow(row.updatedAt)
            val completedAt = row.completedAt?.let(::parseInstantOrNow)
            HabitCompletion(
                habitId = habitId,
                dayDate = day,
                value = row.value.coerceAtLeast(0),
                completedAt = completedAt,
                updatedAt = updatedAt
            )
        }.groupBy { it.habitId }
    }

    private fun rollingCompletionPercent(
        habit: Habit,
        completions: List<HabitCompletion>,
        groupCreatedAt: LocalDate,
        today: LocalDate
    ): Int {
        val ageDays = kotlin.math.max(1L, java.time.temporal.ChronoUnit.DAYS.between(groupCreatedAt, today) + 1L)
        val windowDays = kotlin.math.min(40L, ageDays)
        val startDate = today.minusDays(windowDays - 1)
        val completionByDay = completions
            .groupBy { it.dayDate }
            .mapValues { (_, rows) -> rows.maxByOrNull { it.updatedAt } }

        var dueCount = 0
        var completedCount = 0
        var day = startDate
        while (!day.isAfter(today)) {
            if (habit.isDue(day)) {
                dueCount += 1
                val completion = completionByDay[day]
                if (completion != null && completion.isCompleted(habit)) {
                    completedCount += 1
                }
            }
            day = day.plusDays(1)
        }
        if (dueCount == 0) return 0
        return ((completedCount.toDouble() / dueCount.toDouble()) * 100.0).toInt()
    }

    private fun HabitRowDto.toDomainHabit(id: UUID): Habit {
        val schedule = HabitSchedule.fromStorage(schedule, weekdays.toSet())
        val reminder = reminderTime?.let { time ->
            parseLocalTimeOrNull(time)?.let { HabitReminder(hour = it.hour, minute = it.minute) }
        }
        val habitType = when (type.lowercase()) {
            "dhikr" -> HabitType.DHIKR
            else -> HabitType.BINARY
        }
        val categoryValue = presetCategory?.let(::parseCategory) ?: HabitCategoryValue.SPIRITUAL
        return Habit(
            id = id,
            name = name,
            icon = icon ?: "star.fill",
            iconKey = iconKey,
            category = categoryValue,
            categoryCustom = categoryCustom?.trim()?.takeUnless { it.isNullOrEmpty() },
            type = habitType,
            targetCount = targetCount,
            schedule = schedule,
            reminder = reminder,
            sortOrder = sortOrder,
            archived = archived,
            createdAt = parseLocalDateTimeOrNow(createdAt),
            updatedAt = parseLocalDateTimeOrNow(updatedAt)
        )
    }

    private fun parseDateOrNull(raw: String?): LocalDate? {
        if (raw.isNullOrBlank()) return null
        return runCatching { LocalDate.parse(raw) }.getOrNull()
            ?: runCatching { Instant.parse(raw).atZone(ZoneOffset.UTC).toLocalDate() }.getOrNull()
    }

    private fun parseInstantOrNow(raw: String): Instant {
        return runCatching { Instant.parse(raw) }.getOrElse { Instant.now() }
    }

    private fun parseLocalDateTimeOrNow(raw: String): LocalDateTime {
        return runCatching { LocalDateTime.parse(raw) }.getOrElse {
            runCatching { Instant.parse(raw).atZone(ZoneOffset.UTC).toLocalDateTime() }
                .getOrElse { LocalDateTime.now() }
        }
    }

    private fun parseLocalTimeOrNull(raw: String): LocalTime? {
        return runCatching {
            when {
                raw.contains(":") -> LocalTime.parse(raw.take(8))
                else -> null
            }
        }.getOrNull()
    }

    private fun parseCategory(raw: String): HabitCategoryValue {
        return when (raw.lowercase()) {
            "physical" -> HabitCategoryValue.PHYSICAL
            "social" -> HabitCategoryValue.SOCIAL
            "financial" -> HabitCategoryValue.FINANCIAL
            "learning" -> HabitCategoryValue.LEARNING
            "family" -> HabitCategoryValue.FAMILY
            "work" -> HabitCategoryValue.WORK
            "hobby" -> HabitCategoryValue.HOBBY
            else -> HabitCategoryValue.SPIRITUAL
        }
    }

    private fun isMissingProgressDisplayModeRpc(error: Throwable): Boolean {
        val lower = error.message.orEmpty().lowercase()
        return "set_group_progress_display_mode" in lower && (
            "pgrst202" in lower ||
                "schema cache" in lower ||
                "no matches were found" in lower ||
                "function public.set_group_progress_display_mode" in lower
            )
    }

    companion object {
        private val uuidRegex = Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")

        internal fun parseUuidFromRpcResponse(raw: String): UUID? {
            val normalized = parseStringFromRpcResponse(raw) ?: return null
            return runCatching { UUID.fromString(normalized) }.getOrNull()
                ?: uuidRegex.find(raw)?.value?.let { runCatching { UUID.fromString(it) }.getOrNull() }
        }

        internal fun parseStringFromRpcResponse(raw: String): String? {
            val trimmed = raw.trim()
            if (trimmed.isBlank() || trimmed == "null") return null

            val parsed = runCatching { Json.parseToJsonElement(trimmed) }.getOrNull()
            if (parsed != null) {
                return parseStringFromJsonElement(parsed)
            }

            if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.length >= 2) {
                return trimmed.substring(1, trimmed.lastIndex)
            }
            return trimmed
        }

        private fun parseStringFromJsonElement(element: JsonElement): String? {
            return when (element) {
                is JsonPrimitive -> element.contentOrNull
                is JsonArray -> element.firstNotNullOfOrNull(::parseStringFromJsonElement)
                is JsonObject -> {
                    val preferredKeys = listOf(
                        "id",
                        "group_id",
                        "invite_code",
                        "code",
                        "value",
                        "result"
                    )
                    preferredKeys.firstNotNullOfOrNull { key ->
                        element[key]?.let(::parseStringFromJsonElement)
                    } ?: element.values.firstNotNullOfOrNull(::parseStringFromJsonElement)
                }
                else -> null
            }
        }

        internal fun mapNudgeStatus(status: String): GroupNudgeStatus {
            return when (status.lowercase()) {
                "sent" -> GroupNudgeStatus.SENT
                "duplicate" -> GroupNudgeStatus.DUPLICATE
                "forbidden" -> GroupNudgeStatus.FORBIDDEN
                else -> GroupNudgeStatus.ERROR
            }
        }

        private fun String?.toGroupProgressDisplayMode(): GroupProgressDisplayMode {
            return when (this?.lowercase()) {
                "streak" -> GroupProgressDisplayMode.STREAK
                else -> GroupProgressDisplayMode.PERCENT
            }
        }

        private fun GroupProgressDisplayMode.toStorageValue(): String {
            return when (this) {
                GroupProgressDisplayMode.PERCENT -> "percent"
                GroupProgressDisplayMode.STREAK -> "streak"
            }
        }
    }
}

@Serializable
private data class ProfileRow(
    val username: String? = null,
    @SerialName("avatar_path") val avatarPath: String? = null
)

@Serializable
private data class GroupSharingRow(
    @SerialName("group_id") val groupId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("habit_id") val habitId: String,
    val shared: Boolean
)

@Serializable
private data class CompletionHistoryRow(
    @SerialName("habit_id") val habitId: String,
    @SerialName("day_date") val dayDate: String,
    val value: Int,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
private data class NudgeFunctionResponse(
    val status: String,
    val error: String? = null,
    @SerialName("nudge_id") val nudgeId: String? = null,
    val delivered: Boolean? = null
)
