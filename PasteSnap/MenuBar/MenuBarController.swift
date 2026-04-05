import AppKit
import Foundation

// MARK: - Action Handler (plain NSObject, no actor isolation)
@objc class MenuActionHandler: NSObject {
    private var onThemeChange: ((String) -> Void)?
    private var onHistory: (() -> Void)?
    private var onQuit: (() -> Void)?

    func bind(
        onThemeChange: @escaping (String) -> Void,
        onHistory: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onThemeChange = onThemeChange
        self.onHistory = onHistory
        self.onQuit = onQuit
    }

    @objc func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onThemeChange?(id)
    }

    @objc func showHistory() {
        onHistory?()
    }

    @objc func quitApp() {
        onQuit?()
    }
}

// MARK: - Menu Bar Controller
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let handler = MenuActionHandler()

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        handler.bind(
            onThemeChange: { [weak self] id in
                self?.setTheme(id)
            },
            onHistory: { [weak self] in
                self?.appState.showHistory()
            },
            onQuit: { [weak self] in
                self?.appState.cleanupAndQuit()
            }
        )

        setupMenuBarIcon()
        setupMenu()

        NSLog("[PasteSnap] MenuBarController initialized, menu set")
    }

    private func setTheme(_ id: String) {
        appState.setTheme(id)
        updateThemeCheckmarks()
    }

    private func updateThemeCheckmarks() {
        guard let menu = statusItem.menu else { return }
        for item in menu.items {
            guard let tid = item.representedObject as? String else { continue }
            item.state = appState.theme == tid ? .on : .off
        }
    }

    private func setupMenuBarIcon() {
        let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "PasteSnap")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = image
    }

    private func setupMenu() {
        let menu = NSMenu(title: "PasteSnap")
        menu.autoenablesItems = false

        // Status label
        let statusItem = NSMenuItem(title: "Monitoring", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Theme items
        let themes = [
            ("dark-code", "🌑 Theme: Dark Code"),
            ("light-quote", "☀️ Theme: Light Quote"),
            ("minimal-gray", "⬜ Theme: Minimal Gray"),
        ]
        for (id, title) in themes {
            let item = NSMenuItem(title: title, action: #selector(MenuActionHandler.selectTheme(_:)), keyEquivalent: "")
            item.representedObject = id
            item.target = handler
            item.state = appState.theme == id ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // History
        let histItem = NSMenuItem(title: "📋 History", action: #selector(MenuActionHandler.showHistory), keyEquivalent: "")
        histItem.target = handler
        menu.addItem(histItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(MenuActionHandler.quitApp), keyEquivalent: "q")
        quitItem.target = handler
        menu.addItem(quitItem)

        statusItem.menu = menu
        NSLog("[PasteSnap] Menu configured with \(menu.numberOfItems) items")
    }
}
