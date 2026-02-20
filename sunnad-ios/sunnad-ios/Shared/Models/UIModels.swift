import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ru
    case kk

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .en: return "en"
        case .ru: return "ru"
        case .kk: return "kk"
        }
    }

    var nameKey: String {
        switch self {
        case .en: return "language.english"
        case .ru: return "language.russian"
        case .kk: return "language.kazakh"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var nameKey: String {
        switch self {
        case .system: return "appearance.system"
        case .light: return "appearance.light"
        case .dark: return "appearance.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct UINotificationPreferences: Equatable {
    var habitReminders = true
    var quoteReminder = true
    var groupReminders = true
}

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case groups
    case profile

    var id: String { rawValue }
}

enum OnboardingStep: String {
    case welcome
    case templates
    case notifications
    case joinGroups
    case signIn
    case signUp
    case otp
}

enum OTPFlowMode: String {
    case signup
    case recovery
}

enum RootSheetRoute: Identifiable, Equatable {
    case addHabit
    case habitDetail(UUID)
    case quoteOfDay
    case createGroup
    case joinGroup
    case savedQuotes
    case languagePicker
    case reminderPlaceholder

    var id: String {
        switch self {
        case .addHabit:
            return "addHabit"
        case .habitDetail(let habitID):
            return "habitDetail-\(habitID.uuidString)"
        case .quoteOfDay:
            return "quoteOfDay"
        case .createGroup:
            return "createGroup"
        case .joinGroup:
            return "joinGroup"
        case .savedQuotes:
            return "savedQuotes"
        case .languagePicker:
            return "languagePicker"
        case .reminderPlaceholder:
            return "reminderPlaceholder"
        }
    }
}

enum FullScreenRoute: Identifiable, Equatable {
    case schedule
    case insightsPlaceholder
    case weekPlaceholder
    case monthPlaceholder
    case profileSignIn
    case profileSignUp
    case profileOTP
    case forgotPasswordOTPOnboarding
    case forgotPasswordOTPProfile
    case forgotPasswordOnboarding
    case forgotPasswordProfile
    case changePassword
    case editProfile

    var id: String {
        switch self {
        case .schedule:
            return "schedule"
        case .insightsPlaceholder:
            return "insightsPlaceholder"
        case .weekPlaceholder:
            return "weekPlaceholder"
        case .monthPlaceholder:
            return "monthPlaceholder"
        case .profileSignIn:
            return "profileSignIn"
        case .profileSignUp:
            return "profileSignUp"
        case .profileOTP:
            return "profileOTP"
        case .forgotPasswordOTPOnboarding:
            return "forgotPasswordOTPOnboarding"
        case .forgotPasswordOTPProfile:
            return "forgotPasswordOTPProfile"
        case .forgotPasswordOnboarding:
            return "forgotPasswordOnboarding"
        case .forgotPasswordProfile:
            return "forgotPasswordProfile"
        case .changePassword:
            return "changePassword"
        case .editProfile:
            return "editProfile"
        }
    }
}

enum HabitCategory: String, CaseIterable, Identifiable {
    case spiritual
    case physical
    case social
    case financial
    case learning
    case family

    var id: String { rawValue }

    var titleKey: String {
        "category.\(rawValue)"
    }
}

enum UIHabitSchedule: String, CaseIterable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .daily: return "habit.schedule.daily"
        case .weekly: return "habit.schedule.weekly"
        }
    }
}

enum ScheduleViewMode: String, CaseIterable, Identifiable {
    case all
    case upcoming
    case week
    case month

    var id: String { rawValue }

    var titleKey: String {
        "schedule.mode.\(rawValue)"
    }
}

struct HabitTemplate: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let iconSystemName: String
    let category: HabitCategory
    let isDhikr: Bool
}

struct UIHabit: Identifiable, Hashable {
    static let defaultDhikrKey = "dhikr.choice.subhanallah"

    let id: UUID
    var templateTitleKey: String?
    var customTitle: String?
    var iconSystemName: String
    var category: HabitCategory
    var completedToday: Bool
    var streak: Int
    var schedule: UIHabitSchedule
    var weekdays: Set<Int>
    var reminderTime: Date?
    var isDhikr: Bool
    var selectedDhikrKey: String
    var dhikrCountsByKey: [String: Int]
    var dhikrCount: Int
    var dhikrTarget: Int

