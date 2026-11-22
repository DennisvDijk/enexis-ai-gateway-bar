# How-to's

## Als gebruiker
**Installeren:** zet `GatewayBar.app` in `/Applications` en open hem. Eerste keer: rechtsklik, Open (ad-hoc getekend, tot er een Developer ID is).

**Instellen:** klik het icoon, tandwiel, vul gateway-URL en je eigen key in, Bewaar. De key gaat in de Keychain.

**Menubalk aanpassen:** Instellingen, Stijl: bedrag, percentage, beide of alleen icoon.

**Icoon niet te zien:** menubalk vol of verborgen door Ice/Bartender. Open de app opnieuw via Spotlight: het dashboard opent in een gewoon venster.

**Maand toont "–":** je key heeft geen admin-rechten. Normaal.

**Model staat nooit op "niet beschikbaar":** de gateway moet `background_health_checks` aan hebben.

## Als ontwikkelaar
```sh
swift run UICheck     # alle UI-tests, ook zonder Xcode
swift test            # unit tests (Xcode nodig)
python3 mock/server.py & ./build.sh && open GatewayBar.app   # tegen nep-gateway (poort 4000)
./build.sh install    # naar /Applications
```
**Nieuwe check toevoegen:** `Sources/UICheck/main.swift`. Maak een `Gateway(...)` met de gewenste data, `install()`, laad `MenuView`, en test met `screen.texts()` en `screen.press(id:)`.
**Nieuw element testbaar maken:** geef het een `.accessibilityIdentifier("naam")` in `Views.swift`.

## Releasen
1. Zet `CHANGELOG.md` goed.
2. `git tag v1.1.0 && git push origin v1.1.0`
3. De pipeline test, bouwt, tekent en publiceert dmg/zip/SHA256SUMS (GitHub Release).
Certificaat en notarization: zie [DEPLOYMENT.md](DEPLOYMENT.md).

## Uitrollen naar Enexis (IT)
1. Developer ID + notarization regelen, bundle-id naar `nl.enexis.aigatewaybar`.
2. Pakket in Jamf/Intune.
3. Configuratieprofiel met `baseURL`, `interval`, `alertAt` voorinvullen.
Details: [DEPLOYMENT.md](DEPLOYMENT.md).

## Naar GitLab
Push naar de GitLab-remote. `.gitlab-ci.yml` draait test, UI-tests en build. Nodig: een macOS-runner (SaaS Premium of eigen Mac, tag in `MACOS_RUNNER_TAG`).
