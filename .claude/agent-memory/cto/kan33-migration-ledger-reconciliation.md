---
name: kan33-migration-ledger-reconciliation
description: KAN-33 ledger-vs-repo reconciliation (2026-08-29) — 244/43/36/7 with the commands; the CLI cannot relocate its migrations dir; add_post_theme_id is unapplied
metadata:
  type: project
---

KAN-33 was ruled by `T-032` (adopt `supabase/migrations/`, baseline is the work) and amended by
`T-033`. Reconciliation measured 2026-08-29.

**Why option B was never real.** The Supabase CLI has **no key to relocate the migrations
directory** — it is hardcoded to `supabase/migrations`. `[db.migrations]` accepts only `enabled`
and `schema_paths`, and `schema_paths` is glob input for *declarative schema* files, not
migrations. `T-032` rejected option B on the weaker ground that no `config.toml` exists. Command
that settles it:
```
cd $(mktemp -d) && supabase init && grep -nE 'migration|path' supabase/config.toml
```

**The numbers, name-exact.** Ledger **244** · repo files **43** · matched **36** · repo files with
no ledger row **7** · ledger rows with no file **208**. Note 192 ledger rows predate `20260627`
and 52 are at or after it — so even the "recent era" has 17 rows with no repo file. Commands:
```sql
select count(*), min(version), max(version) from supabase_migrations.schema_migrations;
select version, name from supabase_migrations.schema_migrations order by version;
```
```
ls supabase/schema/migrations/*.sql | xargs -n1 basename | sed 's/\.sql$//' | sort
```
`backend-owner`'s "~40 matched" was 36. `add_select_policies_game_roster_and_waitlist` matches an
**older** row (`20260521203824`) — comparing only the `>= 20260627` slice undercounts by one.

**The live finding: `add_post_theme_id_and_seed_themes.sql` was never applied.** `public.posts`
exists, `public.post_themes` exists, **`posts.theme_id` does not**, and there is no ledger row.
A baseline is a dump of production, so a baseline cannot subsume it — `T-032` step 4's "effects
subsumed by the baseline" is false for this file. Open product question for the PO: is
`posts.theme_id` wanted, or is this abandoned work?

**Standing rule from `T-033`:** nothing enters `supabase/migrations/` with a version not already
in the ledger, except the baseline — a file there with a fresh timestamp is one the next
`db push` runs against production.

**The generalisable trap** (same family as [[verification-lessons]] and
[[cto-own-ruling-corrections]]): a repo filename is not evidence a migration ran, and a ledger row
is not evidence a file exists. Resolve both directions against the live catalogue — check the
*object*, not the name. Four of the 7 unmatched files were applied under names that never reached
the ledger; one was not applied at all. Only querying `pg_proc` / `information_schema.columns`
separated them.

Related: [[kan67-migration-facts]], [[g002-bypass-2026-08-29]].
