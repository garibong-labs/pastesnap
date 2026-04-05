import AppKit
import Foundation

/// NSObject bridge for NSMenu target/action dispatch.
/// Uses DispatchQueue.main.asyncMainActor를 피하기 위해 직접 MainActor.run.
@objc final class ActionTarget: NSObject {
    // Non-Sendable closures — called from Obj-C runtime (nonisolated).
    // We dispatch to MainActor via DispatchQueue.main.async.
    private let themeClosure: (String) -> Void
    private let historyClosure: () -> Void
    private let quitClosure: () -> Void

    /// Accepts closures that are safe to call from nonisolated context.
    /// Each closure internally dispatches to @MainActor.
    init(
        onTheme: @escaping (String) -> Void,
        onHistory: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.themeClosure = onTheme
        self.historyClosure = onHistory
        self.quitClosure = onQuit
        super.init()
    }

    @objc func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        themeClosure(id)
    }

    @objc func showHistoryAction() {
        historyClosure()
    }

    @objc func quitAppAction() {
        quitClosure()
    }
}

// MARK: - Status Item Controller
@MainActor
final class StatusItemController {
    let statusItem: NSStatusItem
    private let menu = NSMenu(title: "PasteSnap")
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let target = ActionTarget(
            onTheme: { id in
                DispatchQueue.main.async {
                    Task { @MainActor [weak appState] in
                        appState?.setTheme(id)
                    }
                }
            },
            onHistory: {
                DispatchQueue.main.async {
                    Task { @MainActor [weak appState] in
                        appState?.showHistory()
                    }
                }
            },
            onQuit: {
                DispatchQueue.main.async {
                    Task { @MainActor [weak appState] in
                        appState?.cleanupAndQuit()
                    }
                }
            }
        )

        buildMenu(target: target)
        setupIcon()

        NSLog("[PasteSnap] StatusItemController initialized")
    }

    private func setupIcon() {
        let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "PasteSnap")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = image
        statusItem.menu = menu
    }

    private func buildMenu(target: ActionTarget) {
        menu.autoenablesItems = false

        let statusItem = NSMenuItem(title: "Monitoring", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())

        let themes = [
            ("dark-code", "🌑 Theme: Dark Code"),
            ("light-quote", "☀️ Theme: Light Quote"),
            ("minimal-gray", "⬜ Theme: Minimal Gray"),
        ]

        for (id, title) in themes {
            let item = NSMenuItem(
                title: title,
                action: #selector(ActionTarget.selectTheme(_:)),
                keyEquivalent: ""
            )
            item.representedObject = id
            item.target = target
            item.state = appState?.theme == id ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let histItem = NSMenuItem(
            title: "📋 History",
            action: #selector(ActionTarget.showHistoryAction),
            keyEquivalent: ""
        )
        histItem.target = target
        menu.addItem(histItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(ActionTarget.quitAppAction),
            keyEquivalent: "q"
        )
        quitItem.target = target
        menu.addItem(quitItem)

        NSLog("[PasteSnap] Menu built with \(menu.numberOfItems) items")
    }

    func updateThemeCheckmarks() {
        for item in menu.items {
            guard let tid = item.representedObject as? String else { continue }
            item.state = appState?.theme == tid ? .on : .off
        }
    }
}
