# OSC Loop Management Entry

## Goal

Make the multi-loop management panel easy to reach from the bottom playback controls (OSC), because the current entry — Quick Settings sidebar → 4th "Loop" tab — is too buried / cumbersome to access.

## What I already know (verified in code)

* **Current loop management entry**: A programmatic "Loop" tab inside the Quick Settings sidebar.
  * `QuickSettingViewController.TabViewType` = `[.video, .audio, .sub, .loop]` (`iina/QuickSettingViewController.swift:41`).
  * `setupLoopTab()` adds the tab button + hosts `MultiLoopViewController` (`QuickSettingViewController.swift:552`, `:574`).
  * To reach it today: open Quick Settings sidebar → click the Loop tab. (This is the "繁杂" path the user wants to replace.)
* **The "暂停/停用" button** (`enforcementToggleButton`) lives at the **bottom of the Loop sidebar panel**, NOT in the OSC bottom bar (`iina/MultiLoopViewController.swift:17`, `:80-92`, `:138-148`). It toggles `player.multiLoop.enforcementEnabled`.
* **OSC bottom bar toolbar buttons** are a customizable set:
  * `Preference.ToolBarButton` enum: `settings, playlist, pip, fullScreen, musicMode, subTrack, screenshot, plugins` (`iina/Preference.swift:721`). Each has `image()` (SF Symbol + fallback) and `description()` (localized `osc_toolbar.<key>` tooltip).
  * User picks which appear via `.controlBarToolbarButtons` pref (default: plugins, pip, playlist, settings — `Preference.swift:839`).
  * `setupOSCToolbarButtons(_:)` builds each button, sets `tag = rawValue`, action `toolBarButtonAction(_:)`, adds to `fragToolbarView` `.trailing` (`MainWindowController.swift:738`).
  * `toolBarButtonAction(_:)` dispatches by tag: `.settings → showSettingsSidebar()`, `.playlist → showPlaylistSidebar()`, etc. (`MainWindowController.swift:3276`).
  * `showSettingsSidebar(tab: .loop)` already exists and can open the Loop panel directly (`MainWindowController.swift:3170`).
* **CONFIRMED**: There is currently **no loop-related button anywhere in the OSC bottom bar.**

## Assumptions (temporary)

* The cleanest IINA-native solution is a **new OSC toolbar button** (a new `ToolBarButton` case) whose action opens the Loop panel via `showSettingsSidebar(tab: .loop)`, mirroring `.settings`/`.playlist`.
* User-visible strings go only in `iina/Base.lproj` and `iina/en.lproj`.

## Decisions (resolved with user)

* **Placement**: Put BOTH loop controls in the OSC bottom toolbar — an enforcement **toggle** (暂停/启用) button, and a **management entry** button to its right.
* **Old entry**: **Remove** the Quick Settings "Loop" tab. The OSC becomes the only entry.
* **Management panel presentation**: clicking the management-entry button opens an **NSPopover** anchored to that button, hosting the segment-management UI (decoupled from Quick Settings — a true "migration").

## Defaults adopted (stated for veto)

* The two new buttons are standard **customizable** `ToolBarButton` cases, added to the default `.controlBarToolbarButtons` order as `... toggle, manage ...` (manage to the right of toggle). User can rearrange via OSC customization like any other toolbar button.
* The enforcement toggle is **removed from the popover panel** (it now lives in the OSC), so the popover focuses on sort + segment list + drag-reorder + delete.
* Toggle button reflects enabled/disabled visually using **the same icon with a tint/dim swap** (enabled = normal tint, disabled = dimmed/secondary), and refreshes on toggle + media change.

## Requirements (evolving)

* Add two OSC toolbar controls: a multi-loop **enforcement toggle** and, to its right, a **management entry** button.
* The management entry opens an NSPopover anchored to the button, hosting the segment-management UI (sort + table + drag-reorder + delete).
* The enforcement toggle toggles `player.multiLoop.enforcementEnabled` and reflects state visually; it stays in sync on toggle and media change.
* Remove the Quick Settings "Loop" tab and re-route the multi-loop refresh hook (`reloadLoopTab()`) to refresh the OSC toggle + open popover.
* New buttons appear by default and are listed in the OSC customization sheet.
* Localize new user-visible text in Base + English only.
* Route playback behavior through `PlayerCore`; window/OSC logic in `MainWindowController`; no direct mpv calls.

## Acceptance Criteria (evolving)

* [ ] OSC bottom toolbar shows a loop enforcement toggle and a management-entry button (manage to the right of toggle) by default.
* [ ] Clicking the management entry opens a popover with the segment list, sort, drag-reorder, and delete — all working as before.
* [ ] Clicking the toggle enables/disables enforcement and the button's appearance updates; state persists correctly across media changes.
* [ ] Quick Settings no longer shows a "Loop" tab; remaining tabs (Video/Audio/Subtitle) work normally.
* [ ] Multi-loop mutations (add/remove/sort/reorder/undo) refresh the OSC toggle and the open popover.
* [ ] New buttons appear in the OSC customization preferences and can be added/removed/reordered.
* [ ] New strings localized in Base/en only; no spurious XIB / project.pbxproj churn.

## Technical Approach

