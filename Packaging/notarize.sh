#!/bin/bash
# Run explicitly after building with a Developer ID identity.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo 'Usage: bash Packaging/notarize.sh /path/to/signed.dmg keychain-profile-name' >&2
  exit 2
fi
image_path="$1"
keychain_profile="$2"
if [[ ! -f "$image_path" || "$image_path" != *.dmg ]]; then
  echo 'A signed DMG file is required.' >&2
  exit 2
fi
if ! signature_info=$(codesign --display --verbose=4 "$image_path" 2>&1); then
  echo "The DMG has no valid code signature; notarization was not started." >&2
  exit 1
fi
if [[ "$signature_info" != *"Authority=Developer ID Application:"* ]]; then
  echo 'Build the DMG with a Developer ID Application identity before submitting.' >&2
  exit 1
fi
codesign --verify --strict "$image_path"
xcrun notarytool submit "$image_path" --keychain-profile "$keychain_profile" --wait --timeout 20m --output-format json > "${image_path}.notary-result.json"
/usr/bin/plutil -extract status raw "${image_path}.notary-result.json" | /usr/bin/grep -qx Accepted
xcrun stapler staple "$image_path"
xcrun stapler validate "$image_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$image_path"
# Stapling changes the bytes. Generate the release digest afterwards.
shasum -a 256 "$image_path" > "${image_path}.sha256"
echo 'Notarization accepted, ticket stapled and checked. Use the new digest when uploading.'
