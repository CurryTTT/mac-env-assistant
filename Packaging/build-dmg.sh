#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
# Install ds_store and mac_alias into your Python environment before running.
python_bin="${PYTHON_BIN:-python3}"
"$python_bin" -c "import ds_store, mac_alias"
bash build.sh
pkg="$root/.build/packaging"
mkdir -p "$pkg/stage/.background"
xcrun swiftc -module-cache-path .build/module-cache -framework AppKit Packaging/draw-assets.swift -o "$pkg/draw-assets"
"$pkg/draw-assets" "$pkg/assets"
# Replace only our packaging stage, never a user's installation.
if [[ -d "$pkg/stage/MacEnvAssistant.app" ]]; then rm -rf "$pkg/stage/MacEnvAssistant.app"; fi
cp -R dist/MacEnvAssistant.app "$pkg/stage/"
ln -sfn /Applications "$pkg/stage/Applications"
cp "$pkg/assets/background.png" "$pkg/stage/.background/"
"$python_bin" Packaging/finder-layout.py "$pkg/stage"
hdiutil makehybrid -hfs -hfs-volume-name 'Mac Env Assistant' -hfs-openfolder "$pkg/stage" -o "$pkg/first.dmg" "$pkg/stage" -ov
"$python_bin" Packaging/finder-layout.py "$pkg/stage" "$pkg/first.dmg"
hdiutil makehybrid -hfs -hfs-volume-name 'Mac Env Assistant' -hfs-openfolder "$pkg/stage" -o "$pkg/final.dmg" "$pkg/stage" -ov
"$python_bin" Packaging/align-volume-date.py "$pkg/first.dmg" "$pkg/final.dmg"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
output="dist/MacEnvAssistant-v${version}-macOS-$(uname -m).dmg"
hdiutil convert "$pkg/final.dmg" -format UDZO -o "$output" -ov
if [[ "${SIGNING_IDENTITY:--}" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$output"
fi
hdiutil verify "$output"
shasum -a 256 "$output"
