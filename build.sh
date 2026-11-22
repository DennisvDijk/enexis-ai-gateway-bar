#!/bin/zsh
# Builds GatewayBar.app (menu bar only, no Dock icon).
# Usage: ./build.sh            -> ./GatewayBar.app
#        ./build.sh install    -> also copies to /Applications
# Env:   VERSION=1.2.3         marketing version (default 1.0.0), BUILD_NUMBER=42
#        SIGN_IDENTITY="Developer ID Application: ..."  -> hardened-runtime signing (else ad hoc)
set -euo pipefail
cd "${0:A:h}"
swift build -c release --product GatewayBar
BIN="$(swift build -c release --show-bin-path)/GatewayBar"
APP=GatewayBar.app
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
mkdir -p $APP/Contents/MacOS
cp "$BIN" $APP/Contents/MacOS/GatewayBar
cat > $APP/Contents/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>GatewayBar</string>
<key>CFBundleIdentifier</key><string>nl.gatewaybar.app</string>
<key>CFBundleExecutable</key><string>GatewayBar</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict></plist>
PL
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" $APP
else
  codesign --force --sign - $APP
fi
echo "Built $PWD/$APP"
if [[ "${1:-}" == install ]]; then
  ditto $APP /Applications/$APP
  echo "Installed in /Applications/$APP"
fi
