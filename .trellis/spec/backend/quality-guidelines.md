# Core Quality Guidelines

## Formatting and language level

- Use 2-space indentation and trim trailing whitespace. `.editorconfig` applies this repository-wide, except `deps/include/**` uses 4-space indentation for vendored headers.
- Swift code is built as Swift 5.0 according to `Configs/Shared.xcconfig`.
- Keep new code consistent with surrounding files; `CONTRIBUTING.md` explicitly says there is no fixed Swift style guide beyond consistency.

## Build and verification

- Most local builds require dependencies first: `./other/download_libs.sh`.
- CI-style build command from `AGENTS.md` is `xcodebuild -project iina.xcodeproj -scheme iina -configuration Nightly ONLY_ACTIVE_ARCH=NO`.
- Prefer lightweight targeted verification when changing docs, scripts, or isolated source; full Xcode builds may require downloaded dylibs.

> **Xcode SDK availability gotcha**: `Configs/Availability.xcconfig` expands `SWIFT_ACTIVE_COMPILATION_CONDITIONS` from `AVAILABLE_$(SDK_VERSION_MAJOR)`. When building with a newly numbered macOS SDK, add the corresponding cumulative `AVAILABLE_<version>` definition or Swift receives an invalid literal `$AVAILABLE_...` condition.

## Architectural review checks

- Do not call mpv APIs outside `iina/MPVController.swift` and `iina/VideoView.swift`.
- Keep high-level playback operations in `PlayerCore`; avoid setting mpv options/properties directly from random controllers.
- Keep window and UI lifecycle logic in `MainWindowController` / `PlayerWindowController`.
- Do not directly edit generated `iina/MPVCommand.swift`, `iina/MPVOption.swift`, or `iina/MPVProperty.swift`.

## Concurrency and lifecycle

- Respect comments documenting thread requirements. `PlayerCore.active` and `lastActive` are documented as main-thread-sensitive.
- `MPVController.queue` must only read mpv events and must not do slow processing; dispatch processing elsewhere.
- Remove KVO observers in `deinit` when adding preference observation. `PlayerWindowController` removes each key in `observedPrefKeys` with `ObjcUtils.silenced`.
- Use weak or unowned references following existing ownership. Examples: `MultiLoopController` keeps `private unowned let player`, `MultiLoopViewController` keeps `private weak var player`, and plugin/window controllers often use `[unowned self]` in notification closures tied to controller lifetime.

## Pull request hygiene from CONTRIBUTING.md

- Submit separate PRs for unrelated features.
- Avoid spurious changes to `iina.xcodeproj/project.pbxproj` and XIBs unless you intentionally changed project wiring or UI.
- For UI text changes, update only `iina/Base.lproj` and `iina/en.lproj`; do not modify other localized folders.

## Comments and documentation

- Add comments when necessary, especially for non-obvious playback, threading, or lifecycle behavior.
- Existing code uses `// MARK: -` sections heavily in controllers and doc comments for important preconditions and threading notes.
