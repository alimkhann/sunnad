package com.arystan.almasuly.sunnadandroid.data.remote.repository

import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.core.model.GroupMember
import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
import com.arystan.almasuly.sunnadandroid.core.model.SharedHabit
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
import java.util.UUID

class SupabaseGroupsRepository(
    private val client: SupabaseClient
) : GroupsRepository {
    override suspend fun fetchGroups(): List<Group> {
        val currentUserId = currentUserId() ?: return emptyList()
        val memberships = client.from("group_members")
            .select {
                filter { eq("user_id", currentUserId.toString()) }
            }
            .decodeList<GroupMemberRowDto>()

        if (memberships.isEmpty()) return emptyList()

        val groups = mutableListOf<Group>()
        val groupIds = memberships.map { it.groupId }.distinct()
        for (groupId in groupIds) {
            val groupRow = client.from("groups")
                .select {
                    filter { eq("id", groupId) }
                }
                .decodeList<GroupRowDto>()
                .firstOrNull()
                ?: continue

            val memberRows = client.from("group_members")
                .select {
                    filter { eq("group_id", groupId) }
                }
                .decodeList<GroupMemberRowDto>()

            val sharedRows = client.from("group_shared_habits")
                .select {
                    filter { eq("group_id", groupId) }
                }
                .decodeList<GroupSharedHabitRowDto>()
                .filter { it.shared }

            val habitRows = client.from("habits")
                .select {
                    filter { eq("archived", false) }
                }
                .decodeList<HabitRowDto>()
            val habitsById = habitRows.associateBy { it.id.lowercase() }

            val members = memberRows.map { member ->
                val profile = client.from("profiles")
                    .select {
                        filter { eq("id", member.userId) }
                    }
                    .decodeList<ProfileRow>()
                    .firstOrNull()

                val memberShared = sharedRows
                    .filter { it.userId == member.userId }
                    .map { shared ->
                        val habit = habitsById[shared.habitId.lowercase()]
                        SharedHabit(
                            habitId = UUID.fromString(shared.habitId),
                            title = habit?.name ?: "Shared habit",
                            icon = habit?.icon ?: "check_circle",
                            completedToday = false,
                            streak = 0
                        )
                    }

                GroupMember(
                    id = UUID.fromString(member.userId),
                    name = profile?.username ?: "Member",
                    avatarUrl = avatarUrlFromPath(profile?.avatarPath),
                    completedToday = memberShared.count { it.completedToday },
                    totalSharedHabits = memberShared.size,
                    sharedHabits = memberShared
                )
            }

            val currentUserSharedIds = sharedRows
                .filter { it.userId == currentUserId.toString() }
                .map { UUID.fromString(it.habitId) }
                .toSet()

            groups += Group(
                id = UUID.fromString(groupRow.id),
                name = groupRow.name,
                code = groupRow.code,
                joinLocked = groupRow.joinLocked,
                members = members,
                sharedHabitIds = currentUserSharedIds,
                ownerMemberId = UUID.fromString(groupRow.ownerId),
                currentUserMemberId = currentUserId
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

        val rows = habitIds.map {
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
        val raw = client.auth.currentUserOrNull()?.id ?: return null
        return runCatching { UUID.fromString(raw) }.getOrNull()
    }

    private fun avatarUrlFromPath(path: String?): String? {
        val trimmed = path?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
        return runCatching {
            client.storage.from("avatars").publicUrl(trimmed)
        }.getOrDefault(trimmed)
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
private data class NudgeFunctionResponse(
    val status: String,
    val error: String? = null,
    @SerialName("nudge_id") val nudgeId: String? = null,
    val delivered: Boolean? = null
)
