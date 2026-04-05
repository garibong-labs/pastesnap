# PasteSnap

Clipboard text → pretty card image converter for macOS.

Copy text anywhere, PasteSnap automatically generates a styled card image and replaces your clipboard. Paste as an image with **⌘⇧V** or **Cmd+V** right after generation.

![screenshot](https://github.com/garibong-labs/pastesnap/raw/main/docs/screenshot.png)

## Features

- **Auto clipboard monitoring** — 500ms polling, detects text changes
- **3 card themes** — Dark Code, Light Quote, Minimal Gray
- **Instant paste** — generated image auto-writes to clipboard on generation
- **⌘⇧V hotkey** — paste the last generated image at any time
- **History** — stores last 10 generated cards with LRU eviction
- **Menu bar only** — no dock icon, lightweight (`~90 KB` binary)
- **macOS 14+** — Apple Silicon (arm64) only

## Install

1. Download the latest [Release DMG](https://github.com/garibong-labs/pastesnap/releases)
2. Drag `PasteSnap.app` to `/Applications`
3. Remove Gatekeeper quarantine:
   ```bash
   xattr -cr /Applications/PasteSnap.app
   ```
4. Double-click — clipboard monitoring starts immediately

First launch shows a welcome notification. No permissions required (standard clipboard, no accessibility or screen recording).

## Usage

| Action | How |
|--------|-----|
| **Copy text** | Select any text and Cmd+C — card auto-generates in ~2 seconds |
| **Paste as image** | After generation, Cmd+V where images are accepted (Slack, Twitter, etc.) |
| **Paste last image** | ⌘⇧V writes the most recent card to clipboard, then Cmd+V as usual |
| **Change theme** | Click menu bar icon → pick a theme |
| **View history** | Click menu bar icon → 📋 History |
| **Quit** | Click menu bar icon → Quit |

Generated images are saved to `~/Pictures/PasteSnap/`.

## Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────┐
│  Clipboard  │────▶│  ClipboardMonitor │────▶│   AppState     │
│  (NSPaste‑  │     │  (500ms polling,  │     │  (@MainActor, │
│   board)    │     │   .common mode)   │     │   coordinator)│
└─────────────┘     └──────────────────┘     └───────┬───────┘
                                                      │
                    ┌─────────────────────────────────┼────┐
                    │                                 │    │
                    ▼                                 ▼    ▼
           ┌──────────────┐              ┌────────────┐  ┌────────────┐
           │ CardRenderer │              │HistoryStore│  │ HotkeyMgr  │
           │ (CGContext)  │              │ (JSON, LRU)│  │ (⌘⇧V NSE‑  │
           │ → CGImageDest│              │ ~/Lib/AppS │  │  vent mon.)│
           └──────┬───────┘              └────────────┘  └────────────┘
                  │
         PNG ─────┘
     ~/Pictures/PasteSnap/
```

### Source Structure

```
PasteSnap/
├── main.swift                    # Entry point (no @main), sets accessory activation
├── AppDelegate.swift             # NSApplicationDelegate, bootstraps State + Menu
├── AppState.swift                # @MainActor coordinator, clipboard change handler
├── MenuBar/
│   └── StatusItemController.swift  # NSStatusItem menu + NSObject ActionTarget bridge
├── Clipboard/
│   └── ClipboardMonitor.swift    # NSPasteboard polling via Timer(.common)
├── CardRenderer/
│   ├── CardTheme.swift           # 3 theme presets (colors, fonts, layout)
│   ├── CardConfig.swift           # Input: text, theme, dimensions, scale
│   └── CardRenderer.swift        # Core Graphics CGContext → CGImageDestination PNG
├── History/
│   └── HistoryStore.swift        # JSON persistence, LRU eviction (max 10)
└── Hotkey/
    └── HotkeyManager.swift       # NSEvent local + global monitor for ⌘⇧V
```

### Key Technical Decisions

| Decision | Why |
|----------|-----|
| **`main.swift` entry** | Avoids Swift 6 `@main` + `NSApplication.shared` weak delegate issue |
| **`.common` run loop mode** | Default mode blocks during UI tracking (menu open); `.common` fires reliably |
| **`CGImageDestination` for PNG** | More reliable than `NSImage.tiffRepresentation → NSBitmapImageRep` |
| **`NSObject` ActionTarget bridge** | `@objc` selectors require NSObject; `@MainActor` classes can't use `#selector` directly |
| **`NSLog` for logging** | `print()` is silent in LSUIElement apps; NSLog goes to Console.app |
| **No SwiftUI, no SPM** | Zero dependencies, fast builds, simple distribution |
| **`setActivationPolicy(.accessory)`** | No dock icon, pure menu bar app behavior |

## Technologies

- **Language:** Swift 6 (strict concurrency enabled)
- **SDK:** macOS 14.0+, Apple Silicon (arm64)
- **Xcode:** 17C52 (Xcode 26) with xcodegen
- **Frameworks:** AppKit, CoreGraphics, UniformTypeIdentifiers
- **Project generator:** xcodegen (no `.xcodeproj` in repo)

## Build & Release

### Prerequisites
```bash
brew install xcodegen
```

### Build
```bash
cd projects/pastesnap
rm -rf PasteSnap.xcodeproj
xcodegen generate
xcodebuild -scheme PasteSnap -configuration Release \
    -destination 'platform=macOS' \
    build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

### Release DMG
```bash
bash build-dmg.sh
# → build/PasteSnap-vX.Y.Z.dmg
```

### Publish
```bash
gh auth switch --user garibong-labs
git tag vX.Y.Z && git push origin vX.Y.Z
gh release create vX.Y.Z \
    --title "PasteSnap vX.Y.Z" \
    --notes 'Release notes...' \
    build/PasteSnap-vX.Y.Z.dmg
```

## Known Limitations

- **No code signing / notarization** — PoC stage; Gatekeeper warning on first launch
- **Input Monitoring permission** — ⌘⇧V global hotkey needs Accessibility / Input Monitoring in System Settings → Privacy & Security
- **LSUIElement** — no main window, no Dock icon, menu bar only
- **Single user** — history stored in `~/Library/Application Support/PasteSnap/`
- **No iCloud sync** — images and history are local only

## License

MIT — see [LICENSE](LICENSE)

## Author

[EliFromTheBarn](https://github.com/garibong-labs) (Eli on behalf of garibong-labs)
