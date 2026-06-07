# Temporary Multi-Loop Disable Button

## Goal

Add a playback-control affordance that temporarily disables multi-segment loop enforcement without deleting configured loop segments, so normal playback can pass through any saved loop segment instead of being pulled back into that segment.

## What I already know

* User request: add a new feature on playback controls: a button to temporarily close/disable all loop nodes.
* Desired behavior: after clicking, loop playback is temporarily disabled, preventing natural playback from entering any loop segment and getting trapped.
* User explicitly requested working in a worktree first; current session is in `worktree-loop-disable-button-feat`.
* Multi-loop runtime state lives in `iina/MultiLoop.swift` via `MultiLoopController.segments`, `pendingStart`, and `sequenceModeEnabled`.
* Loop enforcement happens in `MultiLoopController.handleTimePosUpdate(_:)`, which seeks back to segment starts when playback crosses segment ends.
* `PlayerCore` exposes multi-loop operations and refreshes UI/slider markers in `iina/PlayerCore.swift`.
* Existing Loop sidebar content is programmatic in `iina/MultiLoopViewController.swift`, hosted by `iina/QuickSettingViewController.swift`.
* Existing multi-loop commands are defined in `iina/IINACommand.swift` and dispatched in `iina/PlayerWindowController.swift`.
* User-visible strings should be added only to `iina/Base.lproj/Localizable.strings` and `iina/en.lproj/Localizable.strings`.

## Assumptions (temporary)

* “暂时关闭” means a UI toggle: disable enforcement while keeping loop segments visible and persisted, and re-enable enforcement when toggled back on.
* Disabled state should be runtime-only by default, not written into watch-later multi-loop segment storage.
* Markers/rows should remain visible while disabled so users can see which loop segments are being bypassed.
* This should not delete segments, clear pending start, or change segment order.

## Open Questions

* MVP scope: should the button be a persistent toggle until clicked again, or a one-shot bypass that automatically re-enables later?

## Requirements (evolving)

* Add a control to temporarily disable all multi-loop segment enforcement without deleting loop segments.
* When disabled, natural playback through any configured multi-loop segment should not seek back to that segment start.
* Preserve existing loop segment data, pending-start state, marker display, sidebar rows, delete behavior, and sequence ordering.
* Provide localized UI text in Base and English only.
* Route playback behavior through `PlayerCore`; UI should not talk to mpv directly.

## Acceptance Criteria (evolving)

* [ ] Given existing multi-loop segments, clicking the new control disables multi-loop enforcement without deleting segments.
* [ ] Given playback naturally enters and crosses a configured segment while disabled, playback continues past the segment end instead of seeking to the segment start.
* [ ] Given multi-loop enforcement is re-enabled, existing segments enforce loop behavior again.
* [ ] Given loop segments exist while disabled, the Loop UI and slider markers still show the existing segments.
* [ ] Given a pending start point exists, toggling disable does not clear or convert the pending point.
* [ ] New user-visible strings are localized in `Base.lproj` and `en.lproj` only.

## Definition of Done

* Tests added/updated where practical; for AppKit-only UI, provide manual verification steps if automated tests are not feasible.
* Targeted build or compile check run when dependencies are available.
* No unrelated XIB or project file changes.
* Rollback is straightforward because the feature is localized to multi-loop controller/UI plumbing.

## Out of Scope (explicit)

* Deleting, sorting, or otherwise mutating existing loop segments.
* Changing regular mpv A-B loop, playlist loop, or file loop semantics.
* Persisting disabled state across app launches unless explicitly requested.
* Adding a keyboard shortcut/command unless explicitly requested.
* Editing non-Base/non-English localizations.

## Technical Approach (draft)

* Add runtime enabled/disabled state to `MultiLoopController`, likely defaulting to enabled for each loaded media item.
* Gate `handleTimePosUpdate(_:)` so it observes markers/segments but does not seek when multi-loop enforcement is disabled.
* Add `PlayerCore` wrapper methods to toggle/query state and refresh the relevant UI.
* Add a UI button in the appropriate playback-control surface once placement is confirmed; if added programmatically, avoid XIB churn.
* Add localized label/tooltip/accessibility strings.

## Decision (ADR-lite)

**Context**: Multi-loop segments are useful for intentional loop playback, but normal playback can unintentionally enter a saved segment and get trapped.

**Decision**: Pending user confirmation, implement a runtime toggle that disables enforcement while retaining segment data and marker visibility.

**Consequences**: Users can safely bypass loops without data loss. The state is simple and reversible, but UI must make disabled/enabled state clear.

## Technical Notes

* Relevant source files inspected:
  * `iina/MultiLoop.swift` — segment storage, persistence, marker times, and enforcement seek logic.
  * `iina/PlayerCore.swift` — multi-loop operation wrappers and UI refresh path.
  * `iina/MultiLoopViewController.swift` — existing Loop sidebar UI and delete action pattern.
  * `iina/QuickSettingViewController.swift` — Loop tab creation and reload path.
  * `iina/PlayerWindowController.swift` — command dispatch for existing multi-loop commands.
  * `iina/Base.lproj/Localizable.strings` and `iina/en.lproj/Localizable.strings` — existing multi-loop strings.
* Relevant Trellis specs inspected:
  * `.trellis/spec/frontend/component-guidelines.md`
  * `.trellis/spec/frontend/quality-guidelines.md`
* App boundary: playback behavior should route through `PlayerCore`; random UI controllers should not call mpv directly.
