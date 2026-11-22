# Hoe het werkt

![Architectuur](architecture.svg)

## Onderdelen
| Onderdeel | Doel |
|---|---|
| `Sources/GatewayBar` | Dunne app: menubalk-item, venster bij heropenen. Bevat bijna geen logica. |
| `Sources/GatewayBarKit` | Alle logica en views: `Store` (status, timer, meldingen), `Client` (HTTP), `Views`, `Keychain`. |
| `Sources/UICheck` | UI-tests zonder Xcode: laadt de echte views, leest de accessibility-tree, drukt op knoppen, nep-gateway. |
| `Tests/GatewayBarTests` | Unit tests (XCTest, draaien in CI). |
| `mock/server.py` | Nep-gateway voor handmatig proberen (poort 4000). |

## Eén verversing (elke 60 s, minimaal 15 s)
1. `/v1/models` voor de lijst, met `healthy_only` voor wat werkt. Verschil = niet beschikbaar.
2. `/health/liveliness` bepaalt of de gateway zelf bereikbaar is.
3. `/key/info` geeft uitgaven en budget van je key (wekelijks $120 komt hieruit); zonder budget valt de app terug op `/team/info`.
4. `/spend/logs/v2` geeft vandaag en per model. Maandtotaal vraagt admin-rechten, anders staat er "–".
5. `Store` zet dit om naar één `badge` (ok, waarschuwing, offline, key geweigerd) en een titel. De menubalk en het venster lezen alleen die status.
6. Budget over de drempel, of model erbij/weg/uit/terug: macOS-melding.

## Instellingen
- URL, interval, drempel, stijl: UserDefaults (domein `nl.gatewaybar.app`). Een MDM-profiel wint van de gebruiker.
- API-key: macOS Keychain, nooit in een bestand.

## Statussen
```mermaid
flowchart LR
  A[Niet ingesteld] -->|URL + key| B[Verversen]
  B -->|401/403| C[Key geweigerd]
  B -->|geen verbinding| D[Offline]
  B -->|alles ok| E[Gezond]
  B -->|model uit| F[Waarschuwing]
  B -->|budget > drempel| F
```

## Wat is getest en wat niet
| Functie | Status |
|---|---|
| Weergave van alle statussen, knoppen, instellingen | UI-tests (CI) |
| Budget, percentage, teambudget-terugval | UI- en unit tests |
| Meldingen (budget 80%/100%, model erbij/weg/uit/terug) | Logica aanwezig, **niet getest**; verstuurt alleen vanuit een echte `.app` met bundle-id |
| "Start bij inloggen" | Code aanwezig, niet getest |
| Echte Enexis-gateway | Nog nooit gedraaid |
| Echte muisklik in de menubalk | Niet geautomatiseerd |
