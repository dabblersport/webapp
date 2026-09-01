---
name: dart-fixed-sql-migration-not-applied
description: A two-commit ticket (Dart migration + SQL migration) can have its Dart half fully fixed and re-reviewed while the SQL half — the actual fix — was never applied to production; check list_migrations and re-run the ticket's own live probe, don't infer from Jira comments.
metadata:
  type: feedback
---

**Found in KAN-87** (2026-08-31, second re-review). The ticket's whole point was a live
security leak: `v_game_card` exposed a raw `auth.users` UUID to `anon`. Fix was scoped as two
sequenced commits — Dart call-site migration, then a `CREATE OR REPLACE VIEW` dropping the
column — with the SQL commit explicitly gated on the Dart commit being confirmed live first.

The Dart side went through two rounds of rework (a field-repurposing regression, then a T-041
follow-on ruling) and was fully fixed by the second re-review. But **nobody ever applied the
SQL migration**. The file existed (`supabase/migrations/20260830...kan87...sql`), was reviewed,
and every Jira comment from that point on talked only about the Dart side — the actual
column-drop was silently dropped from the conversation once its precondition (Dart live) was
satisfied. `docs/SCHEMA.md` itself said "not yet applied" the whole time, but nobody read that
as still-blocking because the ticket kept getting re-reviewed on the Dart regression alone.

**Why:** A ticket with a sequenced two-commit design accumulates review attention on whichever
half most recently had a bug. Once that half is clean, it's easy to mistake "the part I keep
re-checking is now fine" for "the ticket is done" — the other, quieter half can sail through
un-checked for cycles because nothing about the surface conversation (comments, re-review
verdicts) is about it anymore.

**How to apply:** for any ticket whose acceptance criteria include a live-state check that only
a database/production probe can confirm (not a `grep`, not `flutter analyze`) — re-run that
exact probe yourself, and cross-check `mcp__supabase__list_migrations` for the migration file
name, every single time you review the ticket, even on a second or third pass that's ostensibly
"just re-checking the regression." Do not let a satisfied Dart-side sub-criterion stand in for
the SQL-side sub-criterion just because the more recent conversation was about the former. See
[[sql-verified-app-not]] for the inverse failure mode (SQL checked, app not) — this is the same
lesson from the other direction: one side's proof is never the other side's proof.
