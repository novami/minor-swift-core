# Changelog

## 0.1.3

- Reverted the DerivedData cache in app-test (no measurable speedup on runners).

## 0.1.2

- app-test workflow caches DerivedData (saved only from the default branch).

## 0.1.1

- Fixed release workflow (runner context in job env).

## 0.1.0

- MinorLog: unified `os.Logger` per subsystem, diagnostics export.
- MinorKeychain: generic-password storage.
- MinorUpdater: GitHub Releases updater with Developer ID signature verification.
- Reusable workflows: lint, app-test, app-release.
