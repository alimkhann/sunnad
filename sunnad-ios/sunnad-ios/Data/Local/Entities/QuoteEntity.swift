import Foundation
import SwiftData

@Model
final class QuoteEntity {
    @Attribute(.unique) var id: UUID
    var locale: String
    var text: String
    var source: String?
    var sortOrder: Int
    var active: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        locale: String,
        text: String,
        source: String?,
        sortOrder: Int,
        active: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.locale = locale
        self.text = text
        self.source = source
        self.sortOrder = sortOrder
        self.active = active
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension QuoteEntity {
    func apply(_ quote: Quote) {
        id = quote.id
        locale = quote.locale
        text = quote.text
        source = quote.source
        sortOrder = quote.sortOrder
        active = quote.active
        createdAt = quote.createdAt
        updatedAt = quote.updatedAt
    }

    func asDomainQuote() -> Quote {
        Quote(
            id: id,
            locale: locale,
            text: text,
            source: source,
            sortOrder: sortOrder,
            active: active,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
