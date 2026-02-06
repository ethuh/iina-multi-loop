# browser/

## OVERVIEW
Chrome/Firefox "Open In IINA" extensions. Chrome implementation is in-repo; Firefox has a manifest here.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Chrome manifest (MV3) | `browser/Chrome_Open_In_IINA/manifest.json` | service worker background script |
| Chrome background entry | `browser/Chrome_Open_In_IINA/background.js` | creates context menus; routes clicks to `openInIINA(...)` |
| URL scheme builder | `browser/Chrome_Open_In_IINA/common.js` | constructs `iina://open?url=...` and triggers navigation |
| Options UI | `browser/Chrome_Open_In_IINA/options.html` `browser/Chrome_Open_In_IINA/options.js` | stores settings via `chrome.storage.sync` |
| Popup UI | `browser/Chrome_Open_In_IINA/popup.html` `browser/Chrome_Open_In_IINA/popup.js` | quick action menu |
| Firefox manifest (MV2) | `browser/Firefox_Open_In_IINA/manifest.json` | implementation not present here |

## CONVENTIONS (THIS DIR)
- macOS integration is via URL scheme, not native messaging.
- Chrome scheme format (from `common.js`):
  - `iina://open?url=<encoded>`
  - optional flags: `full_screen=1`, `pip=1`, `enqueue=1`, `new_window=1`

## ANTI-PATTERNS
- Don't add "native messaging host" assumptions; current implementation is a simple `iina://` navigation.
