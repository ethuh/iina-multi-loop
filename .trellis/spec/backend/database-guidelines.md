# Core Data and Persistence Guidelines

This project uses macOS app mechanisms, files in Application Support-style locations, watch-later data, mpv state, and one narrowly scoped system-SQLite store for multi-loop records. It does not use an ORM or a server database.

## Scenario: Multi-loop SQLite persistence and external media identity

### 1. Scope / Trigger

- Use this contract when changing multi-loop persistence, video identity, legacy loop recovery, or the Emby-to-IINA URL-scheme integration.
- The SQLite store exists because mpv watch-later keys hash the raw playback URL. Signed Emby URLs change between launches, which made JSON sidecars appear lost.

### 2. Signatures

- Database file: `Utility.multiLoopDatabaseURL`, resolving to `Application Support/<bundle-id>/multiloop.sqlite3`.
- Store entry points:
  - `load(identity:merging:) -> [MultiLoopSegment]`
  - `replace(_:identity:)`
  - `clear(identity:)`
- URL-scheme fields accepted by `iina://weblink`:
  - `media_title`: optional human-readable filename/title.
  - `media_id`: optional non-secret external item ID.
- Schema version: `PRAGMA user_version = 1`, with `videos`, `loop_segments`, and `legacy_imports` tables. `external_id` is unique; `normalized_name` is indexed but not unique because different Emby items can share a filename.

### 3. Contracts

- Emby identity is `emby:<lowercased-host[:port]>:<media-id>`; it never contains a path, query, fragment, API key, or session ID.
- Filename/title fallback is source basename, then Emby title, then `Emby-<item-id>`. A generic `stream`, `master`, `playlist`, or `original` path is not a valid identity.
- Two launch paths must both produce the same identity for the same Emby item, and both must be kept working:
  - The `embytest` browser script sends `iina://weblink?...&media_title=&media_id=`; `media_id` is `itemInfo.Id`.
  - `embyToLocalPlayer` sends a bare stream URL through `iina-cli` (`/emby/videos/{itemId}/original.mp4?...`) plus `--mpv-force-media-title=<emby title>  |  <filename>`, and never reaches `openURLString`.
  Explicit metadata wins; otherwise the item ID comes from the URL path (`embyMediaID(for:)`) and the display name from mpv's `force-media-title`. The two ID sources are the same Emby item ID space.
- `force-media-title` may only be consulted for network URLs, and only at `openMainWindow`. It can be set globally in `mpv.conf` (which would collapse every local file into one identity), and mpv keeps it sticky across playlist items, so the `fileStarted` fallback stays URL-only.
- An identity with `externalID` resolves only by that ID. It must not fall back to a same-named external row. An identity without `externalID` may resolve by normalized name among rows whose `external_id IS NULL`.
- SQLite access is serialized, uses bound values, foreign keys, busy timeout, WAL, and transactions. The database is the sole write target; legacy JSON sidecars remain read-only migration sources.
- Import replaces the current video's loop set. Export includes only format/version, source display name, and segment times.

### 4. Validation & Error Matrix

- Missing safe filename/title and missing safe external ID -> `MultiLoopStoreError.noVideoIdentity`; do not persist under a URL or URL hash.
- Unsupported database `user_version` -> `unsupportedSchema`; close the store and surface an actionable persistence alert.
- Non-finite/negative/too-short imported segment -> `invalidSegment`; do not mutate SQLite or in-memory segments.
- Unsupported export envelope version/format -> `unsupportedImportFormat`.
- SQLite prepare/bind/step/commit failure -> roll back the transaction, log a credential-free warning, keep playback usable, and surface the error through `PlayerCore`.
- Corrupt or unmatched legacy sidecar -> leave it untouched and unassigned.

### 5. Good/Base/Bad Cases

