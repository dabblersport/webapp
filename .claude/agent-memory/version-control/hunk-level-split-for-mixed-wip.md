---
name: hunk-level-split-for-mixed-wip
description: A file can carry a ready ticket's fix AND unrelated in-flight WIP from another agent in the same diff — split at the hunk level, don't sweep the WIP in or skip the whole file
metadata:
  type: feedback
---

During the 2026-08-31 sprint-2 local-checkpoint commit (KAN-99/88/45/51/59/102/87/68),
several files named in the brief also carried changes NOT in the brief, made by other
agents working the same tree concurrently:

- `settings_screen.dart` (KAN-99 target) also had a `PersonaType.hoster` → `PersonaType.host`
  enum rename hunk.
- `supabase_config.dart` (needed for KAN-51's one new `rpcTrackEventFn` constant) also had
  the same `hosterTable`→`hostTable` rename plus unrelated new `postMediaTable` /
  `paymentIntentsTable` constants.
- `profile_screen.dart` had ONLY the unrelated hoster→host hunk — nothing from any ticket —
  so it was left untouched entirely.

**How this was handled:** extracted the exact wanted hunk(s) with `git diff -U5 -- <file>`,
built a minimal patch containing only the file header + the wanted hunk(s) (byte-exact,
python slicing of the diff lines rather than hand-typing — hand-typed patches drift and
`git apply` rejects them as corrupt), verified with `git apply --cached --check`, then
`git apply --cached` for real. This stages only the intended hunk; the rest of the file's
edits remain unstaged in the working tree, untouched.

**Why this matters:** the brief's own "don't sweep unrelated WIP into a release commit"
rule and [[shared-working-tree-staging-hazard]] both point at file-level staging as the
risk, but a single file can itself be the collision point when two agents edit different
regions of it. Skipping the whole file would have dropped KAN-99 and KAN-51; staging the
whole file would have shipped an in-progress persona rename (`hoster`→`host`) that wasn't
signed off as ready — it's clearly a multi-file, still-in-progress refactor (also touches
l10n files, persona_rules.dart, persona_label.dart, profile_screen.dart) and shouldn't ship
partially.

**How to apply:** whenever a brief names a file to commit, always check its full diff, not
just the region you expect — a clean single-purpose diff needs no splitting, but any
unexpected hunk means either the brief is wrong (ask) or you split. Never assume "the file
is in my list" means "commit the whole file."
