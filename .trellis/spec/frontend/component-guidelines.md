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
