import Foundation

protocol QuotesRepository: Sendable {
    func fetchQuoteOfDay(locale: String, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> Quote?
    func fetchSavedQuotes() async throws -> [SavedQuote]
    func saveQuote(_ quote: Quote, savedAt: Date) async throws
    func deleteAllSavedQuotes() async throws
}
