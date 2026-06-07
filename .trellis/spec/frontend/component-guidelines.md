# AppKit Component and Controller Guidelines

## Controller structure

- AppKit UI is organized around `NSWindowController` and `NSViewController` subclasses, not reusable web-style components.
- File names generally match class names: `MainWindowController`, `QuickSettingViewController`, `PrefGeneralViewController`, `MultiLoopViewController`.
- Use `// MARK: -` sections to group constants, outlets, lifecycle, actions, delegates, and helper methods. `MainWindowController.swift` and `PlayerWindowController.swift` are examples.
- For XIB-backed controllers, override `nibName` with `NSNib.Name("ClassName")`. Examples: `QuickSettingViewController` and `PrefGeneralViewController`.

## Outlets and actions

- Use `@IBOutlet weak var` for XIB-owned controls. `QuickSettingViewController.swift` has many examples for `NSTableView`, `NSSlider`, `NSSegmentedControl`, and `NSSwitch` outlets.
- Use `@IBAction` for XIB-wired actions. `PrefGeneralViewController.chooseScreenshotPathAction(_:)` opens a panel and stores the selected path.
- Programmatic controls should set `target` and `action` explicitly. `MultiLoopViewController.deleteSegment(_:)` is connected to per-row delete buttons by setting `button.target = self` and `button.action = #selector(deleteSegment(_:))`.

## OSC toolbar buttons

Adding a new On-Screen-Controller toolbar button (`Preference.ToolBarButton`) means updating **all** of these in sync — a missed one silently drops the button from a surface:

- `Preference.ToolBarButton` enum case — append at the end so existing persisted `rawValue`s in `.controlBarToolbarButtons` stay stable.
- `ToolBarButton.image()` and `.description()` switches (compiler-enforced). `description()` keys off `osc_toolbar.<key>` strings in `Base`/`en` only.
- `PrefOSCToolbarSettingsSheetController.allButtonTypes` (NOT compiler-enforced) so the button shows in the OSC customization sheet.
- `Preference.defaultPreference[.controlBarToolbarButtons]` if it should appear by default. Caveat: users with a previously-saved toolbar customization will NOT pick up new defaults — they must add it via the customization sheet.
- `MainWindowController.toolBarButtonAction(_:)` for the click action. Buttons are built in `setupOSCToolbarButtons` and added to `fragToolbarView`.

A button whose appearance reflects per-media or feature state (e.g. a toggle's tint) must be refreshed both where the state mutates AND on the `PlayerCore` fileLoaded path — the OSC is built once per window, but `MultiLoopController.resetForNewItem()` resets feature state for each new media item, so without a fileLoaded refresh the button shows stale state. Find the live button via `fragToolbarView.views` filtered by `tag == ToolBarButton.<case>.rawValue` (see `MainWindowController.refreshMultiLoopUI()`).

## Layout patterns

- Prefer XIB layout when adding normal preference panels or established sidebars, per `CONTRIBUTING.md`.
- For programmatic layout, use Auto Layout anchors or existing utility helpers. `MultiLoopViewController.loadView()` uses `NSLayoutConstraint.activate`; `QuickSettingViewController` uses `Utility.quickConstraints` for inserted color wells.
- Match existing macOS visual conventions: system fonts/colors, margins, table corner radius, template images, and `NSColor(named:)` assets such as `.sidebarTableBackground`.
- Use availability checks for AppKit API differences. Examples in `QuickSettingViewController`: `NSColorWell(style:)` on macOS 13+, SF Symbols delete button on macOS 11+, and macOS 26 slider/switch adjustments.

## Delegates and data sources

- Delegate/data-source conformance is commonly placed in an extension below the main class. `MultiLoopViewController` implements `NSTableViewDataSource` and `NSTableViewDelegate` in a `// MARK` extension.
- For table row reordering, use standard `NSTableView` drag/drop APIs (`registerForDraggedTypes`, `setDraggingSourceOperationMask`, `pasteboardWriterForRow`, `validateDrop`, `acceptDrop`) rather than custom gesture recognizers. Validate local drag source identity, force insertion-style drops with `.above`, and reject no-op insertion rows.
- Larger controllers may conform in the class declaration when that matches existing code, as `QuickSettingViewController` does for `NSTableViewDataSource`, `NSTableViewDelegate`, and `SidebarViewController`.

## Localization

- Use `NSLocalizedString` for user-facing strings. Examples: `PrefGeneralViewController.preferenceTabTitle`, `MultiLoopViewController.emptyLabel`, and reset-speed tooltips in `QuickSettingViewController`.
- Add or update strings only in `iina/Base.lproj` and `iina/en.lproj`; do not edit other language folders manually.

## User experience expectations

- Follow macOS Human Interface Guidelines and built-in macOS app behavior unless an existing IINA pattern differs intentionally.
- `CONTRIBUTING.md` emphasizes UI/UX quality: animations where possible, proper system font weight/size/color, and margins everywhere.
