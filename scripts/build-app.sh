#!/bin/bash
set -euo pipefail

# =============================================================================
# MeetsRecord — Build .app bundle from Swift Package Manager
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="MeetsRecord"
BUILD_DIR="$PROJECT_DIR/.build/release"
OUTPUT_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
MODEL_NAME="ggml-base.en"
MODEL_FILE="$MODEL_NAME.bin"
RESOURCES_DIR="$PROJECT_DIR/MeetsRecord/Resources"

# Parse flags
INSTALL=false
SIGN_IDENTITY="-"  # ad-hoc by default
for arg in "$@"; do
    case $arg in
        --install) INSTALL=true ;;
        --sign=*) SIGN_IDENTITY="${arg#*=}" ;;
    esac
done

echo "🎙️  Building $APP_NAME..."
echo ""

# ---------------------------------------------------------------------------
# 1. Generate icons if not present
# ---------------------------------------------------------------------------
if [ ! -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    echo "🎨 Generating app icon..."
    if command -v python3 &>/dev/null && python3 -c "from PIL import Image" 2>/dev/null; then
        python3 "$PROJECT_DIR/scripts/generate-icons.py"
    else
        echo "  ⚠️  Pillow not installed (pip3 install Pillow), skipping icon generation"
    fi
else
    echo "✅ App icon already present"
fi
echo ""

# ---------------------------------------------------------------------------
# 2. Download Whisper model if not present
# ---------------------------------------------------------------------------
if [ ! -f "$RESOURCES_DIR/$MODEL_FILE" ] || [ "$(wc -c < "$RESOURCES_DIR/$MODEL_FILE")" -lt 1000 ]; then
    echo "📥 Downloading Whisper model ($MODEL_FILE, ~142 MB)..."
    mkdir -p "$RESOURCES_DIR"
    curl -L --progress-bar \
        -o "$RESOURCES_DIR/$MODEL_FILE" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_FILE"
    echo "✅ Model downloaded"
else
    echo "✅ Whisper model already present"
fi
echo ""

# ---------------------------------------------------------------------------
# 3. Build with SPM (release mode for performance)
# ---------------------------------------------------------------------------
if [ -f "$BUILD_DIR/$APP_NAME" ]; then
    echo "✅ Release binary already exists, skipping build"
else
    echo "🔨 Building with Swift Package Manager (release)..."
    cd "$PROJECT_DIR"
    swift build -c release 2>&1 | tail -5
    echo "✅ Build complete"
fi
echo ""

# ---------------------------------------------------------------------------
# 4. Assemble .app bundle
# ---------------------------------------------------------------------------
echo "📦 Assembling $APP_NAME.app..."

# Clean previous build
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/MeetsRecord/App/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy app icon
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "  ↳ Embedded app icon"
fi

# Copy resource bundle (SPM creates this with the whisper model inside)
RESOURCE_BUNDLE="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
    echo "  ↳ Embedded resource bundle with Whisper model"
else
    echo "  ⚠️  Resource bundle not found at $RESOURCE_BUNDLE"
    echo "     Whisper model won't be available — transcription will be skipped"
fi

# Create PkgInfo
printf "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "✅ App bundle assembled"
echo ""

# ---------------------------------------------------------------------------
# 5. Code sign
# ---------------------------------------------------------------------------
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "🔏 Code signing (ad-hoc)..."
    codesign --deep --force --sign - \
        --entitlements "$PROJECT_DIR/MeetsRecord/App/MeetsRecord.entitlements" \
        "$APP_BUNDLE" 2>&1
else
    echo "🔏 Code signing with Developer ID: $SIGN_IDENTITY..."
    codesign --deep --force --sign "$SIGN_IDENTITY" \
        --options runtime \
        --entitlements "$PROJECT_DIR/MeetsRecord/App/MeetsRecord.entitlements" \
        --timestamp \
        "$APP_BUNDLE" 2>&1
fi
echo "✅ Code signed"
echo ""

# ---------------------------------------------------------------------------
# 6. Clear quarantine flag (prevents Gatekeeper "malware" warning on local builds)
# ---------------------------------------------------------------------------
echo "🔓 Clearing quarantine flag..."
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
echo "✅ Quarantine cleared"
echo ""

# ---------------------------------------------------------------------------
# 7. Install to /Applications (if --install flag or local build)
# ---------------------------------------------------------------------------
if [ "$INSTALL" = true ]; then
    echo "📲 Installing to /Applications..."
    # Remove old version if present
    if [ -d "/Applications/$APP_NAME.app" ]; then
        rm -rf "/Applications/$APP_NAME.app"
    fi
    cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"
    # Clear quarantine on installed copy too
    xattr -cr "/Applications/$APP_NAME.app" 2>/dev/null || true
    echo "✅ Installed to /Applications/$APP_NAME.app"
    echo ""
fi

# ---------------------------------------------------------------------------
# 8. Done
# ---------------------------------------------------------------------------
echo "✅ Build complete!"
echo ""
echo "   App:  $APP_BUNDLE"
echo "   Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
echo ""
if [ "$INSTALL" = false ]; then
    echo "   Run:     open $APP_BUNDLE"
    echo "   Install: ./scripts/build-app.sh --install"
    echo "   DMG:     ./scripts/build-dmg.sh"
else
    echo "   Run:     open /Applications/$APP_NAME.app"
    echo "   DMG:     ./scripts/build-dmg.sh"
fi
echo ""
