# loop-ui-auto-sort-button

## Goal

Add an auto-sort control to the Loop tab so users can reorder completed multi-loop segments by each segment's normalized start time in ascending order. This helps users recover a chronological playback order after creating segments out of order or manually dragging rows.

## What I already know

* User request: add a feature to the loop UI with an auto-sort button that sorts loop segments by start time from small to large.
* The Loop tab is programmatic in `iina/QuickSettingViewController.swift`, with content provided by `MultiLoopViewController`.
* Completed loop segments are stored in `MultiLoopController.segments` in `iina/MultiLoop.swift`.
* Existing manual reordering is implemented through `MultiLoopController.moveSegment(from:to:)`, exposed by `PlayerCore.multiLoopMoveSegment(from:to:)`, and triggered by `NSTableView` drag/drop in `MultiLoopViewController`.
* `MultiLoopSegment.normalized` already ensures start/end ordering, so sorting should use `segment.normalized.start` rather than raw `start`.
* Segment order affects sequence playback order (`startSequenceFromFirstSegment`, `handleTimePosUpdate`) and persisted watch-later state (`save()`), so auto-sort must update controller state and persist.
* UI strings should be localized only in `iina/Base.lproj/Localizable.strings` and `iina/en.lproj/Localizable.strings`.

## Assumptions (temporary)

* The button belongs inside the existing Loop tab content, near the segment table, not in the global Quick Settings tab bar.
* Sorting only applies to completed segments; a pending start point row remains pending and is not moved into the sorted segment list.
* If segments are already sorted, clicking the button should be a harmless no-op.
* Auto-sort should preserve existing behavior for manual drag/drop reordering.

## Open Questions

* MVP scope: should this task include only the requested current requirement, or also add a small robustness/UX enhancement such as disabling the button when sorting is not meaningful?

## Requirements (evolving)

* Add an auto-sort button to the Loop tab UI.
* Sort completed loop segments by normalized start time ascending.
* Persist the new order through the existing multi-loop persistence path.
* Refresh the Loop table and slider markers after sorting.
* Preserve pending-start behavior and manual drag/drop behavior.
* Localize any new user-visible text in Base and English only.

## Acceptance Criteria (evolving)

* [ ] Given completed segments are out of chronological order, clicking the Loop tab auto-sort button reorders rows by segment start time ascending.
* [ ] Given segment endpoints were created in reverse order, sorting uses the normalized lower endpoint as the start time.
* [ ] Given sequence mode is started after sorting, playback follows the newly sorted segment order.
* [ ] Given a pending start point exists, sorting completed segments does not clear or modify the pending point.
* [ ] Given segments are sorted, the new order is saved and restored through the existing watch-later multi-loop persistence.
* [ ] The button has localized title/tooltip/accessibility text as appropriate, with changes limited to Base/en localization files.
* [ ] Existing drag/drop reorder and delete behavior still works.

## Definition of Done (team quality bar)

* Tests added/updated where practical; for AppKit-only UI, provide manual verification steps if automated tests are not feasible.
* Targeted build or compile check run when dependencies are available.
* No unrelated XIB or project file changes.
* Docs/notes updated if behavior changes beyond the UI affordance.
* Rollback is straightforward because the feature is localized to multi-loop controller/UI plumbing.

## Out of Scope (explicit)

* Adding a keyboard shortcut or command for auto-sort unless explicitly requested.
* Changing loop creation semantics or automatically sorting every time a segment is added.
* Changing marker labels beyond the labels naturally following the displayed order.
* Editing non-Base/non-English localizations.

## Technical Approach (draft)

* Add a `sortSegmentsByStartTime()` method to `MultiLoopController` that normalizes for comparison, detects no-op order if needed, resets playback tracking state, saves, and updates time-position observation.
* Add a `PlayerCore.multiLoopSortSegmentsByStartTime()` wrapper that refreshes slider markers and Loop UI, similar to `multiLoopMoveSegment(from:to:)`.
* Add a programmatic sort button in `MultiLoopViewController.loadView()`, likely above the existing scroll view, wired to an `@objc` action.
* Add localized strings such as `multiloop.sort_by_start` / tooltip in `Base.lproj` and `en.lproj`.

## Decision (ADR-lite)

**Context**: Multi-loop segment order is user-editable and also controls sequence playback order. Users need a fast way to restore chronological order.

**Decision**: Pending user confirmation, implement explicit user-triggered sorting from the Loop tab, not automatic sorting on every segment creation.

**Consequences**: Users retain manual ordering power while getting a one-click chronological restore. The feature needs small UI plumbing and controller-level mutation/persistence.

## Technical Notes

* Relevant source files inspected:
  * `iina/MultiLoop.swift` — segment model, persistence, controller mutations, sequence playback order.
  * `iina/MultiLoopViewController.swift` — Loop tab table UI, delete button, drag/drop reordering.
  * `iina/QuickSettingViewController.swift` — programmatic Loop tab setup and reload hook.
  * `iina/PlayerCore.swift` around multi-loop wrapper methods.
  * `iina/Base.lproj/Localizable.strings` and `iina/en.lproj/Localizable.strings` around existing multi-loop strings.
* Relevant Trellis specs inspected:
  * `.trellis/spec/frontend/component-guidelines.md`
  * `.trellis/spec/frontend/quality-guidelines.md`
* App boundary: playback behavior should route through `PlayerCore`; UI should not mutate mpv directly.
