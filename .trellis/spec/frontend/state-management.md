# UI State Management

There is no frontend state-management library. State is held in controllers, `PlayerCore`/`PlaybackInfo`, `Preference`, and AppKit controls.

## Playback state

- Playback-facing UI should read and mutate playback through `PlayerCore` and `PlaybackInfo`.
- `PlayerCore` owns per-player state such as `info`, `mpv`, `events`, `plugins`, `mainWindow`, `miniPlayer`, and feature controllers like `multiLoop`.
- `MainWindowController` and `PlayerWindowController` are responsible for syncing window controls to player state.
- Avoid duplicating core playback state in UI controllers. UI caches are acceptable for control behavior, but source-of-truth playback state belongs in `PlayerCore`/`PlaybackInfo` or feature-specific controllers.

## Feature state

- Keep feature logic separate from feature UI. The current multi-loop feature keeps segment state, persistence, and seeking behavior in `iina/MultiLoop.swift`, while row rendering and user actions live in `iina/MultiLoopViewController.swift`.
- Expose small methods on feature controllers for UI actions. `MultiLoopController` provides `setPointAtCurrentTime()`, `undoLastPoint()`, `removeSegment(at:)`, `startSequenceFromFirstSegment()`, and `markerTimes()`.
- Persist feature state from the feature controller, not from table-cell rendering or low-level controls.

## Preferences

- Long-lived settings go through `Preference` and `UserDefaults`, not ad hoc globals.
- `PreferenceViewController` subclasses bind preference panels to `Preference.Key` values and use localized titles/images for the preference window.
- Controllers that need live preference updates should add keys to an observed list and update local cached values in KVO, following `PlayerWindowController`.

## UI view state

- Controller-local UI state is stored as properties. Examples: `QuickSettingViewController.currentTab`, `pendingSwitchRequest`, and `downShift`; `MainWindowController.sideBarStatus`, `isDragging`, `pipStatus`, and timer properties.
- When a view may not be loaded yet, cache pending UI requests and apply them in `viewDidLoad()`. `QuickSettingViewController.pendingSwitchRequest` documents this pattern.
- Use `reloadData()` and targeted state refresh methods after model changes. `MultiLoopViewController.reload()` updates the table and empty state after delete/undo actions.

## Browser extension state

- Chrome extension options use `chrome.storage.sync`. `browser/Chrome_Open_In_IINA/common.js` defines `Option`, `getOptions`, `saveOptions`, and `restoreOptions` around `iconAction` and `iconActionOption`.
- Do not add a native messaging state channel for browser integration; current browser state is minimal and URL-scheme based.
