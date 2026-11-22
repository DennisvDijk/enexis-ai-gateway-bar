#!/bin/zsh
# Builds GatewayBar.app (menu bar only, no Dock icon).
# Usage: ./build.sh            -> ./GatewayBar.app
#        ./build.sh install    -> also copies to /Applications
set -euo pipefail
cd "${0:A:h}"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/GatewayBar"
APP=GatewayBar.app
mkdir -p $APP/Contents/MacOS
cp "$BIN" $APP/Contents/MacOS/GatewayBar
cat > $APP/Contents/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>GatewayBar</string>
<key>CFBundleIdentifier</key><string>nl.gatewaybar.app</string>
<key>CFBundleExecutable</key><string>GatewayBar</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict></plist>
PL
codesign --force --sign - $APP
echo "Built $PWD/$APP"
if [[ "${1:-}" == install ]]; then
  ditto $APP /Applications/$APP
  echo "Installed in /Applications/$APP"
fi
