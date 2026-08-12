# Design: Loop persistence and video identity

## Scope and boundaries

This remains one integration task because persistence, identity resolution, legacy recovery, and import/export all operate on the same loop-set contract. Splitting them would require temporary duplicate storage paths and unstable intermediate behavior.

The implementation spans four boundaries:

1. Emby userscript resolves metadata and launches `iina://weblink`.
2. IINA URL-scheme handling passes non-secret media metadata into `PlayerCore`.
3. `MultiLoopController` reads and writes loop sets through an SQLite-backed store.
4. `MultiLoopViewController` imports and exports portable JSON through AppKit panels.

Playback enforcement and segment editing remain owned by `MultiLoopController`; UI code continues to call `PlayerCore` wrappers rather than mpv directly.

## Video identity contract

### Emby launch parameters

Extend the userscript's IINA URL with:

- `media_title`: human-readable label resolved in this order:
  1. basename of `mediaSource.Path`, accepting both `/` and `\\` separators;
  2. trimmed `itemInfo.Name`;
  3. `Emby-<itemInfo.Id>`.
- `media_id`: the non-secret Emby item ID.

The script must guard missing `Path`, `Name`, `MediaSources`, and selected source values. It must not substitute `stream.mp4`, the signed playback URL, the API key, or the statistics session ID for either field.

### IINA representation

Introduce a small value type representing the current media:

- `displayName`: exact user-visible filename/title.
- `normalizedName`: trimmed, Unicode-normalized, case-insensitive lookup form.
- `externalID`: optional stable alias. For Emby, namespace the item ID with the normalized server origin so equal numeric IDs on different servers do not collide. No query or fragment is retained.
- `sourceKind`: `local`, `emby`, or `network`.

`PlayerCore.openURLString` receives optional external metadata from `AppDelegate.parsePendingURL`. It is consumed by the next `fileStarted` event so it cannot leak into later playlist items. Ordinary local playback derives `displayName` from `lastPathComponent`. Generic network playback derives only a query-free path label and must never use a signed URL as its database identity.

Lookup order is:

1. stable `externalID` when present;
2. `normalizedName` for identities without an external ID;
3. no persistence when no safe non-URL identity can be produced.

An external identity never falls back to a same-named row belonging to another external item. This prevents two distinct Emby items with equal filenames from sharing loops accidentally.

The network window title and IINA media title helpers prefer the resolved `displayName`, ensuring the title bar shows the filename/title supplied by Emby.

## SQLite persistence

Use the system `SQLite3` module (verified available in the current SDK, SQLite 3.54.0). Do not add an ORM or bundled database dependency.

Database location:

`Application Support/com.colliderli.iina/multiloop.sqlite3`

Initial schema, created transactionally with `PRAGMA user_version = 1`:

```sql
CREATE TABLE videos (
  id INTEGER PRIMARY KEY,
  display_name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  external_id TEXT UNIQUE,
  source_kind TEXT NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL
);

CREATE INDEX videos_normalized_name_idx ON videos(normalized_name);

CREATE TABLE loop_segments (
  video_id INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL,
  start REAL NOT NULL,
  end REAL NOT NULL,
  PRIMARY KEY (video_id, ordinal)
);

CREATE TABLE legacy_imports (
  sidecar_hash TEXT PRIMARY KEY,
  video_id INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  imported_at REAL NOT NULL
);
```

Open one process-wide store with serialized access, foreign keys enabled, a busy timeout, and WAL journaling. Each replace/save operation uses a transaction: upsert video metadata, delete that video's segment rows, insert normalized segments in array order, then commit. Failures roll back, log a warning without credentials, and leave the controller's in-memory state usable.

Clearing loops deletes segment rows but keeps the video row and migration markers so legacy data does not reappear on the next open.

## Legacy recovery

Legacy sidecars are `<raw-mpv-path-md5>.iina-multiloop.json` in the watch-later directory and contain only segment times.

### Local files

For the current local file, try its exact existing `watchLaterKey` sidecar. If it has not been marked in `legacy_imports`, decode and import it.

### Emby streams

Use `HistoryController.shared.history` only in memory:

1. Select history entries whose query-free server/path identifies the same Emby item as the current `externalID`.
2. Recompute MD5 from each historical URL's `absoluteString`.
3. Load matching sidecars that are not already in `legacy_imports`.
4. Normalize all segments, merge them with any current database segments, deduplicate equal/near-equal `(start, end)` pairs, and sort by start then end.
5. Save the merged set and record all imported hashes in the same transaction.

Historical URLs, tokens, API keys, and statistics-session IDs are never logged or written to SQLite. Source sidecars remain untouched for rollback. Unmatched sidecars remain untouched and unassigned.

## Import/export contract

Export a UTF-8 JSON document with a stable versioned envelope:

```json
{
  "format": "iina-multiloop",
  "version": 1,
  "sourceVideoName": "FC2-3363866.mp4",
  "segments": [
    { "start": 12.5, "end": 20.0 }
  ]
}
```

Do not export `externalID`, URLs, hashes, API keys, or server details. The suggested filename is a filesystem-safe form of `<video-name>.iina-multiloop.json`.

Import accepts both the versioned envelope and the legacy `{ "segments": [...] }` payload. Validate that every time is finite and non-negative, normalize reversed endpoints, discard exact/near duplicates, reject segments shorter than the controller minimum, and preserve file order for a normal import.

Import always targets the currently playing video's resolved identity and ignores the exported source name for lookup. When the target has no segments, replace immediately. When it has segments, show a confirmation sheet; cancellation performs no database or in-memory mutation. Successful replacement updates SQLite, markers, mpv observation, the open popover, and a localized success message.

## UI

Keep the existing programmatic popover. Replace the single top-aligned sort button with a compact horizontal control row containing Import, Export, and Sort. Buttons have localized titles, tooltips, and accessibility labels. Export is disabled when there are no completed segments; Import is disabled when no safe current video identity exists.

Use `Utility.quickOpenPanel` and `Utility.quickSavePanel` with JSON file filtering. Use a sheet alert for replacement confirmation and invalid/read/write/database errors. Report successful import/export through localized OSD or an equivalent non-blocking status path.

## Compatibility and rollout

- Existing sidecars are read-only migration sources and are not deleted.
- The database becomes the only write target after upgrade.
- If database initialization fails, log and surface an actionable persistence error; do not silently fall back to the volatile raw-URL sidecar scheme.
- The external userscript is outside Git. Before changing it, create a timestamp-free `.bak` copy beside it, then update the installed file only after explicit filesystem approval. Validate it with `node --check`.
- Rollback consists of reverting IINA code and restoring the userscript backup. Legacy sidecars remain available throughout.

## Security and privacy

- Never use or store a full network playback URL as the new identity.
- Never persist or export query parameters, API keys, access tokens, session UUIDs, or historical signed URLs.
- Do not include signed URLs in diagnostic logs or user-facing errors.
- SQL uses bound parameters only.

## Validation strategy

- Build the IINA scheme in Debug.
- Validate schema creation and transactional replace/load/delete behavior with a temporary database or focused harness where practical.
- Exercise identity resolution for POSIX path, Windows path, Emby title fallback, item-ID fallback, and rejection of raw stream labels.
- Validate legacy correlation against local fixtures modeled on `history.plist` plus sidecar hashes, including multiple sidecars for one item and unmatched files.
- Validate new and legacy import JSON, malformed JSON, invalid times, cancellation, and replacement.
- Run `node --check` on the modified userscript.
- Manually launch an Emby item and verify the window title, database identity, restart restore, and import/export buttons.
