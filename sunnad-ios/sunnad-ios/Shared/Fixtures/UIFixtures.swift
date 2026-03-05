import Foundation

enum UIFixtures {
    static let dailyQuote = UIQuote(
        textKey: "quote.daily.text",
        authorKey: "quote.daily.author"
    )

    static let templates: [HabitTemplate] = [
        HabitTemplate(id: "wake-early", titleKey: "habit.wake_up_early", iconSystemName: "sunrise.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "morning-dhikr", titleKey: "habit.morning_dhikr", iconSystemName: "sun.max.fill", category: .spiritual, isDhikr: true),
        HabitTemplate(id: "evening-dhikr", titleKey: "habit.evening_dhikr", iconSystemName: "moon.fill", category: .spiritual, isDhikr: true),
        HabitTemplate(id: "read-quran", titleKey: "habit.read_quran", iconSystemName: "book.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "surah-waqiah", titleKey: "habit.read_surah_al_waqiah", iconSystemName: "text.book.closed.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "surah-yasin", titleKey: "habit.read_surah_yasin", iconSystemName: "text.book.closed.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "study-arabic", titleKey: "habit.study_arabic", iconSystemName: "character.book.closed.fill", category: .learning, isDhikr: false),
        HabitTemplate(id: "exercise", titleKey: "habit.exercise", iconSystemName: "figure.run", category: .physical, isDhikr: false),
        HabitTemplate(id: "give-charity", titleKey: "habit.give_charity", iconSystemName: "heart.fill", category: .financial, isDhikr: false),
        HabitTemplate(id: "go-mosque", titleKey: "habit.go_to_the_mosque", iconSystemName: "building.columns.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "five-times-prayer", titleKey: "habit.five_times_prayer", iconSystemName: "building.columns.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "fajr", titleKey: "habit.fajr", iconSystemName: "building.columns.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "dhuhr", titleKey: "habit.dhuhr", iconSystemName: "building.columns.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "asr", titleKey: "habit.asr", iconSystemName: "building.columns.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "maghrib", titleKey: "habit.maghrib", iconSystemName: "building.columns.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "isha", titleKey: "habit.isha", iconSystemName: "building.columns.fill", category: .spiritual, isDhikr: false),
        HabitTemplate(id: "avoid-debt", titleKey: "habit.avoid_debt", iconSystemName: "creditcard.fill", category: .financial, isDhikr: false),
        HabitTemplate(id: "care-parents", titleKey: "habit.care_for_parents", iconSystemName: "person.2.fill", category: .family, isDhikr: false),
        HabitTemplate(id: "attention-spouse", titleKey: "habit.give_attention_to_spouse", iconSystemName: "person.2.circle.fill", category: .social, isDhikr: false),
        HabitTemplate(id: "time-children", titleKey: "habit.time_with_children", iconSystemName: "figure.2.and.child.holdinghands", category: .family, isDhikr: false),
        HabitTemplate(id: "work-focus", titleKey: "habit.work_focus", iconSystemName: "briefcase.fill", category: .work, isDhikr: false),
        HabitTemplate(id: "hobby-practice", titleKey: "habit.hobby_practice", iconSystemName: "paintpalette.fill", category: .hobby, isDhikr: false)
    ]

    static var initialHabits: [UIHabit] {
        [
            UIHabit(
                templateTitleKey: "habit.morning_dhikr",
                iconSystemName: "sun.max.fill",
                category: .spiritual,
                completedToday: false,
                streak: 8,
                schedule: .daily,
                reminderTime: time(hour: 7, minute: 0),
                isDhikr: true,
                dhikrCount: 11,
                dhikrTarget: 33
            ),
            UIHabit(
                templateTitleKey: "habit.read_quran",
                iconSystemName: "book.fill",
                category: .spiritual,
                completedToday: true,
                streak: 5,
                schedule: .daily,
                reminderTime: time(hour: 20, minute: 0)
            ),
            UIHabit(
                templateTitleKey: "habit.exercise",
                iconSystemName: "figure.run",
                category: .physical,
                completedToday: false,
                streak: 3,
                schedule: .weekly,
                weekdays: [0, 2, 4]
            ),
            UIHabit(
                templateTitleKey: "habit.give_charity",
                iconSystemName: "heart.fill",
                category: .financial,
                completedToday: false,
                streak: 1,
                schedule: .weekly,
                weekdays: [4]
            ),
            UIHabit(
                templateTitleKey: "habit.care_for_parents",
                iconSystemName: "person.2.fill",
                category: .family,
                completedToday: true,
                streak: 15,
                schedule: .daily
            )
        ]
    }

    static var initialSavedQuotes: [UISavedQuote] {
        [
            UISavedQuote(
                text: L10n.t("quote.saved.sample.text"),
                author: L10n.t("quote.saved.sample.author"),
                savedAt: Date().addingTimeInterval(-86_400)
            )
        ]
    }

    static func groups(user: UIUserState, habits: [UIHabit]) -> [UIGroup] {
        let myName = user.name ?? L10n.t("groups.you")
        let mySharedHabits = habits.map {
            UISharedHabit(
                habitID: $0.id,
                habitTitle: $0.displayTitle,
                habitIconSystemName: $0.iconSystemName,
                completedToday: $0.completedToday,
                streak: $0.streak
            )
        }

        let me = UIGroupMember(
            name: myName,
            completedToday: habits.filter(\.completedToday).count,
            totalSharedHabits: habits.count,
            sharedHabits: mySharedHabits
        )

        let memberOne = UIGroupMember(
            name: "Ahmed",
            completedToday: 3,
            totalSharedHabits: 5,
            sharedHabits: [
                UISharedHabit(habitID: UUID(), habitTitle: L10n.t("habit.read_quran"), habitIconSystemName: "book.fill", completedToday: true, streak: 12),
                UISharedHabit(habitID: UUID(), habitTitle: L10n.t("habit.exercise"), habitIconSystemName: "figure.run", completedToday: false, streak: 3)
            ]
        )

        let memberTwo = UIGroupMember(
            name: "Fatima",
            completedToday: 4,
            totalSharedHabits: 4,
            sharedHabits: [
                UISharedHabit(habitID: UUID(), habitTitle: L10n.t("habit.morning_dhikr"), habitIconSystemName: "sun.max.fill", completedToday: true, streak: 18),
                UISharedHabit(habitID: UUID(), habitTitle: L10n.t("habit.evening_dhikr"), habitIconSystemName: "moon.fill", completedToday: true, streak: 21)
            ]
        )

        return [
            UIGroup(
                name: "Morning Circle",
                code: "SUNNAD",
                members: [me, memberOne, memberTwo],
                sharedHabitIDs: Set(habits.map(\.id))
            )
        ]
    }

    static func time(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