    init(
        id: UUID = UUID(),
        templateTitleKey: String? = nil,
        customTitle: String? = nil,
        iconSystemName: String,
        category: HabitCategory,
        completedToday: Bool = false,
        streak: Int = 0,
        schedule: UIHabitSchedule = .daily,
        weekdays: Set<Int> = Set(0...6),
        reminderTime: Date? = nil,
        isDhikr: Bool = false,
        selectedDhikrKey: String = UIHabit.defaultDhikrKey,
        dhikrCountsByKey: [String: Int] = [:],
        dhikrCount: Int = 0,
        dhikrTarget: Int = 33
    ) {
        var normalizedCounts = dhikrCountsByKey
        normalizedCounts = normalizedCounts.mapValues { max($0, 0) }
        if isDhikr {
            normalizedCounts[selectedDhikrKey] = max(normalizedCounts[selectedDhikrKey] ?? dhikrCount, 0)
        }

        self.id = id
        self.templateTitleKey = templateTitleKey
        self.customTitle = customTitle
        self.iconSystemName = iconSystemName
        self.category = category
        self.completedToday = completedToday
        self.streak = streak
        self.schedule = schedule
        self.weekdays = weekdays
        self.reminderTime = reminderTime
        self.isDhikr = isDhikr
        self.selectedDhikrKey = selectedDhikrKey
        self.dhikrCountsByKey = normalizedCounts
        self.dhikrCount = dhikrCount
        self.dhikrTarget = dhikrTarget
    }

    var displayTitle: String {
        if let customTitle, !customTitle.isEmpty {
            return customTitle
        }

        if let templateTitleKey {
            return L10n.t(templateTitleKey)
        }

        return L10n.t("habit.untitled")
    }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        switch schedule {
        case .daily:
            return true
        case .weekly:
            let weekday = calendar.component(.weekday, from: date)
            let mondayFirst = (weekday + 5) % 7
            return weekdays.contains(mondayFirst)
        }
    }
}

struct UIQuote: Equatable {
    let textKey: String?
    let authorKey: String?
    let rawText: String?
    let rawAuthor: String?

    init(textKey: String, authorKey: String) {
        self.textKey = textKey
        self.authorKey = authorKey
        self.rawText = nil
        self.rawAuthor = nil
    }

    init(rawText: String, rawAuthor: String) {
        self.textKey = nil
        self.authorKey = nil
        self.rawText = rawText
        self.rawAuthor = rawAuthor
    }

    var text: String {
        if let rawText {
            return rawText
        }

        guard let textKey else {
            return ""
        }

        return L10n.t(textKey)
    }

    var author: String {
        if let rawAuthor {
            return rawAuthor
        }

        guard let authorKey else {
            return ""
        }

        return L10n.t(authorKey)
    }
}

struct UISavedQuote: Identifiable, Equatable {
    let id: UUID
    let text: String
    let author: String
    let savedAt: Date

    init(id: UUID = UUID(), text: String, author: String, savedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.author = author
        self.savedAt = savedAt
    }
}

struct UIUserState: Equatable {
    var isGuest: Bool
    var name: String?
    var email: String?
    var avatarURL: URL? = nil

    static let guest = UIUserState(isGuest: true, name: nil, email: nil)
}

struct UISharedHabit: Identifiable, Hashable {
    let id: UUID
    let habitID: UUID
    let habitTitle: String
    let habitIconSystemName: String
    let completedToday: Bool
    let streak: Int

    init(
        id: UUID = UUID(),
        habitID: UUID,
        habitTitle: String,
        habitIconSystemName: String,
        completedToday: Bool,
        streak: Int
    ) {
        self.id = id
        self.habitID = habitID
        self.habitTitle = habitTitle
        self.habitIconSystemName = habitIconSystemName
        self.completedToday = completedToday
        self.streak = streak
    }
}

struct UIGroupMember: Identifiable, Hashable {
    let id: UUID
    var name: String
    var completedToday: Int
    var totalSharedHabits: Int
    var sharedHabits: [UISharedHabit]

    init(
        id: UUID = UUID(),
        name: String,
        completedToday: Int,
        totalSharedHabits: Int,
        sharedHabits: [UISharedHabit]
    ) {
        self.id = id
        self.name = name
        self.completedToday = completedToday
        self.totalSharedHabits = totalSharedHabits
        self.sharedHabits = sharedHabits
    }
}

struct UIGroup: Identifiable, Hashable {
    let id: UUID
    var name: String
    var code: String
    var joinLocked: Bool
    var members: [UIGroupMember]
    var sharedHabitIDs: Set<UUID>
    var ownerMemberID: UUID
    var currentUserMemberID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        code: String,
        joinLocked: Bool = false,
        members: [UIGroupMember],
        sharedHabitIDs: Set<UUID>,
        ownerMemberID: UUID? = nil,
        currentUserMemberID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.joinLocked = joinLocked
        self.members = members
        self.sharedHabitIDs = sharedHabitIDs
        self.ownerMemberID = ownerMemberID ?? members.first?.id ?? UUID()
        self.currentUserMemberID = currentUserMemberID
    }
}
