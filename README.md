# Enexis AI Gateway (menu bar)

macOS menu bar app that tracks AI gateway spend, budget and model availability.
Built for a LiteLLM-compatible proxy (assumed, not yet confirmed against the real gateway).

- Menu bar: Enexis mark + current spend; ⚠︎ / offline / key? on problems
- Popover: spend vs. budget, today / month / team, model availability
- Notifications: budget threshold, models added/removed/down/recovered
- API key stored in the Keychain

## Build
```sh
./build.sh            # builds GatewayBar.app
./build.sh install    # also copies to /Applications
```
Requires macOS 14+ and the Swift toolchain. Open Settings (gear) to enter the gateway URL and key.
`mock/server.py` is a small fake gateway for local testing (port 4000).

Note: "unavailable" model detection needs `background_health_checks` on the proxy. The app is ad-hoc signed, not notarized.
