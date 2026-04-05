import Foundation
import AppKit

/// Manages the ⌘⇧V hotkey.
/// Uses NSEvent local monitor (when app is active) + global monitor (when app is in background).
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    /// Supplier closure that returns the image to paste.
    private var imageSupplier: (() -> NSImage?)?

    /// Strong reference required — the monitor stops if this is released.
    private var localMonitor: Any?

    private var isInstalled = false

    private init() {}

    // MARK: Public

    /// Install key event monitors.
    /// `imageSupplier` is called on each ⌘⇧V press to retrieve the last card image.
    func install(imageSupplier: @escaping () -> NSImage?) {
        guard !isInstalled else { return }
        self.imageSupplier = imageSupplier

        // Local monitor: fires when the app has focus/eats key events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self, self.matchesPaste(event: event) else { return event }
            self.pasteLastImage()
            return nil // consume
        }

        // Global monitor: fires even when app is in background (menu bar only)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.matchesPaste(event: event) else { return }
            self.pasteLastImage()
        }

        isInstalled = true
    }

    func uninstall() {
        isInstalled = false
        localMonitor = nil
        imageSupplier = nil
    }

    // MARK: Private

    private func matchesPaste(event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags == [.command, .shift] && event.keyCode == 0x09  // V key
    }

    private func pasteLastImage() {
        guard let image = imageSupplier?() else { return }
        writeImageToPasteboard(image)
    }

    private func writeImageToPasteboard(_ image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.declareTypes([.tiff, .png], owner: nil)

        if let tiff = image.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }

        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            pb.setData(png, forType: .png)
        }
    }
}
