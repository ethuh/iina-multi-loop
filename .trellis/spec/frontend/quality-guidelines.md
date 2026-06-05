# UI Quality Guidelines

## Visual and interaction quality

- Follow macOS Human Interface Guidelines and built-in macOS app behavior unless existing IINA behavior intentionally differs.
- `CONTRIBUTING.md` calls out UI/UX priorities: use animations when possible, use proper system font weight/size/color, and leave margins everywhere.
- Use named colors and system colors to fit app themes. Examples: `NSColor(named: .sidebarTableBackground)`, `.secondaryLabelColor`, `.labelColor`, and `.systemOrange`.
- Use monospaced digit fonts for time-like values. Examples: `MainWindowController.monospacedFont` and `MultiLoopViewController` row labels.

## Accessibility and localization

- Use localized strings for user-visible text. Examples include preference tab titles and multi-loop empty state labels.
- Provide accessibility descriptions when using system images programmatically. `MultiLoopViewController` passes `accessibilityDescription: "Delete"` to `NSImage(systemSymbolName:...)`.
- For new UI strings, update only `iina/Base.lproj` and `iina/en.lproj`; Crowdin handles other languages.

## Lifecycle and cleanup

- Put one-time window setup in `windowDidLoad()`, per `CONTRIBUTING.md`.
- Put per-show reset logic in `windowDidOpen()` and cleanup/deinitialization in `windowWillClose()` when working in window controllers.
- Remove observers and stop timers as needed. `PlayerWindowController.deinit` removes KVO observers; `Logger.closeLogFile()` coordinates shutdown writes with a lock.

## Performance

- Avoid heavy work on the main thread during playback UI updates.
- Avoid slow work on `MPVController.queue`; it is only for reading mpv events quickly.
- Throttle frequent playback-time UI/feature work. `MultiLoopController.handleTimePosUpdate(_:)` throttles to avoid excessive boundary checks and repeated seeks.

## Project hygiene

- Do not commit unrelated XIB changes. `CONTRIBUTING.md` warns XIBs often get spurious changes.
- Do not change URL-scheme formats casually; browser and Safari extensions must match `AppDelegate` routing.
- Browser extension integration currently uses URL scheme navigation, not native messaging. Keep UI actions simple unless the app protocol changes too.

## Verification

- For UI source changes, at minimum inspect changed XIB/source files for accidental unrelated edits and run a targeted build when dependencies are available.
- Full app verification uses `xcodebuild -project iina.xcodeproj -scheme iina -configuration Nightly ONLY_ACTIVE_ARCH=NO` after `./other/download_libs.sh` has populated dependencies.
- For extension JavaScript changes, verify `common.js` still constructs the expected `iina://open?url=<encoded>` URL and preserves optional flags `full_screen=1`, `pip=1`, `enqueue=1`, and `new_window=1`.
