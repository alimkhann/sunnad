import Testing
@testable import sunnad_ios

struct UIModelDomainMapperTests {
    @Test
    func uiWeekdayMappingConvertsToISOAndBack() {
        let uiHabit = UIHabit(
            customTitle: "Exercise",
            iconSystemName: "figure.run",
            category: .physical,
            schedule: .weekly,
            weekdays: [0, 2, 6]
        )

        let domain = uiHabit.asDomainHabit()

        switch domain.schedule {
        case .daily:
            Issue.record("Expected weekly schedule")
        case .weekly(let weekdays):
            #expect(weekdays.contains(.monday))
            #expect(weekdays.contains(.wednesday))
            #expect(weekdays.contains(.sunday))
        }

        let mappedBack = domain.asUIHabit(completedToday: false, streak: 0)
        #expect(mappedBack.weekdays == Set([0, 2, 6]))
    }
}
