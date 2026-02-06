# Configs/

## OVERVIEW
Xcode build settings split across shared and per-target `.xcconfig` files.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Shared warnings/lang | `Configs/Shared.xcconfig` | warnings, hardened runtime, `SWIFT_VERSION = 5.0` |
| Deployment/versioning | `Configs/Deployment.xcconfig` | deployment targets, `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` |
| Availability flags | `Configs/Availability.xcconfig` | `SWIFT_ACTIVE_COMPILATION_CONDITIONS` derived from SDK version |
| Target-specific settings | `Configs/iina.xcconfig` `Configs/iina-cli.xcconfig` `Configs/iina-plugin.xcconfig` `Configs/OpenInIINA.xcconfig` | header/lib search paths, bridging header, etc. |

## CONVENTIONS
- `Configs/iina.xcconfig` sets `HEADER_SEARCH_PATHS = $(SRCROOT)/deps/include` and `LIBRARY_SEARCH_PATHS = $(SRCROOT)/deps/lib`.
