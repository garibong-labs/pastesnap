import AppKit
import Foundation

/// Controls the NSStatusItem and its associated menu.
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupMenuBarIcon()
        setupMenu()
    }

    // MARK: Menu Bar Icon

    private func setupMenuBarIcon() {
        let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "PasteSnap")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = image
    }

    // MARK: Menu Setup

    private func setupMenu() {
        let menu = NSMenu()

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Theme items
        for theme in CardTheme.allThemes {
            let item = NSMenuItem(
                title: themeMenuItemTitle(theme),
                action: #selector(selectTheme(_:)),
                keyEquivalent: ""
            )
            item.representedObject = theme.identifier
            item.state = appState.theme == theme.identifier ? .on : .off
            item.target = self
            menu.addItem(item)
        }

        // Separator
        menu.addItem(NSMenuItem.separator())

        // History
        let historyMenuItem = NSMenuItem(
            title: "📋 History",
            action: #selector(showHistory),
            keyEquivalent: ""
        )
        historyMenuItem.target = self
        menu.addItem(historyMenuItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "❌ Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: Actions

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let themeId = sender.representedObject as? String else { return }
        appState.setTheme(themeId)
        updateMenuThemeStates()
    }

    @objc private func showHistory() {
        appState.showHistory()
    }

    @objc private func quitApp() {
        appState.cleanupAndQuit()
    }

    // MARK: Menu Helpers

    private func themeMenuItemTitle(_ theme: CardTheme) -> String {
        switch theme.identifier {
        case "dark-code":  return "🌑 Theme: Dark Code"
        case "light-quote": return "☀️ Theme: Light Quote"
        case "minimal-gray": return "⬜ Theme: Minimal Gray"
        default:          return "Theme: \(theme.identifier)"
        }
    }

    private func updateMenuThemeStates() {
        guard let menu = statusItem.menu else { return }
        for item in menu.items {
            guard let themeId = item.representedObject as? String else { continue }
            item.state = appState.theme == themeId ? .on : .off
        }
    }
}
