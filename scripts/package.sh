#!/bin/zsh
# Packages GatewayBar.app into dist/GatewayBar-<version>.dmg (+ .zip).
# With SIGN_IDENTITY and NOTARY_PROFILE (a `notarytool store-credentials` profile) the dmg is notarized and stapled.
set -euo pipefail
cd "${0:A:h}/.."
VERSION="${VERSION:-1.0.0}"
export VERSION
./build.sh
mkdir -p dist
DMG="dist/GatewayBar-$VERSION.dmg"
STAGE="$(mktemp -d)"
cp -R GatewayBar.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Enexis AI Gateway" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
ditto -c -k --keepParent GatewayBar.app "dist/GatewayBar-$VERSION.zip"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi
shasum -a 256 dist/* > dist/SHA256SUMS
echo "Packaged:"; ls -1 dist
