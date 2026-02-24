import Foundation

enum AnalyticsScreen: String {
    case today = "today"
    case groups = "groups"
    case profile = "profile"
    case onboarding = "onboarding"
}

enum AnalyticsLifecycleEvent {
    case appOpened
    case appBackgrounded
}

enum AnalyticsOnboardingEvent {
    case started
    case templateSelected(count: Int)
    case notificationsPrompted
    case notificationsEnabled
    case notificationsSkipped
    case completed
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
    case created(type: String, scheduleType: String, hasReminder: Bool)
    case edited(changedFields: [String])
    case archived
    case unarchived
    case completed(type: String, source: String, count: Int)
    case uncompleted
    case reminderEnabled
    case reminderDisabled
    case counterIncremented(type: String, delta: Int)
}

enum AnalyticsQuoteEvent {
    case viewed
    case saved
    case unsaved
    case shared(channel: String?)
}

enum AnalyticsGroupEvent {
    case opened
    case created
    case joinStarted
    case joinSucceeded
    case joinFailed(reason: String)
    case left
    case memberViewed(count: Int)
    case sharingUpdated(delta: Int)
    case nudgeSent(habitType: String)
    case nudgeFailed(reason: String)
}

enum AnalyticsSyncEvent {
    case started(trigger: String)
    case succeeded(durationMs: Int, pulled: Int, pushed: Int)
    case failed(stage: String, code: String, durationMs: Int)
}

extension AnalyticsClient {
    func trackLifecycle(_ event: AnalyticsLifecycleEvent) {
        switch event {
        case .appOpened:
            capture("app_opened", properties: nil)
        case .appBackgrounded:
            capture("app_backgrounded", properties: nil)
        }
    }

    func trackScreen(_ screen: AnalyticsScreen) {
        let name = screen.rawValue
        screen(name, properties: ["screen_name": name])
    }

    func trackOnboarding(_ event: AnalyticsOnboardingEvent) {
        switch event {
        case .started:
            capture("onboarding_started", properties: nil)
        case .templateSelected(let count):
            capture("onboarding_template_selected", properties: ["template_count": count])
        case .notificationsPrompted:
            capture("onboarding_notifications_prompted", properties: nil)
        case .notificationsEnabled:
            capture("onboarding_notifications_enabled", properties: nil)
        case .notificationsSkipped:
            capture("onboarding_notifications_skipped", properties: nil)
        case .completed:
            capture("onboarding_completed", properties: nil)
        }
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
        let eventName: String
        switch (kind, status) {
        case (.signIn, .success):
            eventName = "auth_sign_in_success"
        case (.signIn, .failure):
            eventName = "auth_sign_in_failed"
        case (.signUp, .success):
            eventName = "auth_sign_up_success"
        case (.signUp, .failure):
            eventName = "auth_sign_up_failed"
        }
        capture(eventName, properties: props)
    }

    func trackHabit(_ event: AnalyticsHabitEvent) {
        switch event {
        case let .created(type, scheduleType, hasReminder):
            capture(
                "habit_created",
                properties: [
                    "type": type,
                    "schedule_type": scheduleType,
                    "has_reminder": hasReminder,
                ]
            )
        case let .edited(changedFields):
            capture("habit_edited", properties: ["changed_fields": changedFields])
        case .archived:
            capture("habit_archived", properties: nil)
        case .unarchived:
            capture("habit_unarchived", properties: nil)
        case let .completed(type, source, count):
            capture(
                "habit_completed",
                properties: [
                    "type": type,
                    "source": source,
                    "count": count,
                ]
            )
        case .uncompleted:
            capture("habit_uncompleted", properties: nil)
        case .reminderEnabled:
            capture("habit_reminder_enabled", properties: nil)
        case .reminderDisabled:
            capture("habit_reminder_disabled", properties: nil)
        case let .counterIncremented(type, delta):
            capture(
                "habit_counter_incremented",
                properties: [
                    "type": type,
                    "delta": delta,
                ]
            )
        }
    }

    func trackQuote(_ event: AnalyticsQuoteEvent) {
        switch event {
        case .viewed:
            capture("quote_viewed", properties: nil)
        case .saved:
            capture("quote_saved", properties: nil)
        case .unsaved:
            capture("quote_unsaved", properties: nil)
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
        case .joinStarted:
            capture("group_join_started", properties: nil)
        case .joinSucceeded:
            capture("group_join_succeeded", properties: nil)
        case let .joinFailed(reason):
            capture("group_join_failed", properties: ["reason": reason])
        case .left:
            capture("group_left", properties: nil)
        case let .memberViewed(count):
            capture("group_member_viewed", properties: ["count": count])
        case let .sharingUpdated(delta):
            capture("group_sharing_updated", properties: ["delta": delta])
        case let .nudgeSent(habitType):
            capture("nudge_sent", properties: ["habit_type": habitType])
        case let .nudgeFailed(reason):
            capture("nudge_failed", properties: ["reason": reason])
        }
    }

    func trackSync(_ event: AnalyticsSyncEvent) {
        switch event {
        case let .started(trigger):
            capture("sync_started", properties: ["trigger": trigger])
        case let .succeeded(durationMs, pulled, pushed):
            capture(
                "sync_succeeded",
                properties: [
                    "duration_ms": durationMs,
                    "pulled_count": pulled,
                    "pushed_count": pushed,
                ]
            )
        case let .failed(stage, code, durationMs):
            capture(
                "sync_failed",
                properties: [
                    "stage": stage,
                    "error_code": code,
                    "duration_ms": durationMs,
                ]
            )
        }
    }
}

