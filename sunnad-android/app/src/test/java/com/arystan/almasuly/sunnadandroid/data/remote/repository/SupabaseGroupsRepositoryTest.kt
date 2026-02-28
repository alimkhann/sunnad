package com.arystan.almasuly.sunnadandroid.data.remote.repository

import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
import org.junit.Assert.assertEquals
import org.junit.Test

class SupabaseGroupsRepositoryTest {
    @Test
    fun nudgeStatusMappingCoversKnownStatesAndFallback() {
        assertEquals(GroupNudgeStatus.SENT, SupabaseGroupsRepository.mapNudgeStatus("sent"))
        assertEquals(GroupNudgeStatus.DUPLICATE, SupabaseGroupsRepository.mapNudgeStatus("duplicate"))
        assertEquals(GroupNudgeStatus.FORBIDDEN, SupabaseGroupsRepository.mapNudgeStatus("forbidden"))
        assertEquals(GroupNudgeStatus.ERROR, SupabaseGroupsRepository.mapNudgeStatus("unexpected"))
    }
}
