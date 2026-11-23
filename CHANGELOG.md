# Changelog

Follows [Semantic Versioning](https://semver.org). Tags `vX.Y.Z` build a release.

## [Unreleased]

### Added
- Menu bar app "Enexis AI Gateway": spend, budget (period taken from the gateway) and model availability
- Enexis styling, status dot on the icon, compact menu bar text (amount / % / icon)
- Dashboard in a normal window when the app is reopened (for a full menu bar)
- UI tests (`swift run UICheck`, 94 checks): every popover state, the buttons, settings and the menu bar title, against a fake gateway
- Unit tests, CI for GitHub Actions and GitLab, release pipeline (dmg, optionally notarized)
