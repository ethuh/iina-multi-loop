# Logging Guidelines

Use the in-repo `Logger` class for application logging. Logging is user-configurable from Advanced preferences and is disabled by default outside debug-style console output.

## Logger API

- Call `Logger.log(_:, level:subsystem:)` for general messages.
- Prefer class-local helper methods when available. `PlayerCore.log(_:, level:)` logs with a per-player subsystem, and `PlayerWindowController` has a `subsystem` created from the player number.
- Use lazy autoclosure logging for interpolated messages so expensive string construction is skipped when the level is filtered. `Logger.log` is designed around this pattern.

## Levels

- Available levels are `verbose`, `debug`, `warning`, and `error`.
- Default level argument is `.debug`.
- Use `.warning` for recoverable failures that may explain degraded behavior, such as failure to load or save multi-loop JSON in `iina/MultiLoop.swift`.
- Use `.error` for failed commands or invariant failures, such as nonzero mpv key-command return values in `PlayerWindowController.handleKeyBinding(_:)`.

## Subsystems

- Use `Logger.makeSubsystem(...)` for component-specific subsystems.
- Real examples:
  - `PlayerCore` creates `player<label>` subsystems.
  - `MPVController` creates `mpv<playerNumber>` subsystems.
  - `PlayerWindowController` creates `window<playerNumber>` subsystems.
  - `Logger` has an internal `logger` subsystem and a general `iina` subsystem.

## Format and output

- Log lines are formatted by `Logger.formatMessage` as `HH:mm:ss.SSS [subsystem][level] message`.
- `Logger` stores recent logs in `Logger.logs` for the log window, prints to stdout, and writes to `~/Library/Logs/<bundle id>/<timestamp>_<token>/iina.log` when advanced logging is enabled.
- Do not invent a second logging framework for app code.

## mpv logging

- `iina/MPVController.swift` intentionally sets `MPVLogLevel = "warn"`. Comments explain that higher mpv log volumes can overflow mpv's limited event queue.
- Do not raise mpv log verbosity permanently to debug or trace levels. Temporary debugging should account for event queue overflow risk.

## Logger initialization caveat

- `Logger` must not call helpers that themselves log while it is initializing. It uses its own private directory creation helper for this reason.
- During initialization failures, use `fatalDuringInit` semantics: print, show alert, and terminate without attempting normal logging.
