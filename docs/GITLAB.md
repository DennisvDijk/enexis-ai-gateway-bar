# Running the pipeline on self-managed GitLab

The app uses SwiftUI and AppKit, so it can only be built and tested on **macOS**. A Linux runner with a Swift image cannot do it. You need one Mac registered as a runner.

## Set up a Mac runner (once)
1. Use a Mac (a Mac mini is enough) with macOS 14 or later and the Command Line Tools (`xcode-select --install`). Full Xcode is only needed for the unit tests (`swift test`).
2. Install the runner: `brew install gitlab-runner`.
3. Register it with the **shell** executor and the tag `macos`:
   ```sh
   gitlab-runner register --url https://YOUR-GITLAB --token <runner token> --executor shell --tag-list macos
   brew services start gitlab-runner
   ```
4. Run it as a logged-in user (the UI tests host views in a window, which needs a GUI session). Enable auto-login for that user on a headless Mac.

## Without a Mac runner (Linux only)
The pipeline still works: the `lint` job runs on any Linux runner (`python:3.12-slim`, no Swift) via `scripts/lint.sh`. It checks the mock gateway, the shell scripts and the links in the docs. The `test` and `package` jobs are manual and non-blocking until a Mac runner exists. Once it does, set the CI variable `MACOS_RUNNER_AVAILABLE=true` and the test job runs automatically.

`lint` is a safety net, not a replacement: it does not build the app or run the UI tests.

## What the pipeline does
- `test`: `swift test`, `swift run UICheck`, `./build.sh`, signature check.
- `package` (on tag `vX.Y.Z`): builds a dmg and zip. Add `SIGN_IDENTITY` and `NOTARY_PROFILE` as masked and protected variables for a signed, notarized build; the certificate must be in the keychain of the runner Mac.

## If you do not have Xcode on the runner
`swift test` will fail with "no such module XCTest". Either install Xcode, or remove that line: `swift run UICheck` already covers the UI and the main logic and works with only the Command Line Tools.

## No Mac available
Keep GitHub Actions as the CI (the repo is public) and use GitLab only as a mirror, or ask IT for a Mac runner.
