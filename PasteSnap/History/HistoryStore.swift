import AppKit

/// JSON-backed history store with LRU eviction (max 10 items).
/// Thread-safe via NSLock.
final class HistoryStore: @unchecked Sendable {
    static let maxItems = 10

    private let fileURL: URL
    private let lock = NSLock()
    private var history: HistoryJSON

    init() {
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PasteSnap", isDirectory: true)
        self.fileURL = supportDir.appendingPathComponent("history.json")

        // Create directory (blocking, with logging)
        if !FileManager.default.fileExists(atPath: supportDir.path) {
            do {
                try FileManager.default.createDirectory(
                    at: supportDir, withIntermediateDirectories: true)
                NSLog("[PasteSnap] HistoryStore: created \(supportDir.path)")
            } catch {
                NSLog("[PasteSnap] HistoryStore: FAILED to create directory: \(error)")
            }
        }

        // Load existing
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(HistoryJSON.self, from: data) {
            self.history = decoded
        } else {
            self.history = HistoryJSON(items: [])
        }
    }

    // MARK: Public

    var items: [HistoryItem] {
        lock.lock(); defer { lock.unlock() }
        return history.items
    }

    func addItem(_ item: HistoryItem) {
        lock.lock()
        defer { lock.unlock() }

        history.items.insert(item, at: 0)

        // LRU eviction
        while history.items.count > Self.maxItems {
            let evicted = history.items.removeLast()
            // Delete evicted image
            if FileManager.default.fileExists(atPath: evicted.imagePath) {
                try? FileManager.default.removeItem(atPath: evicted.imagePath)
            }
        }

        // Save to disk
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(history) {
            do {
                try data.write(to: fileURL, options: .atomic)
                NSLog("[PasteSnap] HistoryStore: saved \(history.items.count) items")
            } catch {
                NSLog("[PasteSnap] HistoryStore: save FAILED: \(error)")
            }
        }
    }

    func latestImage() -> NSImage? {
        lock.lock(); defer { lock.unlock() }
        guard let latest = history.items.first else { return nil }
        return NSImage(contentsOfFile: latest.imagePath)
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        for item in history.items {
            try? FileManager.default.removeItem(atPath: item.imagePath)
        }
        history.items = []
        try? Data().write(to: fileURL)
    }
}

/// Codable history container.
struct HistoryJSON: Codable {
    var items: [HistoryItem]
}

/// Single history entry.
struct HistoryItem: Codable, Identifiable {
    let id: UUID
    let text: String
    let imagePath: String
    let theme: String
    let createdAt: TimeInterval

    init(id: UUID = UUID(), text: String, imagePath: String, theme: String) {
        self.id = id
        self.text = String(text.prefix(200))
        self.imagePath = imagePath
        self.theme = theme
        self.createdAt = Date().timeIntervalSince1970
    }
}
