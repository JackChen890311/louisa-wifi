#!/bin/bash
# Build build/LouisaWiFi.app (and a zip for GitHub Releases).
# Needs only the Xcode Command Line Tools: xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

ARCHS=${ARCHS:-"arm64 x86_64"}
APP=build/LouisaWiFi.app

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

bins=()
for arch in $ARCHS; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos13" app/Sources/*.swift -o "build/LouisaWiFi-$arch"
  bins+=("build/LouisaWiFi-$arch")
done
lipo -create "${bins[@]}" -output "$APP/Contents/MacOS/LouisaWiFi"
rm "${bins[@]}"

cp app/Info.plist "$APP/Contents/"
# Release builds pass VERSION=1.2.3 (from the git tag).
if [ -n "${VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi
cp data/stores.json "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

ditto -c -k --keepParent "$APP" build/LouisaWiFi.zip
echo "Built $APP"
