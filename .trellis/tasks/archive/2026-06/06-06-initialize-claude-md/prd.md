# Initialize CLAUDE.md

## Goal

Create a concise `CLAUDE.md` that future Claude Code sessions can use to build, test, and navigate this IINA fork quickly without duplicating generic guidance.

## What I already know

* The user invoked `/init` and requested a repository analysis plus `CLAUDE.md` creation.
* There is no existing `CLAUDE.md` at the repository root.
* Existing repo guidance is in `AGENTS.md` files at the root and package directories.
* This is a macOS IINA fork focused on multi-segment loop support.
* The project builds through `iina.xcodeproj` with schemes `iina`, `iina-cli`, `iina-plugin`, and `OpenInIINA`.
* README documents dependency setup via `./other/download_libs.sh` and manual mpv rebuild/regeneration workflows.
* No top-level test directories or explicit test bundles were found in a shallow test-file scan.

## Requirements

* Prefix `CLAUDE.md` exactly as requested by `/init`.
* Include common build/setup/test commands that are supported by current repo metadata.
* Include high-level architecture and module boundaries derived from README, CONTRIBUTING, and `AGENTS.md` files.
* Include important repo-specific rules from existing `AGENTS.md` and Cursor/Trellis context where relevant.
* Avoid generic development advice and avoid inventing unsupported commands.

## Acceptance Criteria

* [ ] Root `CLAUDE.md` exists and starts with the required heading and description.
* [ ] Commands include dependency setup and Xcode build/list/test/analyze examples for known schemes.
* [ ] Architecture section summarizes the main app, playback boundaries, plugin runtime, CLIs/extensions, configs, deps, and tooling.
* [ ] Guidance notes generated mpv files, localization scope, URL scheme coupling, and avoiding spurious `.xib`/`project.pbxproj` edits.
* [ ] The file is concise and non-duplicative.

## Definition of Done

* `CLAUDE.md` written.
* Basic verification performed by inspecting git diff.

## Out of Scope

* Changing build configuration, source code, tests, or Trellis-generated files beyond this task PRD.
* Adding new test infrastructure.
* Documenting every file or component that can be discovered by browsing the tree.

## Technical Notes

* Read `README.md`, `CONTRIBUTING.md`, root `AGENTS.md`, and package `AGENTS.md` files under `iina/`, `iina-cli/`, `iina-plugin/`, `browser/`, `OpenInIINA/`, `Configs/`, `deps/`, and `other/`.
* `xcodebuild -list -project iina.xcodeproj` resolved package dependencies and listed project schemes/targets.
* The iina scheme has an empty auto-created test action, so test commands should be framed as build/test actions only, not as claims of a full test suite.
