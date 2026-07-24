#!/bin/bash
set -e

APP_NAME="SoundPref"
DMG_NAME="${APP_NAME}.dmg"
STAGING_DIR="dmg_staging"

echo "Step 1: Building the app..."
./run_app.sh

echo "Step 2: Preparing staging directory..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "Step 3: Copying ${APP_NAME}.app..."
cp -R "${APP_NAME}.app" "$STAGING_DIR/"

echo "Step 4: Creating /Applications symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

echo "Step 5: Building DMG..."
# Remove old DMG if it exists
rm -f "$DMG_NAME"
# Create the DMG using hdiutil
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

echo "Step 6: Cleaning up..."
rm -rf "$STAGING_DIR"

echo "Done! 🎉 Your DMG is ready at: ${DMG_NAME}"
