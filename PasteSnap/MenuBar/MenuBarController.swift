import AppKit
import Foundation

/// Controls the NSStatusItem and its associated menu.
@MainActor
final class MenuBarController {
    private static weak var sharedInstance: MenuBarController?

    private let statusItem: NSStatusItem
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupMenuBarIcon()
        setupMenu()
        
        // Register after menu is set up
        Self.sharedInstance = self
    }

    private func setupMenuBarIcon() {
        let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "PasteSnap")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = image
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Status label
        let statusItem = NSMenuItem(title: "Monitoring", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

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

        menu.addItem(NSMenuItem.separator())

        // History
        let histItem = NSMenuItem(title: "📋 History", action: #selector(showHistory), keyEquivalent: "")
        histItem.target = self
        menu.addItem(histItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "❌ Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: Static (called from AppState)

    /// Update theme checkmarks in the menu bar menu after theme switch.
    static func updateThemeCheckmarks() {
        guard let me = Self.sharedInstance else { return }
        guard let menu = me.statusItem.menu else { return }
        for item in menu.items {
            guard let themeId = item.representedObject as? String else { continue }
            item.state = me.appState.theme == themeId ? .on : .off
        }
    }

    // MARK: Actions

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let themeId = sender.representedObject as? String else { return }
        appState.setTheme(themeId)

        // Update checkmarks
        guard let menu = statusItem.menu else { return }
        for item in menu.items {
            guard let tid = item.representedObject as? String else { continue }
            item.state = appState.theme == tid ? .on : .off
        }

        // Update status label
        menu.items.first?.title = "Theme: \(themeId)"
    }

    @objc private func showHistory() {
        appState.showHistory()
    }

    @objc private func quitApp() {
        appState.cleanupAndQuit()
    }

    private func themeMenuItemTitle(_ theme: CardTheme) -> String {
        switch theme.identifier {
        case "dark-code":    return "🌑 Theme: Dark Code"
        case "light-quote":  return "☀️ Theme: Light Quote"
        case "minimal-gray": return "⬜ Theme: Minimal Gray"
        default:             return "Theme: \(theme.identifier)"
        }
    }
}
