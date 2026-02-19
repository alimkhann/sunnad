import Foundation
import SwiftData

@MainActor
final class SavedQuotesLocalRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSavedQuotes() throws -> [SavedQuote] {
        let descriptor = FetchDescriptor<SavedQuoteEntity>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.asDomainSavedQuote()}
    }

    func save(_ savedQuote: SavedQuote) throws {
        if let quoteID = savedQuote.quoteID {
            let descriptor = FetchDescriptor<SavedQuoteEntity>(predicate: #Predicate { $0.quoteID == quoteID })
            if try modelContext.fetch(descriptor).first != nil {
                return
            }
        }

        let entity = SavedQuoteEntity(
            id: savedQuote.id,
            quoteID: savedQuote.quoteID,
            text: savedQuote.text,
            author: savedQuote.author,
            savedAt: savedQuote.savedAt
        )

        modelContext.insert(entity)
        try modelContext.save()
    }
}
