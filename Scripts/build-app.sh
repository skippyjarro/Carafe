#!/bin/bash
# Builds Carafe and wraps the binary in a double-clickable build/Carafe.app.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/Carafe.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Carafe "$APP/Contents/MacOS/Carafe"
cp Scripts/install-wine.sh "$APP/Contents/Resources/install-wine.sh"
Scripts/build-shim.sh "$APP/Contents/Resources/carafe-shim.dylib"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Carafe</string>
    <key>CFBundleDisplayName</key><string>Carafe</string>
    <key>CFBundleIdentifier</key><string>local.carafe</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleExecutable</key><string>Carafe</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"
