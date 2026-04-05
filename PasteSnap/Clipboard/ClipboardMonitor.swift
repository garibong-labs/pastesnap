import Foundation
import AppKit

/// A change detected on the general pasteboard.
struct ClipboardChange: Sendable {
    let oldText: String
    let newText: String
    let timestamp: Double
}

/// Polls NSPasteboard.general for text changes on a 500ms timer.
final class ClipboardMonitor {
    static let minTextLength = 2
    static let maxTextLength = 2000
    static let pollingInterval: TimeInterval = 0.5

    private let onChange: (ClipboardChange) -> Void
    private var timer: Timer?
    private var lastText: String = ""

    init(onChange: @escaping (ClipboardChange) -> Void) {
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() {
        guard timer == nil else { return }

        lastText = currentTextFromPasteboard() ?? ""
        NSLog("[PasteSnap] Monitor started, initial text: '\(lastText.prefix(60))'")

        // Use .common mode so timer fires during UI tracking (menu, etc.)
        let t = Timer(
            timeInterval: Self.pollingInterval,
            target: self,
            selector: #selector(poll),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func poll() {
        guard let current = currentTextFromPasteboard() else { return }

        guard current != lastText else { return }

        let oldText = lastText
        lastText = current
        NSLog("[PasteSnap] Clipboard changed: '\(current.prefix(60))'")

        onChange(ClipboardChange(
            oldText: oldText,
            newText: current,
            timestamp: Date().timeIntervalSince1970
        ))
    }

    private func currentTextFromPasteboard() -> String? {
        let pb = NSPasteboard.general
        guard let text = pb.string(forType: .string),
              !text.isEmpty,
              text.count >= Self.minTextLength else {
            return nil
        }

        let truncated: String
        if text.count > Self.maxTextLength {
            truncated = String(text.prefix(Self.maxTextLength)) + "..."
        } else {
            truncated = text
        }
        return truncated
    }
}
