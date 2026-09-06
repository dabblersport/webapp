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

`--fatal-infos` is **not** enabled. **The number that matters is the one CI measured against
the actually-committed `Canary` tree, not a local working copy** — a local sandbox in this
repo tends to carry other agents' uncommitted in-progress fixes layered on top of the last
commit, which understates the real count. Measured 2026-08-29 from the first real run of this
workflow (run `33240974826`, Flutter 3.38.9, fresh checkout): `flutter analyze` exits
non-zero with **217 issues — 55 warnings, 162 infos, 0 errors** even without `--fatal-infos`.
(A same-day measurement against a local working tree with other agents' uncommitted fixes
present showed only 2 warnings / 92 infos — that number was real for that tree but is not
the number this gate actually enforces; it's left here only as a caution against trusting a
local run over CI on this repo.) Turning on `--fatal-infos` would add all 162 as new failures
on top of the 55. **This gate shows red on its first real run** and will keep doing so until
the 55 warnings are fixed — out of scope for `version-control` (`lib/**` is owned by
`flutter-feature-agent` / `backend-owner` per `docs/CONTRACT.md`), flagged in the KAN-72
handoff instead. Full list: see the "Analyze" step of run `33240974826`.
