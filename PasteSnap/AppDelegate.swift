import AppKit
import Foundation

/// Main application delegate — created via main.swift NIB-less bootstrap.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var shared: AppDelegate?
    
    private var appState: AppState?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSLog("[PasteSnap] applicationDidFinishLaunching — wiring subsystems")

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
