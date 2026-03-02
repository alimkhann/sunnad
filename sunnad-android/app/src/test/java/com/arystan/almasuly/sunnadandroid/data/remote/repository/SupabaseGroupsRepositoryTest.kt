package com.arystan.almasuly.sunnadandroid.data.remote.repository

import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class SupabaseGroupsRepositoryTest {
    @Test
    fun nudgeStatusMappingCoversKnownStatesAndFallback() {
        assertEquals(GroupNudgeStatus.SENT, SupabaseGroupsRepository.mapNudgeStatus("sent"))
        assertEquals(GroupNudgeStatus.DUPLICATE, SupabaseGroupsRepository.mapNudgeStatus("duplicate"))
        assertEquals(GroupNudgeStatus.FORBIDDEN, SupabaseGroupsRepository.mapNudgeStatus("forbidden"))
        assertEquals(GroupNudgeStatus.ERROR, SupabaseGroupsRepository.mapNudgeStatus("unexpected"))
    }

    @Test
    fun parseUuidFromRpcResponseSupportsScalarObjectAndArrayShapes() {
        val scalar = SupabaseGroupsRepository.parseUuidFromRpcResponse("\"f91c03bf-cd81-40be-ad07-56f0128e19a2\"")
        val objectPayload = SupabaseGroupsRepository.parseUuidFromRpcResponse("{\"id\":\"f91c03bf-cd81-40be-ad07-56f0128e19a2\"}")
        val arrayPayload = SupabaseGroupsRepository.parseUuidFromRpcResponse("[{\"group_id\":\"f91c03bf-cd81-40be-ad07-56f0128e19a2\"}]")

        assertNotNull(scalar)
        assertNotNull(objectPayload)
        assertNotNull(arrayPayload)
        assertEquals(scalar, objectPayload)
        assertEquals(objectPayload, arrayPayload)
    }
}
