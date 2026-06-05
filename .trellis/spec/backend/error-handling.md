# Core Error Handling Guidelines

IINA is a desktop media app. Error handling should preserve playback when possible, surface user-actionable failures through AppKit alerts, and use fatal termination only for unrecoverable initialization or invariant failures.

## User-facing errors

- Use `Utility.showAlert(...)` for localized user-visible alerts. It builds keys under `alert.<key>` and supports critical, warning, informational, sheet-modal, and suppression-button cases.
- Use `Utility.quickAskPanel(...)`, `quickOpenPanel(...)`, and `quickSavePanel(...)` for standard dialogs. They keep AppKit behavior consistent and handle sheet vs app-modal presentation.
- Add localization strings only to `iina/Base.lproj` and `iina/en.lproj`; `CONTRIBUTING.md` says other languages are managed by Crowdin.

## Recoverable errors

- Prefer `do`/`catch` plus `Logger.log(..., level: .warning/.error)` when a failure should not interrupt playback. Example: `MultiLoopStore.load(watchLaterKey:)` logs a warning and returns `nil` if JSON cannot be read or decoded.
- Guard invalid playback state early. Example: `MultiLoopController.setPointAtCurrentTime()` returns `.ignored` when the player is inactive, the time position is not finite, or the segment is shorter than the minimum.
- Use optional guards around AppKit and player state rather than force-unwrapping unless the surrounding class invariant already relies on that object.

## Fatal errors and invariants

- `Logger.fatal(...)` and `Logger.ensure(...)` log the error, show an alert, and terminate. Reserve these for conditions where continuing would corrupt state or crash later.
- `Logger.fatalDuringInit(...)` is specifically for logger initialization and intentionally avoids logging through the normal logger.
- `fatalError("init(coder:) has not been implemented")` appears in programmatic controllers such as `iina/MultiLoopViewController.swift` and window/controller base classes that are not intended to be decoded from storyboards.
- `assertionFailure(...)` is used for impossible switch defaults in UI integration code, such as `OpenInIINA/SafariExtensionHandler.swift` and `Utility.showAlert` unknown cases.

## mpv and threading errors

- `MPVController.swift` documents that the mpv event queue can overflow. Do not perform slow processing on `MPVController.queue`; dispatch work to the main thread or another queue.
- When a key binding command fails, `PlayerWindowController.handleKeyBinding(_:)` logs the nonzero return value at error level and returns `false` instead of crashing.
- AppKit actions that must run on the main thread should be scheduled appropriately. `PlayerWindowController` uses `RunLoop.main.perform(inModes: [.common])` when handling mpv quit.

## Objective-C and filesystem edge cases

- Use existing wrappers where present. `Logger.closeLogFile()` and log writes use `ObjcUtils.catchException` because some file-handle Objective-C exceptions are not reliably bridged to Swift errors.
- Logger initialization must not call `Utility.createDirIfNotExist`-style helpers that themselves log; `Logger` has its own private directory creation helper to avoid recursive initialization crashes.
