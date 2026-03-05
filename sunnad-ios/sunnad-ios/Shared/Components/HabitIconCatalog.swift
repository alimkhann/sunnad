import SwiftUI
import UIKit

enum HabitIconCatalog {
    static let canonicalKeys: [String] = [
        "star.fill",
        "heart.fill",
        "sun.max.fill",
        "sunrise.fill",
        "moon.stars.fill",
        "moon.fill",
        "book.closed.fill",
        "book.fill",
        "text.book.closed.fill",
        "bookmark.fill",
        "figure.run",
        "figure.walk",
        "dumbbell.fill",
        "flame.fill",
        "bolt.fill",
        "drop.fill",
        "leaf.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "bed.double.fill",
        "alarm.fill",
        "clock.fill",
        "calendar",
        "checkmark.circle.fill",
        "target",
        "brain.head.profile",
        "sparkles",
        "hands.sparkles.fill",
        "building.columns.fill",
        "person.2.fill",
        "figure.2.and.child.holdinghands",
        "phone.fill",
        "message.fill",
        "briefcase.fill",
        "chart.bar.fill",
        "banknote.fill",
        "creditcard.fill",
        "cart.fill",
        "graduationcap.fill",
        "paintpalette.fill",
        "music.note",
        "globe"
    ]

    static let availableSFSymbols: [String] = canonicalKeys.filter { UIImage(systemName: $0) != nil }

    static func canonicalKey(for raw: String, title: String = "") -> String {
        let source = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let titleLower = title.lowercased()

        if canonicalKeys.contains(source) {
            return source
        }

        if ["sun", "sunrise", "wb_sunny", "wbsunny"].contains(source) || titleLower.contains("morning") {
            return "sunrise.fill"
        }
        if ["moon", "bedtime"].contains(source) || titleLower.contains("evening") {
            return "moon.fill"
        }
        if ["book", "menu_book", "graduationcap", "graduationcap.fill"].contains(source) || titleLower.contains("quran") || titleLower.contains("surah") {
            return "book.closed.fill"
        }
        if source.contains("run") || source.contains("fitness") || titleLower.contains("exercise") {
            return "figure.run"
        }
        if source.contains("group") || source.contains("person") {
            return "person.2.fill"
        }
        if source.contains("money") || source.contains("credit") || source.contains("cart") {
            return "banknote.fill"
        }
        if source.contains("prayer") || source == "mosque" || titleLower.contains("prayer") || titleLower.contains("намаз") {
            return "building.columns.fill"
        }
        if source.contains("dhikr") {
            return "sparkles"
        }

        return "star.fill"
    }
}
