# MinorSwiftCore

Shared Swift package and GitHub Actions workflows for Minor macOS apps (macOS 26+, Apple Silicon, Swift 6).

## Modules

| Module | Purpose |
|---|---|
| `MinorLog` | `Log.logger("Category")` – `os.Logger` with subsystem = bundle ID; `Diagnostics.export(to:)` writes recent logs + app/OS info |
| `MinorKeychain` | `Keychain(service:)` – generic-password get/set/remove |
| `MinorUpdater` | `Updater` – checks GitHub Releases, verifies and installs updates |

No external runtime dependencies.

## Updater

- Repository comes from Info.plist key `MinorUpdateRepository` (`owner/repo`).
- Queries `api.github.com/repos/<repo>/releases/latest` (drafts and pre-releases are skipped), once per 24 h.
- Expects asset `<AppName>-<major.minor.patch>.zip` (the bundle name without `.app`).
- Before replacing the app it checks: SHA-256 digest from GitHub, Developer ID signature of the same Team ID
  as the running app, same bundle ID, strictly newer version.
- Disabled for unsigned / ad-hoc builds (local Debug).
- If the app location is not writable, it opens the release page instead.

## Reusable workflows

| Workflow | Use from an app repository |
|---|---|
| `lint.yml` | SwiftLint (pinned version + SHA-256), `--strict` |
| `app-test.yml` | `xcodebuild test` (input `scheme`) |
| `app-release.yml` | archive → Developer ID sign → notarize → staple → GitHub Release (input `scheme`, `secrets: inherit`) |

Reference them by tag, e.g. `uses: novami/minor-swift-core/.github/workflows/lint.yml@0.1.0`.

### Secrets required in each app repository

| Secret | Content |
|---|---|
| `DEVELOPER_ID_P12` | Developer ID Application certificate + key, `.p12` as base64 |
| `DEVELOPER_ID_P12_PASSWORD` | `.p12` password |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect issuer ID |
| `ASC_KEY_P8` | API key `.p8` as base64 |

## Versioning

Tags and releases are `major.minor.patch` without a prefix. Pushing a tag on `main` runs tests and creates the GitHub Release.
