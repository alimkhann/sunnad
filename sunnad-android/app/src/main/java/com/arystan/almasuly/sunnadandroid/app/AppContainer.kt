package com.arystan.almasuly.sunnadandroid.app

import android.content.Context
import androidx.room.Room
import com.arystan.almasuly.sunnadandroid.BuildConfig
import com.arystan.almasuly.sunnadandroid.core.local.OwnerScopeResolver
import com.arystan.almasuly.sunnadandroid.data.local.db.SunnadDatabase
import com.arystan.almasuly.sunnadandroid.data.local.entity.QuoteEntity
import com.arystan.almasuly.sunnadandroid.data.local.repository.CompletionsLocalRepository
import com.arystan.almasuly.sunnadandroid.data.local.repository.GroupsLocalRepository
import com.arystan.almasuly.sunnadandroid.data.local.repository.HabitsLocalRepository
import com.arystan.almasuly.sunnadandroid.data.local.repository.QuotesLocalRepository
import com.arystan.almasuly.sunnadandroid.data.remote.SupabaseClientProvider
import com.arystan.almasuly.sunnadandroid.data.remote.repository.SupabaseGroupsRepository
import com.arystan.almasuly.sunnadandroid.domain.repository.CompletionsRepository
import com.arystan.almasuly.sunnadandroid.domain.repository.GroupsRepository
import com.arystan.almasuly.sunnadandroid.domain.repository.HabitsRepository
import com.arystan.almasuly.sunnadandroid.domain.repository.QuotesRepository
import com.arystan.almasuly.sunnadandroid.features.auth.AuthService
import com.arystan.almasuly.sunnadandroid.features.auth.SupabaseAuthService
import com.arystan.almasuly.sunnadandroid.features.auth.UnconfiguredAuthService
import com.arystan.almasuly.sunnadandroid.notifications.AlarmLocalReminderScheduler
import com.arystan.almasuly.sunnadandroid.notifications.LocalReminderScheduler
import com.arystan.almasuly.sunnadandroid.notifications.NoOpPushTokenSyncService
import com.arystan.almasuly.sunnadandroid.notifications.PushTokenSyncService
import com.arystan.almasuly.sunnadandroid.notifications.SupabasePushTokenSyncService
import com.arystan.almasuly.sunnadandroid.services.AppSettingsStore
import com.arystan.almasuly.sunnadandroid.sync.NoOpSyncCoordinator
import com.arystan.almasuly.sunnadandroid.sync.SupabaseSyncCoordinator
import com.arystan.almasuly.sunnadandroid.sync.SyncCoordinator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.UUID

class AppContainer(context: Context) {
    private val appContext = context.applicationContext
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val storageNamespace = BuildConfig.SUNNAD_STORAGE_NAMESPACE.trim().ifBlank { "android" }

    private val prefs = appContext.getSharedPreferences("sunnad_owner_scope", Context.MODE_PRIVATE)
    val ownerScopeResolver = OwnerScopeResolver(prefs = prefs, namespace = storageNamespace)

    private val authRuntimeResolver = AuthRuntimeConfigResolver(
        context = appContext,
        namespace = storageNamespace
    )
    private val authRuntimeConfig = authRuntimeResolver.resolve(
        buildUrl = BuildConfig.SUNNAD_SUPABASE_URL,
        buildAnonKey = BuildConfig.SUNNAD_SUPABASE_ANON_KEY,
        buildRedirect = BuildConfig.SUNNAD_AUTH_REDIRECT_URL,
        buildGoogleEnabled = BuildConfig.SUNNAD_GOOGLE_AUTH_ENABLED,
        buildAppleEnabled = BuildConfig.SUNNAD_APPLE_AUTH_ENABLED,
        buildResendCooldownSeconds = BuildConfig.SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS
    )
    private var supabaseInitFailure: String? = null
    val authRuntimeStatus: String
        get() = buildString {
            append(authRuntimeResolver.diagnostics(authRuntimeConfig))
            supabaseInitFailure?.let { failure ->
                append(" client=UNAVAILABLE reason=")
                append(failure)
            }
        }

