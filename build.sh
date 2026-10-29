#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This application requires macOS." >&2
  exit 1
fi
build_arch="$(uname -m)"
app_path="$project_root/dist/MacEnvAssistant.app"
mkdir -p "$app_path/Contents/MacOS" "$project_root/.build/module-cache"
xcrun swiftc -parse-as-library -swift-version 5 \
  -target "${build_arch}-apple-macosx14.0" \
  -module-cache-path "$project_root/.build/module-cache" \
  -framework SwiftUI -framework AppKit \
  Sources/*.swift -o "$app_path/Contents/MacOS/EnvSetup.new"
mv "$app_path/Contents/MacOS/EnvSetup.new" "$app_path/Contents/MacOS/EnvSetup"
mkdir -p "$app_path/Contents/Resources"
cp Resources/AppIcon.icns "$app_path/Contents/Resources/"
cp Info.plist "$app_path/Contents/Info.plist"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
echo "Built: $app_path"
