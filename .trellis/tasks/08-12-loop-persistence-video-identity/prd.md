# Persist loop records and unify video identity

## Goal

Make multi-loop records durable and reliably associated with a human-readable video identity, including videos launched from Emby through the user's browser script. Let users export one video's loop records and import them for another video when the two sources represent the same content under different names.

## User Value

- Loop records survive application restarts and are not silently lost.
- Emby streams are identified by a video filename or title instead of a signed `stream.mp4?api_key=...` URL.
- Loop records can be transferred manually between differently named copies of the same video.

## Confirmed Facts

- The existing multi-loop feature sometimes loses saved loop records.
- The user launches Emby videos in IINA with `/Users/chuyizhen/Downloads/embytest-1.1.4-mac-mpv-new-instance.user.js`.
- Those launches currently expose a long stream URL such as `stream.mp4?api_key=...` as the IINA window title/video label.
- The requested storage should use a lightweight embedded database.
- Import and export must each be accessible through a visible UI button.
- Existing persistence is one JSON sidecar per `watchLaterKey` in IINA's watch-later directory; the key is the MD5 of mpv's raw playback path.
- For network playback, that raw path contains query parameters. The userscript adds both the Emby API key and a newly generated statistics-session value, so the current key can change between launches and make saved records appear lost.
- The userscript already obtains the source filename from `mediaSource.Path` as `mediaInfo.intent.title`, and also has the Emby display title in `mediaInfo.itemInfo.Name`.
- The userscript currently sends only `url` and `new_window` to `iina://weblink`; it does not send either available title.
- IINA's URL scheme already accepts `mpv_*` options, and mpv/IINA support `force-media-title`; IINA uses mpv's media title for a network window title.
- The repository currently has no application database or ORM.
- A read-only audit of the user's current Application Support data found 111 legacy multi-loop sidecars. Their JSON payload contains only `segments` (`start`/`end`); it contains no URL, title, path, or Emby ID.
- IINA's separate `history.plist` retains historical playback URLs and can be correlated by recomputing the raw URL MD5 used in legacy sidecar filenames.
- In the current data, 71 of 111 sidecars can be correlated to playback-history URLs. Of those, 36 sidecars map to Emby URLs representing 35 distinct Emby item IDs. The other 40 sidecars have no reliable playback-history match.

## Requirements

- Persist loop records in a lightweight embedded database rather than relying only on the current fragile storage mechanism.
- Associate loop records with a stable, human-readable video identity.
- New database records must never use the full playback URL, a signed stream URL, or a hash derived from that full URL as the video identity.
- Extend or integrate with the Emby userscript so it passes the best available video filename/title to IINA.
- Never use a signed stream URL or its query parameters as the user-visible video label or exported identity.
- Provide loop export for the current video.
- Provide loop import for the current video so records from an equivalent, differently named video can be applied.
- Import replaces the current video's complete loop set; it does not merge records.
- If the current video has no loop records, import proceeds directly. If it already has records, require confirmation before replacement.
- Preserve compatibility for ordinary local-file playback as well as browser-launched streams.
- Define migration/compatibility behavior for loop records saved by the current implementation.
- During legacy migration, use playback history only as a local correlation index: match sidecar hash to historical URL, extract the non-secret Emby item ID/path identity, and associate it with the human-readable label supplied by a new launch. Do not persist the historical signed URL into the new database.
- When multiple legacy sidecars map to the same Emby item, merge all distinct normalized segments and sort them by start time. Preserve the legacy files so the migration remains recoverable.

## Acceptance Criteria

- [ ] Creating, editing, sorting, and deleting loop records is reflected durably in the database.
- [ ] Relaunching IINA and reopening the same video restores its loop records.
- [ ] Opening an Emby stream through the userscript shows and stores a human-readable filename/title, not `stream.mp4?...` or an API key-bearing URL.
- [ ] Neither the database video identity nor exported metadata contains the Emby API key, statistics-session parameter, or full signed stream URL.
- [ ] If a source filename is unavailable, the userscript/IINA falls back to the Emby item title; if both are unavailable, it uses a short `Emby-<item-id>` label and never the stream URL.
- [ ] Local files continue to resolve to an appropriate human-readable identity.
- [ ] Export produces a portable representation of all loop records for the selected/current video.
- [ ] Import can apply exported loop records to another selected/current video with a different identity.
- [ ] Import into a video with no loop records replaces the empty set without an unnecessary conflict prompt.
- [ ] Import into a video with existing loop records asks for confirmation before replacing the complete set.
- [ ] Cancelling the replacement confirmation leaves existing loop records unchanged.
- [ ] Import and export are available from explicit UI buttons and report success or actionable errors.
- [ ] Existing loop records are retained or migrated according to an explicitly documented compatibility rule.
- [ ] Recoverable legacy Emby sidecars are associated through playback-history URL hashes and Emby item IDs without storing API keys or historical signed URLs in SQLite.
- [ ] Multiple legacy sidecars for one Emby item are merged, duplicate normalized segments are removed, and the result is sorted by start time.
- [ ] Legacy sidecars are not deleted by automatic migration.
- [ ] Legacy sidecars with no trustworthy history match remain untouched rather than being guessed onto the wrong video.
- [ ] Automated tests cover database persistence, video identity normalization, and import/export validation where practical.

## Out of Scope (Initial)

- Automatic content fingerprinting or automatic detection that two differently named videos are identical.
- Cloud synchronization of loop records.

## Open Questions

- None currently blocking planning.

## Evidence-Based Defaults (Pending Review)

- Use the source filename from `mediaSource.Path` as the Emby identity/display label, with `itemInfo.Name` as fallback when the path has no usable filename.
- Pass that label explicitly from the userscript to IINA and apply it as the network media/window title.
- Use system SQLite as the embedded database, without adding an ORM or network service.
- Use a normalized human-readable label as the database identity. Resolution order for the Emby script is source filename, Emby item title, then `Emby-<item-id>`; raw URLs and raw-URL hashes are forbidden fallbacks.
- Import uses replace semantics; confirmation is only required when the target already contains loop records.
- Recover legacy records by correlating sidecar hashes with IINA playback-history URLs, then matching the extracted Emby item ID to the current script-provided item ID/title. Never attempt to reverse MD5 directly and never copy the signed URL into SQLite.
- Merge all distinct segments from sidecars mapped to the same Emby item and sort by start time; keep source sidecars unchanged for rollback.
- Sidecars without a history correlation cannot be automatically identified; preserve them on disk for manual legacy import/recovery rather than deleting them.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
