#!/bin/bash
# Builds Carafe.app and packages it as build/Carafe-<version>.dmg: a disk image with the app and an
# Applications shortcut to drag it onto.
set -euo pipefail
cd "$(dirname "$0")/.."

Scripts/build-app.sh
APP="build/Carafe.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="build/Carafe-$VERSION.dmg"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "Carafe $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null
echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
