import AppKit

// Traditional main.swift entry point (no @main).
// This avoids Swift 6 concurrency issues with @main + NSApplication.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu bar only, no dock icon
app.activate(ignoringOtherApps: false)
app.run()
