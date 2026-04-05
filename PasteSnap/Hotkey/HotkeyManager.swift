import Foundation
import AppKit

/// ⌘⇧V global hotkey.
/// Uses NSEvent.addGlobalMonitorForEvents — works after the app is activated once.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var imageSupplier: (() -> NSImage?)?
    private var isInstalled = false

    private init() {}

    func install(imageSupplier: @escaping () -> NSImage?) {
        guard !isInstalled else { return }
        self.imageSupplier = imageSupplier
        isInstalled = true

        // Local monitor (app active/menu open)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.isPasteShortcut(event) {
                self.triggerPaste()
                return nil
            }
            return event
        }

        // Global monitor (app in background) — requires Accessibility permission for LSUIElement
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if self.isPasteShortcut(event) {
                self.triggerPaste()
            }
        }

        NSLog("[PasteSnap] ⌘⇧V hotkey installed")
    }

    func uninstall() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        imageSupplier = nil
        isInstalled = false
    }

    private func isPasteShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags == [.command, .shift] && event.keyCode == 0x09 // V
    }

    func triggerPaste() {
        guard let supplier = imageSupplier, let image = supplier() else {
            NSLog("[PasteSnap] ⌘⇧V — no image to paste")
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        if let tiff = image.tiffRepresentation {
            pb.declareTypes([.tiff, .png], owner: nil)
            pb.setData(tiff, forType: .tiff)
            if let bm = NSBitmapImageRep(data: tiff),
               let png = bm.representation(using: .png, properties: [:]) {
                pb.setData(png, forType: .png)
            }
            NSLog("[PasteSnap] ⌘⇧V — image pasted")
        }
    }
}
