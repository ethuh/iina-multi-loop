# iina-cli/

## OVERVIEW
Swift CLI wrapper that launches the `IINA` binary inside an `IINA.app` bundle and forwards file paths + mpv-like options.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| CLI entry point | `iina-cli/main.swift` | spawns `IINA` via `Process`; maps args; handles stdin |
| Build scheme | `iina.xcodeproj/xcshareddata/xcschemes/iina-cli.xcscheme` | Xcode target wiring |

## CONVENTIONS (CLI BEHAVIOR)
- Requires being inside `IINA.app` bundle: looks for sibling `IINA` binary next to its own executable.
- `--` arguments are rewritten into `--mpv-*` flags before launching IINA.
- `--music-mode` and `--pip` are mutually exclusive.

## ANTI-PATTERNS
- Don't try to turn this into a long-lived control API; it is a launcher/argument forwarder.
