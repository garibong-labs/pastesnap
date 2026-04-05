import AppKit
import Foundation

/// Application entry point.
/// Keeps AppDelegate alive as a static property so ARC doesn't collect it.
@main
struct PasteSnapApp {
    nonisolated(unsafe) static var appDelegate: AppDelegate?

    static func main() {
        let delegate = AppDelegate()
        Self.appDelegate = delegate
        NSApplication.shared.delegate = delegate
        _ = withExtendedLifetime(delegate) {
            NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
        }
    }
}

/// Main application delegate.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        self.appState = state

        let menuBar = MenuBarController(appState: state)
        self.menuBarController = menuBar

        state.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.cleanupAndQuit()
    }
}
