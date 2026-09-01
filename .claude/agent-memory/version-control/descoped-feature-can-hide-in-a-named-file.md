---
name: descoped-feature-can-hide-in-a-named-file
description: A descoped feature's UI can land inside a file adjacent to (but not named as) a legitimate ticket's target file — check every modified file's full diff before staging, even ones not explicitly excluded
metadata:
  type: feedback
---

2026-08-31 sprint-2 checkpoint: the brief excluded `data_export_service.dart` and "the
Settings data-export entry point" (KAN-52/KAN-103, descoped per P-025 in
docs/DECISIONS.md) but did not name the specific screen file. While probing what
`flutter-feature-agent-11` touched for KAN-99, `account_management_screen.dart` looked
plausible (same settings/ directory) and was staged once, unvetted, alongside the real
KAN-99 file. Its diff turned out to be exactly the excluded entry point:
`_buildDataExportSection()` / `_requestDataExport()`, importing `DataExportService`.
Caught via `git diff --cached` before committing; `git reset` un-staged it cleanly.

**Why this matters:** "not in my explicit exclusion list" is not the same as "safe to
commit" — an excluded feature's *mechanism* file was named, but its *UI entry point* file
was not, and the two aren't in the same directory naming pattern you'd guess from the
ticket description alone.

**How to apply:** never `git add` a file on gut instinct about what an agent "probably
touched" — read its full diff first, every time, even for files that seem adjacent to or
part of an already-vetted ticket. Related: [[hunk-level-split-for-mixed-wip]].
