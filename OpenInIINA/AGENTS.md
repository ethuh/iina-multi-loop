# OpenInIINA/

## OVERVIEW
Safari extension that adds context menu + toolbar actions to open the current page or a link in IINA.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Extension manifest | `OpenInIINA/Info.plist` | registers `SFSafariContextMenu` and `SFSafariToolbarItem` |
| Command handling | `OpenInIINA/SafariExtensionHandler.swift` | opens `iina://weblink?url=...` via `NSWorkspace` |
| Content script | `OpenInIINA/open-in-iina.js` | referenced by `Info.plist` as `SFSafariContentScript` |

## CONVENTIONS (THIS DIR)
- Uses `iina://weblink?url=<escaped>` (see `SafariExtensionHandler.launchIINA(withURL:)`).
- URL escaping uses `.addingPercentEncoding(withAllowedCharacters: .alphanumerics)`.

## ANTI-PATTERNS
- Don't change the URL scheme format casually; `iina/AppDelegate.swift` must match.
