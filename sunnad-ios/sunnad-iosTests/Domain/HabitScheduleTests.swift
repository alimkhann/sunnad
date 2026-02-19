import Foundation
import Testing
@testable import sunnad_ios

struct HabitScheduleTests {
    @Test
    func dailyScheduleIsAlwaysDue() {
        let schedule: HabitSchedule = .daily
        let date = Date(timeIntervalSince1970: 1_771_200_000)

        #expect(schedule.isDue(on: date))
    }

    @Test
    func weeklyScheduleMatchesOnlySelectedDays() {
        let schedule: HabitSchedule = .weekly([.monday, .wednesday, .friday])
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)!

        let monday = makeDate(year: 2026, month: 2, day: 16, hour: 12, minute: 0, timeZone: tz)
        let tuesday = makeDate(year: 2026, month: 2, day: 17, hour: 12, minute: 0, timeZone: tz)

        #expect(schedule.isDue(on: monday, calendar: calendar, timeZone: tz))
        #expect(!schedule.isDue(on: tuesday, calendar: calendar, timeZone: tz))
    }

    @Test
    func isoWeekdayMappingHandlesSundayAndMonday() {
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)!

        let monday = makeDate(year: 2026, month: 2, day: 16, hour: 10, minute: 0, timeZone: tz)
        let sunday = makeDate(year: 2026, month: 2, day: 15, hour: 10, minute: 0, timeZone: tz)

        #expect(Weekday.isoWeekday(for: monday, calendar: calendar, timeZone: tz) == .monday)
        #expect(Weekday.isoWeekday(for: sunday, calendar: calendar, timeZone: tz) == .sunday)
    }

    @Test
    func timezoneAffectsDueDateCalculationAroundMidnight() {
        let schedule: HabitSchedule = .weekly([.tuesday])
        let calendar = Calendar(identifier: .gregorian)

        let utc = TimeZone(secondsFromGMT: 0)!
        let almaty = TimeZone(secondsFromGMT: 6 * 3600)!

        // Monday 23:30 UTC is Tuesday 05:30 in Almaty.
        let date = makeDate(year: 2026, month: 2, day: 16, hour: 23, minute: 30, timeZone: utc)

        #expect(!schedule.isDue(on: date, calendar: calendar, timeZone: utc))
        #expect(schedule.isDue(on: date, calendar: calendar, timeZone: almaty))
    }

    @Test
    func weeklyScheduleHandlesYearBoundaryCorrectly() {
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)!
        let schedule: HabitSchedule = .weekly([.thursday])

        let dec31 = makeDate(year: 2026, month: 12, day: 31, hour: 12, minute: 0, timeZone: tz)
        let jan1 = makeDate(year: 2027, month: 1, day: 1, hour: 12, minute: 0, timeZone: tz)

        #expect(Weekday.isoWeekday(for: dec31, calendar: calendar, timeZone: tz) == .thursday)
        #expect(schedule.isDue(on: dec31, calendar: calendar, timeZone: tz))
        #expect(!schedule.isDue(on: jan1, calendar: calendar, timeZone: tz))
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components)!
    }
}
