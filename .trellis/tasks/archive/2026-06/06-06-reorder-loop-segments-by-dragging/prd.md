# Reorder Loop Segments by Dragging

## Goal

Allow users to reorder multi-loop segments in the Loop sidebar by dragging segment rows, so the sequence playback order can be arranged independently of creation order. Example: if segments are displayed as A, C, B by time/creation intent, the user can drag B above C so sequence playback becomes A, B, C.

## What I already know

* User wants each small segment in the Loop UI to support dragging for manual ordering.
* The Loop UI lives in `iina/MultiLoopViewController.swift` and is an AppKit `NSTableView` built programmatically.
* Multi-loop state lives in `iina/MultiLoop.swift`; `MultiLoopController.segments` is the source of truth for both row order and sequence playback order.
* Sequence playback uses `segments[nextIdx]` in `MultiLoopController.handleTimePosUpdate(_:)`, so changing array order changes playback order.
* Current UI supports deleting rows and clicking a row to seek to segment start.
* Pending start rows are shown after complete segments and are not complete reorderable segments.
* Project specs say feature logic should stay in `MultiLoopController`, UI actions should call small controller methods, and playback-facing UI should mutate via `PlayerCore`/feature controllers.

## Assumptions (temporary)

* Dragging should reorder only completed loop segments, not the pending “A: time → ...” row.
* Reordered segment order should persist through `MultiLoopStore.save`, because persisted state stores `segments` array order.
* Reordering should update the sidebar immediately and refresh slider markers, but marker drawing can continue to show markers at actual times rather than sequence order.
* Dragging should be implemented using standard `NSTableView` row drag/drop APIs, not a custom gesture layer.

## Open Questions

* None.

## Requirements (evolving)

* Users can drag completed segment rows in the Loop sidebar to reorder them.
* Dropping a row updates `MultiLoopController.segments` order and persists it.
* Sequence playback follows the reordered `segments` array order.
* If sequence playback is active during reorder, it should keep running and use the new order at the next segment boundary; implementation should reset internal sequence tracking to avoid stale indices.
* Pending start rows cannot be dragged or targeted as reorderable completed segments.
* Delete and row-click-to-seek behavior continue working after reorder.

## Acceptance Criteria (evolving)

* [ ] With at least two completed segments, dragging a row above/below another row changes the visible row order.
* [ ] Starting sequence playback after reorder plays segments in the visible order.
* [ ] Reordered order is saved and restored for the same watch-later key.
* [ ] Pending start row is not draggable and cannot be used as a completed-segment drop target.
* [ ] Deleting a segment after reorder deletes the row currently shown at that index.
* [ ] Clicking a segment after reorder seeks to that segment’s start.

## Definition of Done

* Code follows `.trellis/spec/backend` and `.trellis/spec/frontend` guidance.
* Relevant UI/model methods are added in the existing `MultiLoopController` / `PlayerCore` / `MultiLoopViewController` boundaries.
* Lightweight verification or Xcode build is run where practical; if skipped, report why.
* Docs/spec updates considered after implementation.

## Out of Scope

* Changing how loop points are created with keyboard shortcuts.
* Renaming point labels beyond what is necessary for row-order display.
* Adding complex timeline drag handles on the playback slider.
* Dragging the pending incomplete point row.

## Technical Notes

* Relevant files inspected: `iina/MultiLoop.swift`, `iina/MultiLoopViewController.swift`, `iina/PlayerCore.swift`, `.trellis/spec/frontend/component-guidelines.md`, `.trellis/spec/frontend/state-management.md`, `.trellis/spec/backend/directory-structure.md`.
* `MultiLoopController.removeSegment(at:)` already resets sequence tracking, saves, and updates mpv time-pos observation; a reorder method should likely follow the same state-reset/persist/update pattern.
* `PlayerCore.multiLoopRemoveSegment(at:)` wraps controller mutation with OSD/UI refresh; a new `multiLoopMoveSegment(from:to:)` wrapper can keep UI mutation routed through `PlayerCore`.
* `NSTableViewDataSource` supports row reordering via pasteboard registration, `pasteboardWriterForRow`, `validateDrop`, and `acceptDrop`.
