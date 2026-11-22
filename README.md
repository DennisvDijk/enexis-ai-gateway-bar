# Enexis AI Gateway (menu bar)

[![CI](https://github.com/DennisvDijk/enexis-ai-gateway-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/DennisvDijk/enexis-ai-gateway-bar/actions/workflows/ci.yml)

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

## Tests en CI
```sh
swift test        # unit tests (XCTest, needs Xcode)
swift run UICheck # UI tests: real views, accessibility tree, stub gateway (CLT is enough)
```
- GitHub Actions: `.github/workflows/ci.yml` (test + build bij elke push/PR), `release.yml` (tag `vX.Y.Z` bouwt dmg/zip).
- GitLab: `.gitlab-ci.yml` (macOS-runner vereist; tag via `MACOS_RUNNER_TAG`).
- Uitrol naar de organisatie: zie [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).
- Hoe het werkt: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). How-to's: [docs/HOWTO.md](docs/HOWTO.md).

## Als het menubalk-icoon niet zichtbaar is
Bij een volle menubalk (of een menubalk-beheerder zoals Ice/Bartender) kan het icoon verborgen zijn. Open GatewayBar opnieuw (Spotlight/Finder): het dashboard verschijnt dan in een gewoon venster.
