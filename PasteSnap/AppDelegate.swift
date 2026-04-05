import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var shared: AppDelegate?
    
    private var appState: AppState?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSLog("[PasteSnap] applicationDidFinishLaunching — wiring subsystems")

        let state = AppState()
        self.appState = state

        self.statusItemController = StatusItemController(appState: state)

        state.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.cleanupAndQuit()
    }
}
