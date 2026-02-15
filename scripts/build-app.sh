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

echo "🎙️  Building $APP_NAME..."
echo ""

# ---------------------------------------------------------------------------
# 1. Download Whisper model if not present
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
# 2. Build with SPM (release mode for performance)
# ---------------------------------------------------------------------------
echo "🔨 Building with Swift Package Manager (release)..."
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -5
echo "✅ Build complete"
echo ""

# ---------------------------------------------------------------------------
# 3. Assemble .app bundle
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
# 4. Code sign (ad-hoc for local use)
# ---------------------------------------------------------------------------
echo "🔏 Code signing (ad-hoc)..."
codesign --deep --force --sign - \
    --entitlements "$PROJECT_DIR/MeetsRecord/App/MeetsRecord.entitlements" \
    "$APP_BUNDLE" 2>&1
echo "✅ Code signed"
echo ""

# ---------------------------------------------------------------------------
# 5. Verify
# ---------------------------------------------------------------------------
echo "✅ Build complete!"
echo ""
echo "   App:  $APP_BUNDLE"
echo "   Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
echo ""
echo "   Run:  open $APP_BUNDLE"
echo "   DMG:  ./scripts/build-dmg.sh"
echo ""
