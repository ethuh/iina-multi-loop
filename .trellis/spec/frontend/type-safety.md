# Swift and JavaScript Type Safety

## Swift type patterns

- Prefer typed wrappers over raw strings for app concepts. Examples:
  - `Preference.Key` wraps preference raw values.
  - `EventController.Name` wraps event raw values.
  - `MPVOption`, `MPVCommand`, and `MPVProperty` provide generated constants for mpv names.
- Use enums for finite UI and playback states. Examples include `QuickSettingViewController.TabViewType`, `MainWindowController.FullScreenState`, `MultiLoopSetPointResult`, and `MultiLoopUndoResult`.
- Use `Codable` for small persisted Swift models. `MultiLoopSegment` and `MultiLoopPersistedState` are `Codable` and `Equatable`.
- Use typed preference accessors (`Preference.bool`, `integer`, `enum`) instead of manual casts where existing APIs cover the value.

## Optionals and ownership

- Guard optional player/app state before use when it may be absent. `MultiLoopController` guards `player.info.watchLaterKey`; `Utility.quickOpenPanel` checks result and `panel.url` before invoking callbacks.
- Existing UI code sometimes uses implicitly unwrapped outlets and player references because AppKit/XIB lifecycle guarantees them. Match surrounding style, but do not add force unwraps where a simple `guard let` handles absence.
- Use `weak` for references that should not keep another controller alive and `unowned` for owner relationships that are required for the helper's lifetime.

## Availability and platform APIs

- Use `#available` / `#unavailable` checks around newer AppKit APIs and SF Symbols. Examples appear in `MainWindowController` title-bar constants, `QuickSettingViewController` color wells, and `MultiLoopViewController` delete button images.
- Deployment targets are macOS 10.15 generally and macOS 12 for arm64 from `Configs/Deployment.xcconfig`; do not assume newer APIs without availability guards.

## Objective-C interoperability

- Use `@objc`, `@objcMembers`, and `dynamic` when AppKit, KVO, Cocoa bindings, or Objective-C runtime access requires them. Examples: `PrefGeneralViewController` is `@objcMembers`; `Logger.Log` has `@objc dynamic` properties.
- Selector-based actions should be marked `@objc` when connected programmatically, such as `MultiLoopViewController.deleteSegment(_:)`.

## JavaScript extension code

- Browser extension code is plain JavaScript modules, not TypeScript. Keep the small typed-by-convention structure already present in `common.js`.
- Use `encodeURIComponent` for URL parameters and preserve existing escaping of single quotes in `openInIINA(...)`.
- Chrome extension options are keyed by string names through the `Option` class; keep defaults explicit in the `options` array.

## Generated types

- Do not edit generated mpv type/constant files directly. If mpv command, option, or property definitions are stale, update `other/parse_doc.rb` inputs/workflow and regenerate.
