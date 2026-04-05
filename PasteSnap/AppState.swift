import Foundation
import AppKit

/// Central application state.
@MainActor
final class AppState: ObservableObject {
    @Published var isMonitoring: Bool = false
    @Published var statusMessage: String = "Idle"
    @Published var theme: String

    private var clipboardMonitor: ClipboardMonitor?
    private let historyStore: HistoryStore
    private let hotkeyManager = HotkeyManager.shared

    init() {
        self.theme = UserDefaults.standard.string(forKey: "PST_selectedTheme") ?? "dark-code"
        self.historyStore = HistoryStore()
    }

    func start() {
        NSLog("[PasteSnap] AppState.start() called")

        // Clipboard monitor
        let monitor = ClipboardMonitor { [weak self] change in
            Task { @MainActor [weak self] in
                await self?.onClipboardChange(change)
            }
        }
        self.clipboardMonitor = monitor
        monitor.start()

        isMonitoring = true
        statusMessage = "Monitoring clipboard..."

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
        let currentTheme = theme
        NSLog("[PasteSnap] Processing clipboard change (theme=\(currentTheme))")

        Task.detached {
            let cardTheme = CardTheme.from(identifier: currentTheme)
            let config = CardConfig(text: change.newText, theme: cardTheme)

            do {
                let fileURL = try CardRenderer.render(config: config)
                NSLog("[PasteSnap] Rendered card: \(fileURL.path)")

                // Write image to pasteboard immediately for instant paste
                let nsImage = NSImage(contentsOf: fileURL)
                if let image = nsImage, let tiff = image.tiffRepresentation {
                    let pb = NSPasteboard.general
                    pb.declareTypes([.tiff, .png], owner: nil)
                    pb.setData(tiff, forType: .tiff)
                    if let bitmap = NSBitmapImageRep(data: tiff),
                       let png = bitmap.representation(using: .png, properties: [:]) {
                        pb.setData(png, forType: .png)
                    }
                }

                // Save to history (for ⌘⇧V later)
                let item = HistoryItem(
                    text: change.newText,
                    imagePath: fileURL.path,
                    theme: cardTheme.identifier
                )

                await MainActor.run {
                    self.historyStore.addItem(item)

                    // Update menu state
                    self.statusMessage = "Card saved: \(fileURL.lastPathComponent)"
                    NSLog("[PasteSnap] Card saved and added to history (\(self.historyStore.items.count) items)")

                    // Theme checkmarks updated by MenuBarController.setTheme
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
