# PasteSnap — macOS Menu Bar App

**Objective:** Build a macOS menu bar app that converts clipboard text into beautifully styled card images.

## Architecture

```
PasteSnap/
├─ AppDelegate.swift          — NSApplicationDelegate, bootstraps menu bar
├─ AppState.swift             — ObservableObject, app lifecycle state
├─ MenuBar/
│  ├─ MenuBarController.swift —— NSStatusBar item + menu setup
│  └─ StatusIconView.swift   —— Simple SF Symbol menu bar icon
├─ Clipboard/
│  ├─ ClipboardMonitor.swift  — Timer-based NSPasteboard polling
│  └─ ClipboardChange.swift  — model (oldText, newText, timestamp)
├─ CardRenderer/
│  ├─ CardRenderer.swift     — Core Image / CGContext pipeline
│  ├─ CardTheme.swift        — theme definitions (enum 3 themes)
│  └─ CardConfig.swift       — input config (text lines, theme, size)
├─ History/
│  ├─ HistoryStore.swift     — JSON storage, max 10 items
│  └─ HistoryItem.swift      — model (id, text, imagePath, createdAt)
├─ Hotkey/
│  └─ HotkeyManager.swift    — ⌘⇧V paste-last-image handler
└─ Assets/
   └─ Assets.xcassets         — empty for now (menu bar icon later)
```

## Technical Specs

### Clipboard Monitor
- **Polling interval:** 500ms (debounced — ignore identical content)
- **Filter:** text only (skip image/URL changes)
- **Min length:** 2 characters (ignore single char noise)
- **Max text:** 2000 characters (truncate with "..." overflow)
- **Trigger:** on text change → generate card image → write image to NSPasteboard → save to history

### Card Themes (3 presets)

| Field | dark-code | light-quote | minimal-gray |
|-------|-----------|-------------|--------------|
| backgroundColor | #1E1E2E | #FDFCF8 | #F5F5F7 |
| cardBackground | #313244 | #FFFFFF | #FFFFFF |
| textColor | #CDD6F4 | #1D1D1F | #1D1D1F |
| accentColor | #89B4FA | #FF6B6B | #636366 |
| fontFamily | SFMono | Noteworthy Light | SF Pro Text |
| fontSize | 14 | 16 | 13 |
| fontStyle | Monospace (code layout) | Serif (quote layout) | Sans-serif (clean) |
| cornerRadius | 10 | 16 | 8 |
| padding | 32 | 48 | 24 |
| maxWidth | 680 | 600 | 640 |
| maxHeight | 400 | 420 | 360 |

### Image Generation Pipeline (Core Graphics)
1. Create NSImage/CGImage with calculated dimensions
2. Draw rounded-rectangle background card
3. Render text with word wrapping (NSAttributedString)
4. Add thin accent bar at top (6pt height, accentColor)
5. Add subtle drop shadow under card
6. Add "PasteSnap" watermark bottom-right (8pt, light gray)
7. Export as PNG to `~/Pictures/PasteSnap/` with timestamp filename

### Output Image Format
- **Size:** ~800x500 @2x (retina)
- **Format:** PNG
- **Path:** `~/Pictures/PasteSnap/<timestamp>.png`
- **Clipboard:** NSImage written to pasteboard as TIFF + PNG
- **Filename pattern:** `20260405-134522.png`

### History (JSON)
```json
{
  "items": [
    {
      "id": "uuid",
      "text": "first 100 chars...",
      "imagePath": "/Users/x/Pictures/PasteSnap/20260405-134522.png",
      "theme": "dark-code",
      "createdAt": 1744057522
    }
  ]
}
```
- Max 10 items, LRU eviction
- Stored at `~/Library/Application Support/PasteSnap/history.json`
- Cleanup: delete old image files when evicted from history

### Hotkey: ⌘⇧V (Cmd+Shift+V)
- Uses Carbon Event Manager (RegisterEventHotKey) or NSEvent local monitor
- On trigger: read last generated image from history → write to NSPasteboard → user can Cmd+V to paste as image
- **Important:** This hotkey writes the image to clipboard, it doesn't paste it. Standard Cmd+V then pastes it.

### Menu Bar Menu Items
- [icon] Always On: Clipboard → Image mode
- ─────
- 🌗 Theme: Dark Code (selected)
- ☀️ Theme: Light Quote
- ⬜ Theme: Minimal Gray
- ─────
- 📋 History (opens small window or submenu)
- ─────
- ❌ Quit

### App Behavior
- **Launch:** Start menu bar icon + clipboard monitor immediately
- **No dock icon:** LSUIElement=true (pure menubar app)
- **First launch alert:** "PasteSnap will monitor your clipboard for text. Generated images appear in ~/Pictures/PasteSnap/" (NSAlert once only)
- **Preferences:** Store in UserDefaults (theme selection, enabled toggle) (keep simple)

## Build Instructions
1. `cd ~/.openclaw/workspace/projects/pastesnap`
2. `xcodegen generate` — generates .xcodeproj from project.yml
3. `xcodebuild -scheme PasteSnap -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
4. Fix any build errors and re-verify
5. Run the app: `open build/Build/Products/Debug/PasteSnap.app`

## Important Constraints
- **Swift 6**: Swift concurrency is strict — use @MainActor for UI code
- **macOS 14+**: Can use modern APIs
- **No CocoaPods/SPM**: Keep it dependency-free for simplicity
- **Core Graphics for rendering**: NOT SwiftUI view-to-image (NSImage(repaint) offscreen) — use CGContext for reliable pixel output
- **project.yml already exists**: Don't modify it

## Current State
- `project.yml` already created with target spec
- Need to create ALL Swift source files
- The project.yml includes: Cocoa, Foundation, AppKit, SwiftUI, UniformTypeIdentifiers frameworks

## Source File Paths (all under PasteSnap/ directory)
- `PasteSnap/AppDelegate.swift`
- `PasteSnap/AppState.swift`
- `PasteSnap/MenuBar/MenuBarController.swift`
- `PasteSnap/Clipboard/ClipboardMonitor.swift`
- `PasteSnap/CardRenderer/CardTheme.swift`
- `PasteSnap/CardRenderer/Config.swift`
- `PasteSnap/CardRenderer/CardRenderer.swift`
- `PasteSnap/History/HistoryItem.swift`
- `PasteSnap/History/HistoryStore.swift`
- `PasteSnap/Hotkey/HotkeyManager.swift`
