#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="build/Fly Cursor.app"
mkdir -p "$app/Contents/MacOS" build/module-cache
cp Info.plist "$app/Contents/Info.plist"
swiftc -O -module-cache-path build/module-cache FlyCursor.swift -o "$app/Contents/MacOS/FlyCursor"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
printf 'Built %s\n' "$app"
