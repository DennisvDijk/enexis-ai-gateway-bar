# How-tos

## As a user
**Install:** put `GatewayBar.app` in `/Applications` and open it. First time: right-click, Open (ad-hoc signed until a Developer ID exists).

**Set up:** click the icon, then the gear, enter the gateway URL and your own key, save. The key goes into the Keychain.

**Change the menu bar text:** Settings, style: amount, percentage, both, or icon only.

**Icon not visible:** the menu bar is full or hidden by Ice/Bartender. Open the app again from Spotlight: the dashboard opens in a normal window.

**Month shows "–":** your key has no admin rights. This is expected.

**A model never shows "unavailable":** the gateway needs `background_health_checks` enabled.

## As a developer
```sh
swift run UICheck                                          # all UI tests, no Xcode needed
swift test                                                 # unit tests (needs Xcode)
python3 mock/server.py & ./build.sh && open GatewayBar.app # try it against the fake gateway
./build.sh install                                         # copy to /Applications
```
**Add a check:** edit `Sources/UICheck/main.swift`. Build a `Gateway(...)` with the data you want, call `install()`, load `MenuView`, then assert with `screen.texts()` and `screen.press(id:)`.

**Make an element testable:** give it `.accessibilityIdentifier("name")` in `Views.swift`.

## Release
1. Update `CHANGELOG.md`.
2. `git tag v1.1.0 && git push origin v1.1.0`
3. The pipeline tests, builds, signs and publishes dmg, zip and SHA256SUMS (GitHub Release).

Certificate and notarization: see [DEPLOYMENT.md](DEPLOYMENT.md).

## Roll out to Enexis (IT)
1. Get a Developer ID and notarization; change the bundle id to `nl.enexis.aigatewaybar`.
2. Package it in Jamf or Intune.
3. Push a configuration profile that presets `baseURL`, `interval` and `alertAt`.

Details: [DEPLOYMENT.md](DEPLOYMENT.md).

## Move to GitLab
Push to the GitLab remote and register a Mac as a runner: see [GITLAB.md](GITLAB.md).
