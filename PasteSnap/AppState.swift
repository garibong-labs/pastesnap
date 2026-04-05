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
    private var lastGeneratedImage: NSImage?

    init() {
        self.theme = UserDefaults.standard.string(forKey: "PST_selectedTheme") ?? "dark-code"
        self.historyStore = HistoryStore()
    }

    func start() {
        print("[PasteSnap] AppState.start() called")

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

        // Hotkey
        hotkeyManager.install { [weak self] in
            self?.lastGeneratedImage
        }

        print("[PasteSnap] All subsystems started")
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
                let date = Date(timeIntervalSince1970: item.createdAt)
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd HH:mm"
                return "• [\(item.theme)] \(formatter.string(from: date)) — \(item.text.prefix(40))"
            }.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func cleanupAndQuit() {
        clipboardMonitor?.stop()
        hotkeyManager.uninstall()
        NSApplication.shared.terminate(nil)
    }

    private func onClipboardChange(_ change: ClipboardChange) {
        print("[PasteSnap] Processing clipboard change (theme=\(theme))")

        let currentTheme = self.theme

        Task.detached { [weak self] in
            guard let self else { return }

            let theme = CardTheme.from(identifier: currentTheme)
            let config = CardConfig(text: change.newText, theme: theme)

            do {
                let fileURL = try CardRenderer.render(config: config)
                print("[PasteSnap] Rendered card: \(fileURL.path)")

                let nsImage = NSImage(contentsOf: fileURL)

                await MainActor.run {
                    self.lastGeneratedImage = nsImage

                    // Write to pasteboard so user can Cmd+V immediately
                    let pb = NSPasteboard.general
                    pb.declareTypes([.tiff, .png], owner: nil)
                    if let image = nsImage, let tiff = image.tiffRepresentation {
                        pb.setData(tiff, forType: .tiff)
                        if let bitmap = NSBitmapImageRep(data: tiff),
                           let png = bitmap.representation(using: .png, properties: [:]) {
                            pb.setData(png, forType: .png)
                        }
                    }

                    self.historyStore.addItem(HistoryItem(
                        text: change.newText,
                        imagePath: fileURL.path,
                        theme: theme.identifier
                    ))

                    self.statusMessage = "Card saved: \(fileURL.lastPathComponent)"
                    print("[PasteSnap] Card saved and added to history")
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Render error: \(error.localizedDescription)"
                    print("[PasteSnap] Render error: \(error)")
                }
            }
        }
    }
}
