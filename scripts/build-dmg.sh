#!/bin/bash
set -euo pipefail

# =============================================================================
# MeetsRecord — Create .dmg installer with drag-to-Applications
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="MeetsRecord"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME"
DMG_OUTPUT="$BUILD_DIR/$DMG_NAME.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"
VERSION=$(defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")

# ---------------------------------------------------------------------------
# 1. Ensure .app exists
# ---------------------------------------------------------------------------
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found at $APP_BUNDLE"
    echo "   Run ./scripts/build-app.sh first"
    exit 1
fi

echo "💿 Creating $DMG_NAME.dmg (v$VERSION)..."
echo ""

# ---------------------------------------------------------------------------
# 2. Prepare staging directory
# ---------------------------------------------------------------------------
echo "📁 Preparing DMG contents..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy app
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# Create Applications symlink (the drag target)
ln -s /Applications "$DMG_STAGING/Applications"

echo "✅ Staging ready"
echo ""

# ---------------------------------------------------------------------------
# 3. Create DMG
# ---------------------------------------------------------------------------
echo "💿 Building DMG..."

# Remove old DMG if present
rm -f "$DMG_OUTPUT"

# Create DMG with hdiutil
#   -volname: Name shown when mounted
#   -srcfolder: Source directory
#   -ov: Overwrite
#   -format: UDZO = compressed read-only
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT" 2>&1 | grep -v "^$"

echo ""

# ---------------------------------------------------------------------------
# 4. Clean up
# ---------------------------------------------------------------------------
rm -rf "$DMG_STAGING"

# ---------------------------------------------------------------------------
# 5. Done
# ---------------------------------------------------------------------------
DMG_SIZE=$(du -sh "$DMG_OUTPUT" | cut -f1)
echo "✅ DMG created!"
echo ""
echo "   File:    $DMG_OUTPUT"
echo "   Size:    $DMG_SIZE"
echo "   Version: $VERSION"
echo ""
echo "   Users download the .dmg, open it, and drag"
echo "   $APP_NAME.app into the Applications folder."
echo ""
