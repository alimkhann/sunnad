import Foundation

struct PendingChange: Codable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case toggleHabit(UUID)
        case dhikrIncrement(UUID)
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date

    init(id: UUID = UUID(), kind: Kind, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
    }
}

extension PendingChange {
    private enum KindCodingKeys: String, CodingKey {
        case type
        case habitID
    }

    private enum KindType: String, Codable {
        case toggleHabit = "toggle_habit"
        case dhikrIncrement = "dhikr_increment"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()

        let kindContainer = try container.nestedContainer(keyedBy: KindCodingKeys.self, forKey: .kind)
        let type = try kindContainer.decode(KindType.self, forKey: .type)
        let habitID = try kindContainer.decode(UUID.self, forKey: .habitID)
        switch type {
        case .toggleHabit:
            kind = .toggleHabit(habitID)
        case .dhikrIncrement:
            kind = .dhikrIncrement(habitID)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)

        var kindContainer = container.nestedContainer(keyedBy: KindCodingKeys.self, forKey: .kind)
        switch kind {
        case .toggleHabit(let habitID):
            try kindContainer.encode(KindType.toggleHabit, forKey: .type)
            try kindContainer.encode(habitID, forKey: .habitID)
        case .dhikrIncrement(let habitID):
            try kindContainer.encode(KindType.dhikrIncrement, forKey: .type)
            try kindContainer.encode(habitID, forKey: .habitID)
        }
    }
}

enum PendingChangeQueue {
    /// Appends a change, deduplicating by id. Order is append (oldest first).
    static func appending(_ change: PendingChange, to existing: [PendingChange]) -> [PendingChange] {
        guard !existing.contains(where: { $0.id == change.id }) else {
            return existing
        }
        return existing + [change]
    }

    static func merging(_ changes: [PendingChange], into existing: [PendingChange]) -> [PendingChange] {
        var result = existing
        for change in changes {
            result = appending(change, to: result)
        }
        return result
    }

    /// Oldest-first ordering for replay.
    static func replayOrder(_ changes: [PendingChange]) -> [PendingChange] {
        changes.sorted { $0.createdAt < $1.createdAt }
    }
}
