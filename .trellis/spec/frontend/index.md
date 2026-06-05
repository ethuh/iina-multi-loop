# AppKit UI Guidelines Index

This project does not have a conventional web frontend for the main app. Treat the frontend spec area as IINA's AppKit UI layer, preference panels, plugin/browser-extension UI, and UI-facing state patterns.

## Guides

| Guide | Project scope | Status |
|-------|---------------|--------|
| [Directory Structure](./directory-structure.md) | AppKit controller/XIB layout, browser/Safari extension files, UI integration boundaries | Complete |
| [Component Guidelines](./component-guidelines.md) | `NSWindowController`/`NSViewController` structure, outlets/actions, layout, localization | Complete |
| [Hook-Like Patterns](./hook-guidelines.md) | Observers, notifications, preference KVO, event wiring, closure captures | Complete |
| [State Management](./state-management.md) | No frontend state library; `PlayerCore`, `PlaybackInfo`, `Preference`, controller-local state | Complete |
| [Quality Guidelines](./quality-guidelines.md) | macOS UI quality, accessibility/localization, lifecycle cleanup, performance, verification | Complete |
| [Type Safety](./type-safety.md) | Swift wrappers/enums/optionals/availability and plain JavaScript extension conventions | Complete |

## Key project examples referenced by these guides

- `iina/MainWindowController.swift` and `iina/PlayerWindowController.swift` own the main playback window, OSC, sidebars, mouse/key handling, fullscreen/PiP, and UI synchronization.
- `iina/QuickSettingViewController.swift` demonstrates XIB-backed sidebar UI, preference KVO, table delegates, and availability-guarded AppKit APIs.
- `iina/MultiLoopViewController.swift` demonstrates feature-contained programmatic AppKit UI, table row rendering, target/action wiring, and UI refresh helpers.
- `iina/PrefGeneralViewController.swift`, `iina/PrefCodecViewController.swift`, and `iina/PrefPluginViewController.swift` demonstrate preference tab organization.
- `browser/Chrome_Open_In_IINA/common.js` and `OpenInIINA/SafariExtensionHandler.swift` demonstrate the URL-scheme-based browser and Safari integrations.

Use these files as the source of truth for future Trellis implementation and check agents working on AppKit UI, preference panels, plugin UI, browser extension UI, or UI-facing state changes.
