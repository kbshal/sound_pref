#!/bin/bash

echo "Building executable..."
swift build

echo "Creating .app bundle structure..."
mkdir -p SoundPref.app/Contents/MacOS
mkdir -p SoundPref.app/Contents/Resources

echo "Building app icon (icns)..."
ICONSET_DIR="SoundPref.app/Contents/Resources/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# Copy PNGs from the logo kit into the iconset with Apple's expected names
LOGO_DIR="Sources/App/Resources/AppIcon"
cp "$LOGO_DIR/icon_16x16.png"    "$ICONSET_DIR/icon_16x16.png"
cp "$LOGO_DIR/icon_16x16-2x.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "$LOGO_DIR/icon_32x32.png"    "$ICONSET_DIR/icon_32x32.png"
cp "$LOGO_DIR/icon_32x32-2x.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "$LOGO_DIR/icon_128x128.png"  "$ICONSET_DIR/icon_128x128.png"
cp "$LOGO_DIR/icon_128x128-2x.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "$LOGO_DIR/icon_256x256.png"  "$ICONSET_DIR/icon_256x256.png"
cp "$LOGO_DIR/icon_256x256-2x.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "$LOGO_DIR/icon_512x512.png"  "$ICONSET_DIR/icon_512x512.png"
cp "$LOGO_DIR/icon_512x512-2x.png" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "SoundPref.app/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "Copying files..."
cp .build/debug/SoundPref SoundPref.app/Contents/MacOS/
cp Sources/App/Info.plist SoundPref.app/Contents/

echo "Signing app bundle..."
codesign --force --deep -s - SoundPref.app

echo "Launching app..."
open SoundPref.app
