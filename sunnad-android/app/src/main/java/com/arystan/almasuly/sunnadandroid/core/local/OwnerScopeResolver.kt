package com.arystan.almasuly.sunnadandroid.core.local

import android.content.SharedPreferences
import java.util.UUID

class OwnerScopeResolver(
    private val prefs: SharedPreferences,
    private val namespace: String
) {
    private val storageKey = "sunnad.local.owner_scope.$namespace"

    var currentOwnerScope: OwnerScope = prefs.getString(storageKey, null)
        ?.let(OwnerScope::fromRaw)
        ?: OwnerScope.Guest
        private set

    val currentOwnerScopeRaw: String
        get() = currentOwnerScope.rawValue

    fun setSignedInUserId(userId: UUID?) {
        currentOwnerScope = if (userId == null) OwnerScope.Guest else OwnerScope.User(userId)
        prefs.edit().putString(storageKey, currentOwnerScope.rawValue).apply()
    }
}
