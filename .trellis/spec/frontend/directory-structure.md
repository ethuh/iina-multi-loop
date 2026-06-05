# UI Directory Structure

This repository does not have a web frontend in the main app. Treat this spec area as AppKit UI, plugin/web-extension UI, and other UI-facing code.

## AppKit UI in `iina/`

- Main playback window behavior lives in `iina/MainWindowController.swift`, subclassing `PlayerWindowController` from `iina/PlayerWindowController.swift`.
- Shared player-window controls and mouse/key handling live in `PlayerWindowController.swift`.
- Quick Settings sidebar code lives in `iina/QuickSettingViewController.swift`; its XIB is `iina/Base.lproj/QuickSettingViewController.xib`.
- Playlist/sidebar/plugin UI controllers are separate files such as `iina/PlaylistViewController.swift`, `iina/PluginViewController.swift`, and `iina/MultiLoopViewController.swift`.
- Preferences tabs use `Pref*ViewController.swift` files, for example `iina/PrefGeneralViewController.swift`, `iina/PrefCodecViewController.swift`, and `iina/PrefPluginViewController.swift`.
- Preference tab controllers implement `PreferenceWindowEmbeddable` and usually subclass `PreferenceViewController`.
- Assets live under `iina/Assets.xcassets`; localized strings and XIBs live in `iina/Base.lproj` and `iina/en.lproj` for source-language changes.

## XIB vs programmatic UI

- `CONTRIBUTING.md` says to use a XIB for UI when possible, especially for positioning, layer use, and Cocoa bindings.
- Existing large controllers such as `QuickSettingViewController` and `PrefGeneralViewController` load from XIB via `override var nibName: NSNib.Name`.
- Small or feature-contained UI may be programmatic when that is already how the feature is structured. `iina/MultiLoopViewController.swift` creates an `NSTableView`, `NSScrollView`, and empty-state label in `loadView()`.

## Browser and Safari extension UI

- Chrome/Firefox extension files live under `browser/`.
  - `browser/Chrome_Open_In_IINA/background.js` creates context menus.
  - `browser/Chrome_Open_In_IINA/common.js` builds the `iina://open?...` URL.
  - `browser/Chrome_Open_In_IINA/options.html` and `options.js` implement options UI via `chrome.storage.sync`.
  - `browser/Chrome_Open_In_IINA/popup.html` and `popup.js` implement the popup.
- Safari extension files live under `OpenInIINA/`.
  - `OpenInIINA/Info.plist` registers toolbar/context-menu entries.
  - `OpenInIINA/SafariExtensionHandler.swift` opens `iina://weblink?url=...` through `NSWorkspace`.
  - `OpenInIINA/open-in-iina.js` is the content script.

## UI integration boundaries

- UI controllers should call `PlayerCore` methods for playback features rather than reaching directly into mpv, except for existing established controller behavior.
- Window lifecycle work follows `CONTRIBUTING.md`: `windowDidLoad()` for one-time setup, `windowDidOpen()` for each show/reset, and `windowWillClose()` for resource release.
- Avoid unrelated XIB churn. Discard XIB changes if the UI was not intentionally edited.
