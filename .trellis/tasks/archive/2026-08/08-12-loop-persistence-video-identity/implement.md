# Implementation plan

## 1. Identity and URL-scheme plumbing

- [x] Add a focused media-identity value type/resolver near the multi-loop feature boundary.
- [x] Extend `AppDelegate.parsePendingURL` documentation and parsing for `media_title` and `media_id`.
- [x] Pass the metadata into the next `PlayerCore.openURLString`/`fileStarted` lifecycle without leaking it to later items.
- [x] Make network title helpers prefer the safe resolved display name.
- [x] Add focused resolver checks for filename, Emby title, `Emby-<id>`, Unicode normalization, and forbidden raw stream URL fallback.

Risk/rollback point: URL-scheme ordering and per-file metadata lifetime. Verify ordinary local playback and consecutive mixed local/Emby opens before continuing.

## 2. SQLite store

- [x] Add `multiloopDatabaseFile` to `AppData` and a `Utility` URL under Application Support.
- [x] Implement a system-SQLite store with schema versioning, serialized access, WAL, foreign keys, busy timeout, bound parameters, transactions, and redacted logging.
- [x] Implement resolve/upsert video, load segments, transactional replace, clear, and legacy-import marker operations.
- [x] Add the new Swift source to the IINA target/project if it is not kept in the existing feature file.
- [x] Change `MultiLoopController` to use the database as the sole write target and expose persistence failures to `PlayerCore`/UI.
- [x] Verify add, remove, reorder, sort, undo, clear, restart load, and two-player-window access.

Risk/rollback point: never delete legacy JSON; if schema/open fails, stop database writes and report the error rather than writing under raw URL hashes.

## 3. Legacy migration

- [x] Implement exact-key local sidecar migration.
- [x] Implement in-memory history correlation for Emby using query-free server/item identity and recomputed historical raw-URL MD5.
- [x] Merge all correlated sidecars, normalize, near-deduplicate, sort by start/end, and record imported hashes transactionally.
- [x] Ensure signed URLs never enter SQLite/log/error strings.
- [x] Preserve all sidecars and leave unmatched files unassigned.
- [x] Test fixtures for one sidecar, multiple sidecars for one item, duplicates, corrupt JSON, already-imported hashes, and no history match.

Risk/rollback point: migration is additive and sidecars stay intact; `legacy_imports` prevents resurrection after users clear loops.

## 4. Import/export and AppKit controls

- [x] Define versioned export DTO plus compatible legacy decoder and validation.
- [x] Add Import and Export buttons beside Sort in `MultiLoopViewController` with accessibility and enabled-state updates.
- [x] Use open/save panels and safe suggested filenames.
- [x] Route replacement through `PlayerCore`; confirm only when the target already has segments.
- [x] Refresh slider markers, observation, popover contents, and success/error feedback.
- [x] Add Base and English localization strings only.
- [x] Validate empty-target import path, replacement gate, malformed/legacy JSON, export round trip, and source-name metadata not changing target identity through code review and the focused harness.

## 5. Emby userscript

- [x] Create `/Users/chuyizhen/Downloads/embytest-1.1.4-mac-mpv-new-instance.user.js.bak` before modification.
- [x] Harden selected media-source lookup and implement the filename/title/item-ID fallback chain.
- [x] Append encoded `media_title` and `media_id` to the `iina://weblink` launch URL.
- [x] Keep API key/session values only inside the nested playback URL; never use them as metadata.
- [x] Run `node --check` and inspect the generated IINA URL with secrets redacted.

Risk/rollback point: the userscript is not tracked by this repository; retain the backup and report both paths in handoff.

## 6. Verification and review gate

- [x] Run `git diff --check` and review the complete diff for unrelated XIB/generated-file churn.
- [x] Run `xcodebuild -project iina.xcodeproj -scheme iina -configuration Debug build`.
- [x] Run the focused store/resolver/import validation harness added during implementation.
- [x] Run `node --check /Users/chuyizhen/Downloads/embytest-1.1.4-mac-mpv-new-instance.user.js`.
- [ ] Manual end-to-end: launch Emby video, verify title, create loops, restart/reopen, verify restore, export, import into a differently named video, verify replacement behavior. (Requires the user's signed-in Emby session.)
- [x] Inspect the SQLite schema contract and focused database rows; confirm no URL/query/token fields are present.
- [x] Re-run the local audit: 71/111 legacy sidecars map through history, including 36 sidecars for 35 Emby IDs; 40 remain untouched and unmatched.
- [x] Load and run `trellis-check`; fix all findings before completion.

## Expected files

- `iina/AppData.swift`
- `iina/Utility.swift`
- `iina/AppDelegate.swift`
- `iina/PlaybackInfo.swift` and/or `iina/PlayerCore.swift`
- `iina/MultiLoop.swift`
- `iina/MultiLoopViewController.swift`
- optional new `iina/MultiLoopStore.swift`
- `iina/Base.lproj/Localizable.strings`
- `iina/en.lproj/Localizable.strings`
- `iina.xcodeproj/project.pbxproj` only if a new source file is added
- `/Users/chuyizhen/Downloads/embytest-1.1.4-mac-mpv-new-instance.user.js` (external, backed up separately)
