# UI Helper and Hook-Like Patterns

This Swift/AppKit project does not use React hooks. Treat "hooks" as reusable UI helper methods, observers, notifications, and event wiring patterns.

## Notification and observer helpers

- Reuse existing observer helpers when available. `PlayerWindowController.addObserver(to:forName:object:using:)` registers notifications on the main queue.
- Keep observer lifecycle balanced. `PlayerWindowController` adds KVO observers for `observedPrefKeys` in `windowDidLoad()` and removes them in `deinit`.
- Store opaque observer tokens when the API returns them and remove them during teardown if the owning object outlives the observed object. `QuickSettingViewController` has an `observers: [NSObjectProtocol]` property for this style.

## Preferences as reactive inputs

- For UI that reflects preferences, cache the typed value and update it in KVO. `PlayerWindowController` caches seek, scroll, volume, and click preferences as `lazy` properties and updates them in `observeValue(...)`.
- Preference changes that affect visible UI should update controls immediately when practical. `PlayerWindowController` updates the remaining-time label, window material, volume slider max, and playlist table when relevant keys change.

## Player events and plugin events

- Use `EventController` for IINA/plugin event emission. Event names are wrapped in `EventController.Name` instead of raw strings, for example `.windowLoaded`, `.fileLoaded`, `.mpvInitialized`, and `.pluginOverlayLoaded`.
- For system notifications, use typed `Notification.Name` constants already present in the app rather than new raw strings when possible.

## Programmatic UI helpers

- Use small private helpers on controllers for repeated UI state updates. Examples from `MultiLoopViewController`: `reload()`, `updateEmptyState()`, and `formatTime(_:)`.
- Use methods such as `setupLoopTab()` or `switchToTab(...)` on existing controllers rather than embedding one-off setup inside unrelated actions.
- When inserting AppKit views programmatically, set `translatesAutoresizingMaskIntoConstraints = false` and activate constraints near view creation.

## Closure capture conventions

- Existing code often uses `[unowned self]` for notification closures tied to controller lifetime, such as `PlayerWindowController.windowDidLoad()` observers.
- Use `weak` references for cross-controller/player references that should not extend lifetime. `QuickSettingViewController.mainWindow` is weak; `MultiLoopViewController.player` is weak.
- Use `unowned` for required owner relationships where the owner outlives the helper. `MultiLoopController` stores `private unowned let player`.
