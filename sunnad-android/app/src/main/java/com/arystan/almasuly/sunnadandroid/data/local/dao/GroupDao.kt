package com.arystan.almasuly.sunnadandroid.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import com.arystan.almasuly.sunnadandroid.data.local.entity.GroupEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.GroupMemberEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.GroupSharedHabitEntity

@Dao
interface GroupDao {
    @Query("SELECT * FROM groups WHERE ownerScope = :ownerScope ORDER BY updatedAtEpochMillis DESC")
    suspend fun fetchGroups(ownerScope: String): List<GroupEntity>

    @Query("SELECT * FROM groups WHERE ownerScope = :ownerScope AND id = :groupId LIMIT 1")
    suspend fun findGroup(ownerScope: String, groupId: String): GroupEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertGroup(group: GroupEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMembers(members: List<GroupMemberEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertSharedHabits(sharedHabits: List<GroupSharedHabitEntity>)

    @Query("SELECT * FROM group_members WHERE groupId = :groupId")
    suspend fun fetchMembers(groupId: String): List<GroupMemberEntity>

    @Query("SELECT * FROM group_shared_habits WHERE groupId = :groupId")
    suspend fun fetchSharedHabits(groupId: String): List<GroupSharedHabitEntity>

    @Query("DELETE FROM groups WHERE ownerScope = :ownerScope AND id = :groupId")
    suspend fun deleteGroup(ownerScope: String, groupId: String)

    @Query("DELETE FROM group_members WHERE groupId = :groupId")
    suspend fun deleteMembers(groupId: String)

    @Query("DELETE FROM group_shared_habits WHERE groupId = :groupId")
    suspend fun deleteSharedHabits(groupId: String)

    @Query("DELETE FROM group_members WHERE groupId IN (SELECT id FROM groups WHERE ownerScope = :ownerScope)")
    suspend fun deleteAllMembersByScope(ownerScope: String)

    @Query("DELETE FROM group_shared_habits WHERE groupId IN (SELECT id FROM groups WHERE ownerScope = :ownerScope)")
    suspend fun deleteAllSharedHabitsByScope(ownerScope: String)

    @Query("DELETE FROM groups WHERE ownerScope = :ownerScope")
    suspend fun deleteAllGroupsByScope(ownerScope: String)

    @Transaction
    suspend fun replaceGroupSnapshot(
        group: GroupEntity,
        members: List<GroupMemberEntity>,
        sharedHabits: List<GroupSharedHabitEntity>
    ) {
        upsertGroup(group)
        deleteMembers(group.id)
        deleteSharedHabits(group.id)
        if (members.isNotEmpty()) {
            upsertMembers(members)
        }
        if (sharedHabits.isNotEmpty()) {
            upsertSharedHabits(sharedHabits)
        }
    }
}
