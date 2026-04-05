import Foundation

/// A single history entry representing a generated card image.
struct HistoryItem: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let text: String
    let imagePath: String
    let theme: String
    let createdAt: Double

    init(id: String = UUID().uuidString,
         text: String,
         imagePath: String,
         theme: String,
         createdAt: Double = Date().timeIntervalSince1970) {
        self.id = id
        self.text = String(text.prefix(100))
        self.imagePath = imagePath
        self.theme = theme
        self.createdAt = createdAt
    }
}

/// Container for JSON serialization.
struct HistoryJSON: Codable {
    var items: [HistoryItem]
}
