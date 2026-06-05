# Core Data and Persistence Guidelines

This project does not use a database or ORM. Persistent data is stored through macOS app mechanisms, files in Application Support-style locations, watch-later data, and mpv state.

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
- Do not scatter preference string literals throughout controllers when a `Preference.Key` exists or should be added.
- Do not treat generated mpv binding files as editable data stores. Regenerate `MPVCommand`, `MPVOption`, and `MPVProperty` with `other/parse_doc.rb`.
