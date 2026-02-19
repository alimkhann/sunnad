import Foundation
import Testing
@testable import sunnad_ios

struct QuoteDayKeyTests {
    @Test
    func dayKeyIncludesLocaleAndDate() {
        let tz = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let date = calendar.date(from: DateComponents(year: 2026, month: 2, day: 19, hour: 15, minute: 0))!

        let key = QuoteDayKey.value(for: date, locale: "ru", calendar: calendar, timeZone: tz)
        #expect(key == "ru-2026-02-19")
    }

    @Test
    func deterministicIndexIsStable() {
        let key = "en-2026-02-19"

        let first = QuoteDayKey.deterministicIndex(for: key, count: 10)
        let second = QuoteDayKey.deterministicIndex(for: key, count: 10)

        #expect(first == second)
    }

    @Test
    func deterministicIndexHandlesZeroCount() {
        #expect(QuoteDayKey.deterministicIndex(for: "en-2026-02-19", count: 0) == 0)
    }

    @Test
    func dayKeyHandlesYearBoundary() {
        let tz = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let date = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 0, minute: 5))!

        let key = QuoteDayKey.value(for: date, locale: "en", calendar: calendar, timeZone: tz)
        #expect(key == "en-2027-01-01")
    }
}
