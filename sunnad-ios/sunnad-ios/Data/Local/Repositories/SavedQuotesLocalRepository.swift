import Foundation
import SwiftData

@MainActor
final class SavedQuotesLocalRepository {
    private let modelContext: ModelContext
    private let ownerScopeProvider: LocalOwnerScopeProviding

    init(modelContext: ModelContext, ownerScopeProvider: LocalOwnerScopeProviding) {
        self.modelContext = modelContext
        self.ownerScopeProvider = ownerScopeProvider
    }

    func fetchSavedQuotes() throws -> [SavedQuote] {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let descriptor = FetchDescriptor<SavedQuoteEntity>(
            predicate: #Predicate { $0.ownerScope == ownerScope },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.asDomainSavedQuote()}
    }

    func save(_ savedQuote: SavedQuote) throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        if let quoteID = savedQuote.quoteID {
            let descriptor = FetchDescriptor<SavedQuoteEntity>(
                predicate: #Predicate { $0.quoteID == quoteID && $0.ownerScope == ownerScope }
            )
            if try modelContext.fetch(descriptor).first != nil {
                return
            }
        }

        let entity = SavedQuoteEntity(
            id: savedQuote.id,
            ownerScope: ownerScope,
            quoteID: savedQuote.quoteID,
            text: savedQuote.text,
            author: savedQuote.author,
            savedAt: savedQuote.savedAt
        )

        modelContext.insert(entity)
        try modelContext.save()
    }

    func deleteAll() throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let descriptor = FetchDescriptor<SavedQuoteEntity>(predicate: #Predicate { $0.ownerScope == ownerScope })
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
        try modelContext.save()
    }
}
