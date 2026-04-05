#!/bin/bash
# build-dmg.sh — Build PasteSnap release DMG
set -e

PROJECT_DIR="$HOME/.openclaw/workspace/projects/pastesnap"
BUILD_DIR="$PROJECT_DIR/build"

cd "$PROJECT_DIR"

echo "🔨 Building Release..."
rm -rf PasteSnap.xcodeproj
xcodegen generate > /dev/null 2>&1
xcodebuild -scheme PasteSnap -configuration Release -destination 'platform=macOS' \
    build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -1

# Find the Release app in DerivedData
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "PasteSnap.app" -path "*/Release/*" 2>/dev/null | head -1)
if [ -z "$APP" ]; then
    echo "❌ Release app not found in DerivedData"
    exit 1
fi

echo "📦 App: $APP"
DMG="$BUILD_DIR/PasteSnap-v0.1.0.dmg"
mkdir -p "$BUILD_DIR"
rm -f "$DMG"

# Staging
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/PasteSnap.app"
xattr -cr "$STAGING/PasteSnap.app" 2>/dev/null || true
ln -s /Applications "$STAGING/Applications"

# Create DMG
hdiutil create -volname "PasteSnap v0.1.0" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "✅ DMG: $DMG"
ls -lh "$DMG"
rm -rf "$STAGING"
