# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This repository is a fork of IINA, a modern macOS media player based on mpv. This fork adds multi-segment loop support with default bindings documented in `README.md`: `L` sets loop points, `Shift+L` undoes/removes the last point or segment, `Cmd+L` plays segments in sequence, and `Shift+Cmd+L` clears all segments. The Loop UI lives in the Quick Settings sidebar.

The app is an Xcode project (`iina.xcodeproj`) with four shared schemes/targets:

- `iina` — main macOS AppKit application and playback runtime.
- `iina-cli` — launcher CLI that forwards file paths and mpv-like options into `IINA.app`.
- `iina-plugin` — Swift CLI for plugin development workflows (`new`, `pack`, `link`, `unlink`).
- `OpenInIINA` — Safari extension for opening pages/links via IINA.

## Common commands

Set up prebuilt mpv/FFmpeg dependencies before building the app:

```sh
./other/download_libs.sh
```

Inspect available targets/schemes:

```sh
xcodebuild -list -project iina.xcodeproj
```

Build the main app from the command line:

```sh
xcodebuild -project iina.xcodeproj -scheme iina -configuration Debug build
```

Build the auxiliary targets:

```sh
xcodebuild -project iina.xcodeproj -scheme iina-cli -configuration Debug build
xcodebuild -project iina.xcodeproj -scheme iina-plugin -configuration Debug build
xcodebuild -project iina.xcodeproj -scheme OpenInIINA -configuration Debug build
```

Run the Xcode test action for a scheme:

```sh
xcodebuild -project iina.xcodeproj -scheme iina -configuration Debug test
```

Run static analysis for the main app:

```sh
xcodebuild -project iina.xcodeproj -scheme iina -configuration Debug analyze
```

Regenerate mpv bindings after updating mpv documentation/API inputs:

```sh
other/parse_doc.rb
```

Re-vendor manually built mpv dylibs into `deps/lib`:

```sh
other/change_lib_dependencies.rb "$(brew --prefix)" "$(brew --prefix mpv-iina)/lib/libmpv.dylib"
```

## Architecture and boundaries

### Main app (`iina/`)

- `AppDelegate.swift` handles startup, Apple Events, and URL scheme routing such as `iina://open` and `iina://weblink`.
- `PlayerCore.swift` is the high-level playback API surface. Keep general playback logic here.
- `MPVController.swift` owns libmpv lifecycle, event handling, and option/property mapping.
- `VideoView.swift` participates in render lifecycle and mpv rendering teardown.
- `MainWindowController.swift` owns main-window behavior, OSC/sidebar/fullscreen/PiP coordination, and UI sync.
- `Preference.swift` is the canonical location for preference keys and defaults.
- `Pref*ViewController.swift` files implement preference panes.
- Plugin runtime loading is in `JavascriptPlugin.swift`; the JavaScript bridge is in `JavascriptMessageHub.swift`; plugin webview surfaces include `PluginOverlayView.swift`, `PluginSidebarView.swift`, and `PluginStandaloneWindow.swift`.

Important app-layer constraints from `CONTRIBUTING.md` and `iina/AGENTS.md`:

- Only `VideoView` and `MPVController` should call mpv APIs directly.
- Route playback behavior through `PlayerCore`; setting mpv options/properties directly through `MPVController` is discouraged outside the established boundary.
- Window-related logic belongs in `MainWindowController`.
- Do not edit generated `MPVCommand.swift`, `MPVOption.swift`, or `MPVProperty.swift` directly; regenerate them with `other/parse_doc.rb`.
- For UI text changes, update only `iina/Base.lproj` and `iina/en.lproj`; Crowdin handles other localizations.
- Avoid committing spurious `.xib` or `project.pbxproj` changes caused by Xcode unless they are intentional.

### Extensions and tools

- `browser/` contains Chrome/Firefox “Open In IINA” browser extension files. The Chrome extension builds `iina://open?url=<encoded>` URLs in `browser/Chrome_Open_In_IINA/common.js`; do not assume a native messaging host.
- `OpenInIINA/` is the Safari extension. It launches IINA through `iina://weblink?url=<escaped>` in `SafariExtensionHandler.swift`; keep this URL scheme in sync with `iina/AppDelegate.swift`.
- `iina-cli/main.swift` is a launcher, not a long-lived control API. It expects to run inside an `IINA.app` bundle and rewrites `--` arguments into `--mpv-*` flags.
- `iina-plugin/main.swift` is separate from the runtime plugin loader. It scaffolds, packs, links, and unlinks plugin development packages.

### Build configuration and dependencies

- Build settings live in `Configs/*.xcconfig`. `Configs/Shared.xcconfig` covers shared warnings/language settings, and target-specific files configure search paths and target options.
- `Configs/iina.xcconfig` points headers to `deps/include` and libraries to `deps/lib`.
- `deps/include` contains vendored mpv/FFmpeg headers. Keep headers and dylibs version-matched.
- `deps/lib` and `deps/executable` are populated by dependency scripts rather than normal source edits.
- `other/` contains repository maintenance scripts for downloading dylibs, regenerating mpv bindings, changing dylib install names, and updating document-type icons.

## Trellis workflow

This repository is Trellis-managed. Before implementation work, read the relevant `.trellis/spec/` guidance and follow `.trellis/workflow.md` or the available Trellis slash commands. Root and per-directory `AGENTS.md` files contain additional local guidance and should be checked before editing within those directories.
