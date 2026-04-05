import Foundation
import AppKit

/// Central application state.
@MainActor
final class AppState: ObservableObject {
    @Published var isMonitoring: Bool = false
    @Published var statusMessage: String = "Idle"
    @Published var theme: String
    @Published var enabled: Bool

    private var clipboardMonitor: ClipboardMonitor?
    private let historyStore: HistoryStore
    private let hotkeyManager = HotkeyManager.shared

    static let minTriggerLength: Int = 10

    init() {
        self.theme = UserDefaults.standard.string(forKey: "PST_selectedTheme") ?? "dark-code"
        self.enabled = !UserDefaults.standard.bool(forKey: "PST_disabled")
        self.historyStore = HistoryStore()
    }

    func start() {
        NSLog("[PasteSnap] AppState.start() called (enabled=\(self.enabled))")

        // Clipboard monitor
        let monitor = ClipboardMonitor { [weak self] change in
            Task { @MainActor [weak self] in
                await self?.onClipboardChange(change)
            }
        }
        self.clipboardMonitor = monitor
        monitor.start()

        isMonitoring = true
        statusMessage = enabled ? "Monitoring..." : "Paused"

        // Hotkey: ⌘⇧V → paste last generated image from history
        hotkeyManager.install { [weak self] in
            self?.historyStore.latestImage()
        }

        NSLog("[PasteSnap] All subsystems started")
    }

    func setTheme(_ themeId: String) {
        self.theme = themeId
        UserDefaults.standard.set(themeId, forKey: "PST_selectedTheme")
    }

    func toggleEnabled() {
        enabled.toggle()
        UserDefaults.standard.set(!enabled, forKey: "PST_disabled")
        statusMessage = enabled ? "Monitoring..." : "Paused"
        NSLog("[PasteSnap] \(enabled ? "Enabled" : "Disabled")")
    }

    func showHistory() {
        let items = historyStore.items
        let alert = NSAlert()
        alert.messageText = "PasteSnap History"
        alert.informativeText = items.isEmpty
            ? "No clipboard cards generated yet."
            : items.map { item in
                let d = Date(timeIntervalSince1970: item.createdAt)
                let fmt = DateFormatter()
                fmt.dateFormat = "MM/dd HH:mm"
                return "• [\(item.theme)] \(fmt.string(from: d)) — \(item.text.prefix(40))"
            }.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func cleanupAndQuit() {
        clipboardMonitor?.stop()
        hotkeyManager.uninstall()
        NSApplication.shared.terminate(nil)
    }

    // MARK: Clipboard Change

    private func onClipboardChange(_ change: ClipboardChange) {
        // Skip when disabled
        guard enabled else { return }

        // Skip short text (URLs, single words, etc.)
        guard change.newText.count >= Self.minTriggerLength else {
            NSLog("[PasteSnap] Skipping short text (\(change.newText.count) chars)")
            return
        }

        let currentTheme = theme
        NSLog("[PasteSnap] Processing clipboard change: '\(change.newText.prefix(40))...' (\(change.newText.count) chars)")

        Task.detached {
            let cardTheme = CardTheme.from(identifier: currentTheme)
            let config = CardConfig(text: change.newText, theme: cardTheme)

            do {
                let fileURL = try CardRenderer.render(config: config)
                NSLog("[PasteSnap] Rendered card: \(fileURL.path)")

                // Save to history (for ⌘⇧V later)
                let item = HistoryItem(
                    text: change.newText,
                    imagePath: fileURL.path,
                    theme: cardTheme.identifier
                )

                await MainActor.run {
                    self.historyStore.addItem(item)
                    self.statusMessage = "Card saved (\(self.historyStore.items.count))"
                    NSLog("[PasteSnap] Card saved and added to history (\(self.historyStore.items.count) items)")
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Render error: \(error.localizedDescription)"
                    NSLog("[PasteSnap] Render error: \(error)")
                }
            }
        }
    }
}
