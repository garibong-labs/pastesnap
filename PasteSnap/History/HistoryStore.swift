import Foundation

/// JSON-backed history store with LRU eviction (max 10 items).
/// Thread-safe via serial queue for file I/O.
final class HistoryStore: @unchecked Sendable {
    static let maxItems = 10

    private let fileURL: URL
    private let historyDirectoryURL: URL
    private let lock = NSLock()
    private var history: HistoryJSON

    init() {
        let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("PasteSnap", isDirectory: true)
        self.historyDirectoryURL = supportDir
        self.fileURL = supportDir.appendingPathComponent("history.json")

        // Create directories if needed
        if !self.historyDirectoryURL.hasDirectoryPath {
            try? FileManager.default.createDirectory(
                at: self.historyDirectoryURL,
                withIntermediateDirectories: true
            )
        }

        // Load existing data
        if let data = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(HistoryJSON.self, from: data) {
            self.history = decoded
        } else {
            self.history = HistoryJSON(items: [])
        }
    }

    // MARK: Public API

    var items: [HistoryItem] {
        lock.lock(); defer { lock.unlock() }
        return history.items
    }

    func addItem(_ item: HistoryItem) {
        lock.lock()
        defer { lock.unlock() }

        history.items.insert(item, at: 0)

        // LRU eviction
        if history.items.count > Self.maxItems {
            let evicted = history.items.removeLast()
            deleteFile(at: evicted.imagePath)
        }

        save()
    }

    func latestItem() -> HistoryItem? {
        lock.lock(); defer { lock.unlock() }
        return history.items.first
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        // Delete all image files
        for item in history.items {
            deleteFile(at: item.imagePath)
        }
        history.items = []
        save()
    }

    // MARK: Private

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        try? encoder.encode(history).write(to: fileURL)
    }

    private func deleteFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
