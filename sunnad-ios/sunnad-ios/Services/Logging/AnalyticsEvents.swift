import Foundation

enum AnalyticsScreen: String {
    case today = "today"
    case groups = "groups"
    case profile = "profile"
    case insights = "insights"
    case onboarding = "onboarding"
}

enum AnalyticsOnboardingStep: String {
    case welcome = "welcome"
    case templates = "templates"
    case notifications = "notifications"
    case joinGroups = "join_groups"
    case signIn = "sign_in"
    case signUp = "sign_up"
    case otp = "otp"
}

enum AnalyticsAuthEventKind: String {
    case signIn = "sign_in"
    case signUp = "sign_up"
}

enum AnalyticsAuthProvider: String {
    case email
    case google
    case apple
}

enum AnalyticsAuthStatus: String {
    case success
    case failure
}

enum AnalyticsHabitEvent {
    case created(type: String, scheduleType: String, hasReminder: Bool, targetCount: Int)
    case edited(changedFields: [String])
    case deleted(type: String)
    case completionToggled(type: String, status: String, source: String)
    case reminderToggled(status: String)
    case counterIncremented(delta: Int, count: Int, target: Int)
}

enum AnalyticsQuoteEvent {
    case opened
    case saved
    case shared(channel: String?)
}

enum AnalyticsGroupEvent {
    case opened
    case created
    case joinResult(status: String, reason: String?)
    case left
    case sharingUpdated(delta: Int, totalShared: Int)
    case nudgeResult(status: String, habitType: String)
}

enum AnalyticsSyncEvent {
    case result(
        trigger: String,
        status: String,
        durationMs: Int,
        pulled: Int,
        pushed: Int,
        stage: String?,
        code: String?
    )
}

enum AnalyticsAppLifecycleEvent {
    case opened(source: String)
    case backgrounded(sessionDurationSeconds: Int)
    case offlineSessionCompleted(sessionDurationSeconds: Int, offlineDurationSeconds: Int)
}

enum AnalyticsStreakEvent {
    case achieved(habitType: String, streakLength: Int, milestone: Int)
    case broken(habitType: String, previousStreakLength: Int)
}

enum AnalyticsGroupInsightEvent {
    case memberProgressViewed(memberScope: String, sharedHabitsCount: Int)
}

enum AnalyticsNotificationEvent {
    case received(notificationType: String, source: String)
    case tapped(notificationType: String, source: String)
}

extension AnalyticsClient {
    func trackScreen(_ screenId: AnalyticsScreen) {
        capture("screen_viewed", properties: ["screen_name": screenId.rawValue])
    }

    func trackOnboardingStepCompleted(_ step: AnalyticsOnboardingStep) {
        capture("onboarding_step_completed", properties: ["step_name": step.rawValue])
    }

    func trackAuth(
        kind: AnalyticsAuthEventKind,
        provider: AnalyticsAuthProvider,
        status: AnalyticsAuthStatus,
        reason: String? = nil
    ) {
        let base: [String: Any] = [
            "kind": kind.rawValue,
            "provider": provider.rawValue,
            "status": status.rawValue,
        ]
        var props = base
        if let reason {
            props["reason"] = reason
        }
        capture("auth_result", properties: props)
    }

    func trackHabit(_ event: AnalyticsHabitEvent) {
        switch event {
        case let .created(type, scheduleType, hasReminder, targetCount):
            capture(
                "habit_created",
                properties: [
                    "type": type,
                    "schedule_type": scheduleType,
                    "has_reminder": hasReminder,
                    "target_count": targetCount,
                ]
            )
        case let .edited(changedFields):
            capture("habit_updated", properties: ["changed_fields": changedFields])
        case let .deleted(type):
            capture("habit_deleted", properties: ["type": type])
        case let .completionToggled(type, status, source):
            capture(
                "habit_completion_toggled",
                properties: [
                    "type": type,
                    "status": status,
                    "source": source,
                ]
            )
        case let .reminderToggled(status):
            capture("habit_reminder_toggled", properties: ["status": status])
        case let .counterIncremented(delta, count, target):
            capture(
                "habit_counter_incremented",
                properties: [
                    "delta": delta,
                    "count": count,
                    "target": target,
                ]
            )
        }
    }

