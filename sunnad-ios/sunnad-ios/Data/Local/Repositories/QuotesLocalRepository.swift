import Foundation
import SwiftData

@MainActor
final class QuotesLocalRepository: QuotesRepository {
    private let modelContext: ModelContext
    private let savedQuotesRepository: SavedQuotesLocalRepository
    private let logger: AnalyticsLogging

    init(modelContext: ModelContext, logger: AnalyticsLogging) {
        self.modelContext = modelContext
        self.savedQuotesRepository = SavedQuotesLocalRepository(modelContext: modelContext)
        self.logger = logger
    }

    func fetchQuoteOfDay(locale: String, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> Quote? {
        let localized = try fetchActiveQuotes(locale: locale)
        let fallback = localized.isEmpty ? try fetchActiveQuotes(locale: "en") : localized

        guard !fallback.isEmpty else {
            return nil
        }

        let dayKey = QuoteDayKey.value(for: day, locale: locale, calendar: calendar, timeZone: timeZone)
        let index = QuoteDayKey.deterministicIndex(for: dayKey, count: fallback.count)
        return fallback[index]
    }

    func fetchSavedQuotes() async throws -> [SavedQuote] {
        try savedQuotesRepository.fetchSavedQuotes()
    }

    func saveQuote(_ quote: Quote, savedAt: Date) async throws {
        let item = SavedQuote(
            quoteID: quote.id,
            text: quote.text,
            author: quote.source ?? "",
            savedAt: savedAt
        )

        try savedQuotesRepository.save(item)
        logger.log(.quoteSaved, metadata: ["quote_id": quote.id.uuidString])
    }

    func upsertQuotes(_ quotes: [Quote]) throws {
        for quote in quotes {
            let descriptor = FetchDescriptor<QuoteEntity>(predicate: #Predicate { $0.id == quote.id })
            if let entity = try modelContext.fetch(descriptor).first {
                entity.apply(quote)
            } else {
                modelContext.insert(
                    QuoteEntity(
                        id: quote.id,
                        locale: quote.locale,
                        text: quote.text,
                        source: quote.source,
                        sortOrder: quote.sortOrder,
                        active: quote.active,
                        createdAt: quote.createdAt,
                        updatedAt: quote.updatedAt
                    )
                )
            }
        }

        try modelContext.save()
    }

    private func fetchActiveQuotes(locale: String) throws -> [Quote] {
        let descriptor = FetchDescriptor<QuoteEntity>(
            predicate: #Predicate { $0.locale == locale && $0.active == true },
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )

        return try modelContext.fetch(descriptor).map { $0.asDomainQuote() }
    }
}
