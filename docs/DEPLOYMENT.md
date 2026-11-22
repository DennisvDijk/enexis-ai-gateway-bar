# Uitrol naar Enexis

## 1. Eenmalig regelen (Apple)
- **Developer ID Application**-certificaat (Apple Developer Program van Enexis). Zonder dit blokkeert Gatekeeper de app op beheerde Macs.
- **Notarization**: app-specific password of API-key voor `notarytool`.
- Aanbevolen: bundle-id wijzigen naar een Enexis-id (bijv. `nl.enexis.aigatewaybar`) voordat je breed uitrolt; daarna niet meer wijzigen (instellingen en Keychain hangen eraan).

## 2. Releasen
Tag een versie; de pipeline test, bouwt, tekent, notariseert en publiceert een `.dmg` + `.zip` + `SHA256SUMS`.

```sh
git tag v1.0.0 && git push origin v1.0.0
```

CI-variabelen/secrets (GitHub: Secrets, GitLab: masked + protected variables):

| Doel | GitHub secret | GitLab variabele |
|---|---|---|
| Certificaat (.p12, base64) | `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD` | zelf toevoegen aan de job |
| Notarization | `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`, `NOTARY_APP_PASSWORD` | `SIGN_IDENTITY`, `NOTARY_PROFILE` (op een eigen Mac-runner) |

Zonder deze waarden is de release ad-hoc getekend en alleen geschikt voor testen.

## 3. Verspreiden via MDM (Jamf / Intune / Kandji)
1. Upload de `.dmg` of `.zip` (of maak er een `.pkg` van) als app/pakket, installatie naar `/Applications`.
2. Push de **vooraf ingevulde instellingen** als configuratieprofiel (Custom Settings / Preference Domain `nl.gatewaybar.app`). De app leest deze waarden uit de standaard-defaults, dus beheerde waarden winnen:

```xml
<key>baseURL</key><string>https://ai-gateway.example.enexis.nl</string>
<key>interval</key><real>60</real>
<key>alertAt</key><real>0.8</real>
<key>notify</key><true/>
<key>barStyle</key><string>amount</string> <!-- amount | percent | both | icon -->
```
3. Optioneel: laat de app starten bij inloggen via een LaunchAgent of de instelling "Start bij inloggen".

## 4. API-keys
Elke medewerker gebruikt een eigen gateway-key (voor eigen budget). De key staat in de macOS Keychain en wordt alleen naar de gateway gestuurd. Voor een centrale rol (bijv. SSO-uitgifte van keys) is een aparte koppeling met de gateway nodig; dat zit er nog niet in.

## 5. Updates
Er is nog geen auto-update. Voor MDM-beheerde Macs: een nieuwe versie als update-pakket uitrollen. Sparkle toevoegen is een logische vervolgstap.
