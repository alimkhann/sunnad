import Foundation
import SwiftData

@Model
final class SavedQuoteEntity {
    @Attribute(.unique) var id: UUID
    var quoteID: UUID?
    var text: String
    var author: String
    var savedAt: Date

    init(id: UUID, quoteID: UUID?, text: String, author: String, savedAt: Date) {
        self.id = id
        self.quoteID = quoteID
        self.text = text
        self.author = author
        self.savedAt = savedAt
    }
}

extension SavedQuoteEntity {
    func apply(_ savedQuote: SavedQuote) {
        id = savedQuote.id
        quoteID = savedQuote.quoteID
        text = savedQuote.text
        author = savedQuote.author
        savedAt = savedQuote.savedAt
    }

    func asDomainSavedQuote() -> SavedQuote {
        SavedQuote(id: id, quoteID: quoteID, text: text, author: author, savedAt: savedAt)
    }
}