- Good: Two signed URLs for the same Emby server/item resolve to one `external_id`, even if their query parameters and display names differ.
- Base: A local file uses its filename and an `external_id` of `NULL`.
- Good: Two Emby item IDs with the same filename create separate video rows.
- Bad: Using `stream.mp4?api_key=...`, its full URL, or its MD5 as `display_name`, `normalized_name`, or `external_id`.
- Bad: Making `normalized_name` globally unique, which aliases distinct external items with equal filenames.

### 6. Tests Required

- Identity: POSIX/local filename, Windows source path, unsafe signed title fallback, generic stream rejection, and distinct external IDs with equal names.
- Store: replace/load across reopen, clear, different-item isolation, transactional legacy merge, near-duplicate removal, sort order, and migration-marker non-resurrection.
- Import/export: versioned round trip, legacy payload, invalid segment rejection, and absence of URL/API/external-ID fields.
- Integration: `node --check` the userscript and build the IINA scheme.

### 7. Wrong vs Correct

#### Wrong

```swift
let identity = playbackURL.absoluteString
let key = identity.md5
```

#### Correct

```swift
guard let identity = MultiLoopVideoIdentity.resolve(
  url: playbackURL,
  externalMetadata: MultiLoopExternalMetadata(title: filename, mediaID: embyItemID)) else { return }
try MultiLoopStore.shared.replace(segments, identity: identity)
```

## Preferences

- Use `iina/Preference.swift` as the source of truth for app preferences.
- Add new preference keys to `Preference.Key` as `static let` values, grouped with related settings. Existing examples include playback keys such as `.alwaysOpenInNewWindow`, UI keys such as `.themeMaterial`, network keys such as `.ytdlEnabled`, and advanced keys such as `.enableLogging`.
- Read and write preferences through `Preference.bool(for:)`, `Preference.integer(for:)`, `Preference.enum(for:)`, and `Preference.set(_:for:)` rather than direct string literals in feature code.
- UI controllers commonly cache preference values and observe `UserDefaults` changes. `iina/PlayerWindowController.swift` keeps `observedPrefKeys` and updates cached values in `observeValue(forKeyPath:of:change:context:)`.

## File-backed state

- Feature-specific file state should live beside existing app state locations and use `URL`/`FileManager` APIs.
- Use atomic writes for small JSON persistence when matching current patterns. `iina/MultiLoop.swift` encodes `MultiLoopPersistedState` with `JSONEncoder` and writes via `data.write(to: fileURL, options: [.atomic])`.
- Decode failures should not crash playback. `MultiLoopStore.load(watchLaterKey:)` catches decode/read errors, logs a warning, and returns `nil`.
- Delete optional persisted feature state with tolerant cleanup when the feature state can be rebuilt. `MultiLoopStore.delete(watchLaterKey:)` uses `try? FileManager.default.removeItem(at:)`.

## Watch-later and playback-derived keys

- Playback-specific persisted state may key off `player.info.watchLaterKey` when it should follow the media item. `MultiLoopController.loadIfAvailable()`, `save()`, and `clearAll(deleteFromDisk:)` all guard on this key.
- Do not store playback-derived state before the key exists; existing code uses `guard let key = player.info.watchLaterKey else { return }`.

## Vendored dependency state

- `deps/include/` headers must match the dylibs copied to `deps/lib/`. README warns against mixing header and library versions.
- Use `./other/download_libs.sh` for the precompiled dependency path.
- When manually updating mpv/FFmpeg, copy headers into `deps/include/` and use `other/change_lib_dependencies.rb` to populate `deps/lib/` and adjust install names.

## Anti-patterns

- Do not introduce an ORM, server database, or network-backed persistence for app settings; the current app is local-first.
- Do not add another SQLite store casually. The multi-loop database is a feature-scoped exception with explicit schema/version/migration tests.
- Do not scatter preference string literals throughout controllers when a `Preference.Key` exists or should be added.
- Do not treat generated mpv binding files as editable data stores. Regenerate `MPVCommand`, `MPVOption`, and `MPVProperty` with `other/parse_doc.rb`.
