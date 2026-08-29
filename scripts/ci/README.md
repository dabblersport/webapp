# CI scripts

## `check_anon_allowlist.sh` (KAN-61, `docs/DECISIONS.md` T-002)

Runs in `.github/workflows/anon-allowlist-check.yml` on push to `Canary` and on PRs into
`main`. Queries `pg_class` for every `public` view `anon` can `SELECT` without
`security_invoker`, and fails the build if any such view is not on the allowlist in
`docs/SCHEMA.md` §2f.

**Requires a `SUPABASE_DB_URL` GitHub Actions secret** — a direct Postgres connection
string for `wtncuzcskpigqpmnxwws` (Project Settings → Database → Connection string). This
does **not exist yet** as of this ticket landing; only `SUPABASE_URL` /
`SUPABASE_ANON_KEY` / `SUPABASE_PUBLISHABLE_KEY` are provisioned, and those go through
PostgREST, not a raw SQL connection, so they cannot run this query. The script fails loudly
with an explanation if the secret is unset, rather than silently skipping the gate. Adding
the secret needs the DB password, which version-control does not hold — cto or the PO
needs to add it in the repo's Actions secrets.

The connection only needs to read `pg_catalog` (`pg_class`, `has_table_privilege`,
`pg_options_to_table`) — no elevated role is required.

`check_anon_allowlist_test.sh` proves the diff logic itself (shared with the real script via
`anon_allowlist_diff.sh`) rejects an unlisted view, using fixture data — no DB connection,
runnable anywhere:

```
bash scripts/ci/check_anon_allowlist_test.sh
```

## `ci.yml` (KAN-72)

`.github/workflows/ci.yml` runs `flutter analyze` and `flutter test` on push to `Canary`
and on PRs into `main`, pinned to Flutter 3.38.9 to match `deploy-web.yml`. It is a gate
only — it deploys nothing.

`--fatal-infos` is **not** enabled. Measured 2026-08-29 on the local tree (Flutter 3.44.1,
CI pins 3.38.9 so the exact count may shift slightly): `flutter analyze` already exits
non-zero on **2 pre-existing warnings** even without `--fatal-infos` —
`unused_local_variable` in `lib/features/social/presentation/widgets/circles/circle_picker_sheet.dart:128`
and `dead_null_aware_expression` in `lib/features/username_engine/username_consumer.dart:19`
— plus 144 non-fatal infos. Turning on `--fatal-infos` would add all 144 as new failures on
day one. Neither warning was touched here: `lib/features/**` is owned by
`flutter-feature-agent` under `docs/CONTRACT.md`, not `version-control`. **This gate will
show red on its first run** until those two warnings are fixed — flagged in the KAN-72
handoff rather than fixed out-of-lane.
