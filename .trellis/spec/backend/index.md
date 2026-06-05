# Core App Guidelines Index

This project is IINA: a Swift/AppKit macOS media player built around libmpv, plus CLI tools, plugin tooling, browser/Safari URL-scheme integrations, and vendored runtime dependencies. Treat the backend spec area as the core app, playback, persistence, logging, and build/tooling boundary rather than as a server backend.

## Guides

| Guide | Project scope | Status |
|-------|---------------|--------|
| [Directory Structure](./directory-structure.md) | Top-level repo layout, app/playback/mpv boundaries, generated and vendored files | Complete |
| [Data and Persistence](./database-guidelines.md) | No ORM/database; `Preference`, file-backed state, watch-later keys, dependency state | Complete |
| [Error Handling](./error-handling.md) | AppKit alerts, recoverable playback errors, fatal invariants, mpv/threading edge cases | Complete |
| [Logging Guidelines](./logging-guidelines.md) | `Logger` API, levels, subsystems, mpv log constraints, initialization caveats | Complete |
| [Quality Guidelines](./quality-guidelines.md) | Swift 5.0 formatting, Xcode build verification, architecture boundaries, lifecycle review checks | Complete |

## Key project examples referenced by these guides

- `iina/PlayerCore.swift` owns player instances, playback orchestration, `PlaybackInfo`, plugins, and `MPVController`.
- `iina/MPVController.swift` and `iina/VideoView.swift` are the only places that should call mpv APIs directly.
- `iina/Preference.swift` is the source of truth for preference keys, defaults, and typed accessors.
- `iina/MultiLoop.swift` demonstrates feature-owned playback state, JSON persistence, watch-later keys, and recoverable logging.
- `other/parse_doc.rb` regenerates `iina/MPVCommand.swift`, `iina/MPVOption.swift`, and `iina/MPVProperty.swift`; those generated files should not be hand-edited.

Use these files as the source of truth for future Trellis implementation and check agents working on core app, playback, persistence, logging, dependency, or build-tooling changes.
