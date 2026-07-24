#!/bin/bash

echo "Building executable..."
swift build

echo "Creating .app bundle structure..."
mkdir -p SoundPref.app/Contents/MacOS
mkdir -p SoundPref.app/Contents/Resources

echo "Copying files..."
cp .build/debug/SoundPref SoundPref.app/Contents/MacOS/
cp Sources/App/Info.plist SoundPref.app/Contents/

echo "Signing app bundle..."
codesign --force --deep -s - SoundPref.app

echo "Launching app..."
open SoundPref.app