    func trackQuote(_ event: AnalyticsQuoteEvent) {
        switch event {
        case .opened:
            capture("quote_opened", properties: nil)
        case .saved:
            capture("quote_saved", properties: nil)
        case let .shared(channel):
            var props: [String: Any] = [:]
            if let channel {
                props["channel"] = channel
            }
            capture("quote_shared", properties: props)
        }
    }

    func trackGroup(_ event: AnalyticsGroupEvent) {
        switch event {
        case .opened:
            capture("group_opened", properties: nil)
        case .created:
            capture("group_created", properties: nil)
        case let .joinResult(status, reason):
            var properties: [String: Any] = ["status": status]
            if let reason {
                properties["reason"] = reason
            }
            capture("group_join_result", properties: properties)
        case .left:
            capture("group_left", properties: nil)
        case let .sharingUpdated(delta, totalShared):
            capture("group_sharing_updated", properties: ["delta": delta, "total_shared": totalShared])
        case let .nudgeResult(status, habitType):
            capture("group_nudge_result", properties: ["status": status, "habit_type": habitType])
        }
    }

    func trackSync(_ event: AnalyticsSyncEvent) {
        switch event {
        case let .result(trigger, status, durationMs, pulled, pushed, stage, code):
            var properties: [String: Any] = [
                "trigger": trigger,
                "status": status,
                "duration_ms": durationMs,
                "pulled_count": pulled,
                "pushed_count": pushed,
            ]
            if let stage {
                properties["stage"] = stage
            }
            if let code {
                properties["error_code"] = code
            }
            capture("sync_cycle_result", properties: properties)
        }
    }

    func trackAppLifecycle(_ event: AnalyticsAppLifecycleEvent) {
        switch event {
        case let .opened(source):
            capture("app_opened", properties: ["source": source])
        case let .backgrounded(sessionDurationSeconds):
            capture("app_backgrounded", properties: ["session_duration_seconds": sessionDurationSeconds])
        case let .offlineSessionCompleted(sessionDurationSeconds, offlineDurationSeconds):
            capture(
                "offline_session_completed",
                properties: [
                    "session_duration_seconds": sessionDurationSeconds,
                    "offline_duration_seconds": offlineDurationSeconds,
                ]
            )
        }
    }

    func trackStreak(_ event: AnalyticsStreakEvent) {
        switch event {
        case let .achieved(habitType, streakLength, milestone):
            capture(
                "habit_streak_achieved",
                properties: [
                    "habit_type": habitType,
                    "streak_length": streakLength,
                    "milestone": milestone,
                ]
            )
        case let .broken(habitType, previousStreakLength):
            capture(
                "habit_streak_broken",
                properties: [
                    "habit_type": habitType,
                    "previous_streak_length": previousStreakLength,
                ]
            )
        }
    }

    func trackGroupInsight(_ event: AnalyticsGroupInsightEvent) {
        switch event {
        case let .memberProgressViewed(memberScope, sharedHabitsCount):
            capture(
                "group_member_progress_viewed",
                properties: [
                    "member_scope": memberScope,
                    "shared_habits_count": sharedHabitsCount,
                ]
            )
        }
    }

    func trackNotification(_ event: AnalyticsNotificationEvent) {
        switch event {
        case let .received(notificationType, source):
            capture(
                "notification_received",
                properties: [
                    "notification_type": notificationType,
                    "source": source,
                ]
            )
        case let .tapped(notificationType, source):
            capture(
                "notification_tapped",
                properties: [
                    "notification_type": notificationType,
                    "source": source,
                ]
            )
        }
    }
}