    private val supabaseClient by lazy {
        authRuntimeConfig?.let { config ->
            runCatching {
                SupabaseClientProvider(
                    url = config.supabaseUrl,
                    anonKey = config.supabaseAnonKey,
                    authScheme = config.authScheme,
                    authHost = config.authHost,
                    authRedirectUrl = config.redirectUrl
                ).create()
            }.onFailure { error ->
                supabaseInitFailure = error.message ?: error::class.simpleName
            }.getOrNull()
        }
    }

    private val database: SunnadDatabase = Room.databaseBuilder(
        appContext,
        SunnadDatabase::class.java,
        "sunnad.db"
    ).fallbackToDestructiveMigration().build()

    val habitsRepository: HabitsRepository = HabitsLocalRepository(database.habitDao(), ownerScopeResolver)
    val completionsRepository: CompletionsRepository = CompletionsLocalRepository(database.completionDao(), ownerScopeResolver)
    val quotesRepository: QuotesRepository = QuotesLocalRepository(
        quoteDao = database.quoteDao(),
        savedQuoteDao = database.savedQuoteDao(),
        ownerScopeResolver = ownerScopeResolver
    )
    val groupsRepository: GroupsRepository = supabaseClient?.let { SupabaseGroupsRepository(it) }
        ?: GroupsLocalRepository(database.groupDao(), ownerScopeResolver)

    val syncCoordinator: SyncCoordinator = if (supabaseClient != null) {
        SupabaseSyncCoordinator(
            outboxDao = database.outboxDao(),
            syncCursorDao = database.syncCursorDao(),
            ownerScopeResolver = ownerScopeResolver,
            habitDao = database.habitDao(),
            completionDao = database.completionDao(),
            savedQuoteDao = database.savedQuoteDao(),
            groupDao = database.groupDao(),
            client = supabaseClient
        )
    } else {
        NoOpSyncCoordinator()
    }
    val reminderScheduler: LocalReminderScheduler = AlarmLocalReminderScheduler(appContext)
    val pushTokenSyncService: PushTokenSyncService = supabaseClient?.let { SupabasePushTokenSyncService(it) }
        ?: NoOpPushTokenSyncService()
    val authService: AuthService = createAuthService()
    val settingsStore: AppSettingsStore = AppSettingsStore(appContext)

    init {
        seedQuotesIfNeeded()
    }

    private fun seedQuotesIfNeeded() {
        appScope.launch {
            val existingEn = database.quoteDao().fetchActiveByLocale("en")
            if (existingEn.isNotEmpty()) return@launch

            val now = Instant.now().toEpochMilli()
            val seed = listOf(
                QuoteEntity(UUID.randomUUID().toString(), "en", "Consistency beats intensity.", "Sunnad", 0, true, now, now),
                QuoteEntity(UUID.randomUUID().toString(), "en", "Small habits, steady hearts.", "Sunnad", 1, true, now, now),
                QuoteEntity(UUID.randomUUID().toString(), "ru", "Постоянство важнее рывков.", "Sunnad", 0, true, now, now),
                QuoteEntity(UUID.randomUUID().toString(), "ru", "Малые шаги каждый день дают силу.", "Sunnad", 1, true, now, now),
                QuoteEntity(UUID.randomUUID().toString(), "kk", "Тұрақтылық екпіннен маңызды.", "Sunnad", 0, true, now, now),
                QuoteEntity(UUID.randomUUID().toString(), "kk", "Күнделікті кіші қадам - үлкен нәтижеге жол.", "Sunnad", 1, true, now, now)
            )
            database.quoteDao().upsertAll(seed)
        }
    }

    private fun createAuthService(): AuthService {
        val config = authRuntimeConfig ?: return UnconfiguredAuthService(
            resendCooldownSeconds = BuildConfig.SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS
        )
        val client = supabaseClient
        if (client == null) {
            return UnconfiguredAuthService(
                resendCooldownSeconds = config.resendCooldownSeconds
            )
        }

        return SupabaseAuthService(
            client = client,
            redirectUrl = config.redirectUrl,
            isGoogleEnabled = config.isGoogleEnabled,
            isAppleEnabled = config.isAppleEnabled,
            resendCooldownSeconds = config.resendCooldownSeconds
        )
    }
}