1. **`Preference.swift`** — add `ToolBarButton` cases `.multiLoopToggle` + `.multiLoopManage`: `image()` (SF Symbol + fallback), `description()` (localized `osc_toolbar.*`); append both to default `.controlBarToolbarButtons` (toggle then manage).
2. **`PrefOSCToolbarSettingsSheetController.swift:37`** — add both cases to `allButtonTypes` so they appear in the OSC customization sheet.
3. **`MainWindowController.swift`** — in `toolBarButtonAction(_:)`: `.multiLoopToggle` flips `player.multiLoopSetEnforcementEnabled(...)` + refresh; `.multiLoopManage` shows an `NSPopover` anchored to `sender` hosting a `MultiLoopViewController`. Add a `refreshMultiLoopOSC()` that finds the toggle button in `fragToolbarView` (by tag) to update icon/state and reloads the popover content if shown.
4. **`QuickSettingViewController.swift`** — remove the Loop tab: `setupLoopTab()` call (`:235`), `loopTabBtn`/`multiLoopVC` props, `.loop` in `TabViewType` (arrays `:48`, tags `:60/:71`, title `:80`, `allBtns :593`, `switchToTab :616`), and `reloadLoopTab()`.
5. **`PlayerCore.swift`** — repoint the 7 `mainWindow.quickSettingView.reloadLoopTab()` calls to `mainWindow.refreshMultiLoopOSC()` (guarded for nil window). (Leave A-B-loop `syncUI(.loop)` / `PlayerCore.swift:2681` untouched — different `.loop`.)
6. **`MultiLoopViewController.swift`** — set a `preferredContentSize` for popover use; remove the `enforcementToggleButton` (now in OSC) and its constraints; keep sort + table + empty state.
7. **Localization** — add `osc_toolbar.multiloop_toggle` / `osc_toolbar.multiloop_manage` (+ any tooltip/state strings) to `Base.lproj` + `en.lproj` only.
8. **Verify** — `xcodebuild ... -scheme iina build`; manual UI checks per Acceptance Criteria.

## Implementation Plan (small steps)

* **Step 1**: ToolBarButton cases + defaults + customization sheet + localized strings (scaffolding, compiles, buttons appear but manage popover stubbed).
* **Step 2**: Wire actions — toggle behavior + popover host + `refreshMultiLoopOSC()` + repoint refresh hook.
* **Step 3**: Remove Quick Settings Loop tab; adapt `MultiLoopViewController` for popover (drop in-panel toggle, set content size); cleanup + verify.

## Definition of Done

* Targeted build/compile check where dependencies are available; manual verification steps for AppKit UI.
* Code follows `.trellis/spec/frontend` + `.trellis/spec/backend` guidance.
* Rollback is simple (localized to OSC toolbar + multi-loop UI plumbing).

## Out of Scope (explicit)

* Changing multi-loop enforcement / sequence / A-B loop semantics.
* Adding new keyboard shortcuts unless requested.
* Editing non-Base/non-English localizations.

## Technical Notes

* Key files: `iina/Preference.swift` (ToolBarButton enum + defaults), `iina/OSCToolbarButton.swift` (styling), `iina/MainWindowController.swift` (`setupOSCToolbarButtons`, `toolBarButtonAction`, `showSettingsSidebar`), `iina/QuickSettingViewController.swift` (Loop tab), `iina/MultiLoopViewController.swift` (panel content + disable toggle).
* Note: also check `PrefOSCToolbarSettingsSheetController.swift` / `PrefOSCToolbarDraggingItemViewController.swift` / `PrefUIViewController.swift` — they enumerate available toolbar buttons for the OSC customization UI, so a new case must be wired there too.

## Implementation Outcome

**Status**: Implemented on `develop`; `xcodebuild -scheme iina -configuration Debug` → BUILD SUCCEEDED (×3). No XIB/pbxproj churn (8 files: 6 Swift + 2 strings).

**Changes**: `Preference.swift` (+`multiLoopToggle`/`multiLoopManage` cases, image/description/default order), `PrefOSCToolbarSettingsSheetController.swift` (customization list), `MainWindowController.swift` (toggle action, `showMultiLoopPanel` popover, `refreshMultiLoopUI`, build-time tint), `PlayerCore.swift` (7 refresh calls repointed to `refreshMultiLoopUI`), `QuickSettingViewController.swift` (Loop tab + `reloadLoopTab` removed), `MultiLoopViewController.swift` (popover-ready, in-panel enforcement toggle removed, `preferredContentSize` set), `Base/en` strings (+2 osc_toolbar keys, −5 dead keys).

**⚠️ Existing-install caveat**: new buttons appear by default ONLY when `.controlBarToolbarButtons` is at its default. A previously-saved toolbar customization overrides the default, so they must be added via Settings → UI → OSC toolbar customization (or reset).

**Manual verification** (AppKit UI; no automated test feasible):
- [ ] Default OSC shows loop toggle + manage button (manage to the right).
- [ ] Manage button toggles a popover with segment list / sort / drag / delete.
- [ ] Toggle flips enforcement; icon dims when disabled; OSD shows enabled/disabled.
- [ ] Add/remove/sort/reorder segment updates the open popover + toggle tint.
- [ ] Quick Settings shows only Video/Audio/Subtitle (no Loop tab).
- [ ] Loop buttons add/remove/reorder in OSC customization preferences.
