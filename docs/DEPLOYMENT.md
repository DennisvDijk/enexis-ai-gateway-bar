# Deployment to Enexis

## 1. One-time Apple setup
- A **Developer ID Application** certificate (Enexis Apple Developer Program). Without it Gatekeeper blocks the app on managed Macs.
- **Notarization**: an app-specific password or API key for `notarytool`.
- Recommended: change the bundle id to an Enexis one (for example `nl.enexis.aigatewaybar`) before a wide rollout, and never change it afterwards (settings and Keychain entries depend on it).

## 2. Releasing
Tag a version; the pipeline tests, builds, signs, notarizes and publishes a `.dmg`, `.zip` and `SHA256SUMS`.

```sh
git tag v1.0.0 && git push origin v1.0.0
```

CI secrets (GitHub: Secrets; GitLab: masked and protected variables):

| Purpose | GitHub secret | GitLab variable |
|---|---|---|
| Certificate (.p12, base64) | `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD` | add to the job yourself |
| Notarization | `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`, `NOTARY_APP_PASSWORD` | `SIGN_IDENTITY`, `NOTARY_PROFILE` (on your own Mac runner) |

Without these values the release is ad-hoc signed and only suitable for testing.

## 3. Distribute with MDM (Jamf / Intune / Kandji)
1. Upload the `.dmg` or `.zip` (or wrap it in a `.pkg`) as an app or package, installed to `/Applications`.
2. Push **preset settings** as a configuration profile (Custom Settings, preference domain `nl.gatewaybar.app`). The app reads these through the standard defaults, so managed values win:

```xml
<key>baseURL</key><string>https://ai-gateway.example.enexis.nl</string>
<key>interval</key><real>60</real>
<key>alertAt</key><real>0.8</real>
<key>notify</key><true/>
<key>barStyle</key><string>amount</string> <!-- amount | percent | both | icon -->
```
3. Optional: start at login via a LaunchAgent or the "Start at login" setting.

## 4. API keys
Each employee uses their own gateway key (for their own budget). The key is stored in the macOS Keychain and only sent to the gateway. Central key issuance (for example via SSO) needs a separate integration with the gateway and is not built.

## 5. Updates
There is no auto-update yet. On MDM-managed Macs, roll out a new version as an update package. Adding Sparkle is the logical next step.
