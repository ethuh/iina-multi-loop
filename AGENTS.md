# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-06T04:06:55Z
**Commit:** bd16c841
**Branch:** develop

## OVERVIEW
IINA is a macOS video player (Swift + some Objective-C) built around libmpv; this repo also ships a CLI wrapper, plugin tooling/runtime, and browser/Safari "Open in IINA" extensions.

## STRUCTURE
```
./
|-- iina/            # main app source (AppKit UI, playback, plugins, prefs, localization, assets)
|-- deps/            # vendored headers + downloaded dylibs/executables (libmpv, FFmpeg, yt-dlp)
|-- Configs/         # Xcode .xcconfig build settings (targets + configs)
|-- other/           # build/codegen/maintenance scripts (download dylibs, mpv doc scrape, etc.)
|-- iina.xcodeproj/  # Xcode project + shared schemes
|-- iina-cli/        # Swift CLI wrapper (launches IINA inside IINA.app bundle)
|-- iina-plugin/     # Swift CLI for plugin template/pack/link/unlink
|-- browser/         # Chrome/Firefox extensions (open via iina:// URL scheme)
`-- OpenInIINA/      # Safari extension (open via iina:// URL scheme)
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| App startup / URL scheme | `iina/AppDelegate.swift` | `handleURLEvent` registers `kAEGetURL` and routes `iina://...` actions |
| Playback orchestration | `iina/PlayerCore.swift` | owns player instances, playlist, high-level playback operations |
| mpv bridge | `iina/MPVController.swift` | libmpv init/options/events; only place (with `iina/VideoView.swift`) allowed to call mpv directly |
| Video rendering lifecycle | `iina/VideoView.swift` | owns render context teardown; lock discipline around shutdown |
| Main window/UI logic | `iina/MainWindowController.swift` | window behavior, OSC/sidebars, fullscreen/PiP, UI sync |
| Preferences keys/defaults | `iina/Preference.swift` | central preference keys + defaults + typed accessors |
| Preferences UI | `iina/Pref*ViewController.swift` | per-tab settings UIs; some changes propagate immediately |
| Plugin runtime (JS) | `iina/JavascriptPlugin.swift` `iina/JavascriptPluginInstance.swift` | loads plugins from Application Support, executes entry JS |
| Plugin UI bridge | `iina/JavascriptMessageHub.swift` `iina/Plugin*View*.swift` | injects `window.iina` bridge into plugin webviews |
| Plugin tooling CLI | `iina-plugin/main.swift` | scaffolds/pack/link/unlink plugins; separate from runtime |
| CLI wrapper | `iina-cli/main.swift` | spawns `IINA` binary in bundle; maps `--` args to `--mpv-*` |
| Browser extension | `browser/Chrome_Open_In_IINA/common.js` | constructs `iina://open?...` and triggers navigation |
| Safari extension | `OpenInIINA/SafariExtensionHandler.swift` | opens `iina://weblink?url=...` via `NSWorkspace` |
| mpv API bindings codegen | `other/parse_doc.rb` | regenerates `iina/MPV{Command,Option,Property}.swift` |
| Download prebuilt deps | `other/download_libs.sh` | populates `deps/lib` and `deps/executable` |
| Xcode build settings | `Configs/Shared.xcconfig` `Configs/Deployment.xcconfig` | warnings, deployment targets, signing |
| CI build | `.github/workflows/ci.yml` | runs `./other/download_libs.sh` then `xcodebuild ... -configuration Nightly` |
| Localization workflow | `CONTRIBUTING.md` `iina/Base.lproj/` `iina/en.lproj/` | strings changes only in Base+en; Crowdin syncs others |

## CODE MAP
| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `AppDelegate` | class | `iina/AppDelegate.swift` | app lifecycle, URL scheme handler, preferences window wiring |
| `PlayerCore` | class | `iina/PlayerCore.swift` | central playback/controller layer; owns `mpv` instance |
| `MPVController` | class | `iina/MPVController.swift` | libmpv bridge: init, options, commands, event loop |
| `VideoView` | class | `iina/VideoView.swift` | view/render lifecycle; coordinates mpv render teardown |
| `MainWindowController` | class | `iina/MainWindowController.swift` | window + OSC + sidebar + fullscreen/PiP behavior |
| `Preference` | type | `iina/Preference.swift` | preference keys/defaults + typed accessors |
| `JavascriptPlugin` | class | `iina/JavascriptPlugin.swift` | plugin discovery/metadata/installation |
| `JavascriptPluginInstance` | class | `iina/JavascriptPluginInstance.swift` | executes plugin entry JS; per-player/global instances |

## CONVENTIONS (THIS REPO)
- Formatting: `.editorconfig` uses `indent_size=2`; exception: `deps/include/**` uses `indent_size=4`.
- Swift version: `Configs/Shared.xcconfig` sets `SWIFT_VERSION = 5.0`.
- Deployment targets: `Configs/Deployment.xcconfig` sets `MACOSX_DEPLOYMENT_TARGET = 10.15` and `MACOSX_DEPLOYMENT_TARGET[arch=arm64] = 12`.
- Availability flags: `Configs/Availability.xcconfig` defines `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $AVAILABLE_$(SDK_VERSION_MAJOR)`.

## ANTI-PATTERNS (THIS PROJECT)
- Do not call mpv APIs outside `iina/VideoView.swift` and `iina/MPVController.swift` (from `CONTRIBUTING.md`).
- Do not edit generated mpv bindings directly: `iina/MPVCommand.swift`, `iina/MPVOption.swift`, `iina/MPVProperty.swift` (generated by `other/parse_doc.rb`).
- Do not include localization changes outside `iina/Base.lproj` and `iina/en.lproj` in PRs; translations are managed via Crowdin.

## COMMANDS
```bash
# Download prebuilt dylibs/executables (required for most builds)
./other/download_libs.sh

# Build (matches CI)
xcodebuild -project iina.xcodeproj -scheme iina -configuration Nightly ONLY_ACTIVE_ARCH=NO

# Regenerate mpv option/command/property bindings (when updating libmpv)
ruby other/parse_doc.rb

# Re-vendor/copy dylibs into deps/lib (when updating mpv/FFmpeg from Homebrew/MacPorts)
ruby other/change_lib_dependencies.rb "$(brew --prefix)" "$(brew --prefix mpv-iina)/lib/libmpv.dylib"
```

## DOWNLINKS
- Main app: `iina/AGENTS.md`
- Dependencies: `deps/AGENTS.md`
- Build configs: `Configs/AGENTS.md`
- Scripts/tooling: `other/AGENTS.md`
- Browser extension: `browser/AGENTS.md`
- Safari extension: `OpenInIINA/AGENTS.md`
- CLI wrapper: `iina-cli/AGENTS.md`
- Plugin tooling CLI: `iina-plugin/AGENTS.md`
