import Foundation

struct Quote: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var locale: String
    var text: String
    var source: String?
    var sortOrder: Int
    var active: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        locale: String,
        text: String,
        source: String?,
        sortOrder: Int = 0,
        active: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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

struct SavedQuote: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var quoteID: UUID?
    var text: String
    var author: String
    var savedAt: Date

    init(
        id: UUID = UUID(),
        quoteID: UUID? = nil,
        text: String,
        author: String,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.quoteID = quoteID
        self.text = text
        self.author = author
        self.savedAt = savedAt
    }
}
