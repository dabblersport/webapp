# CI scripts

## `check_anon_allowlist.sh` (KAN-61, `docs/DECISIONS.md` T-002)

Runs in `.github/workflows/anon-allowlist-check.yml` on push to `Canary` and on PRs into
`main`. Queries `pg_class` for every `public` view `anon` can `SELECT` without
`security_invoker`, and fails the build if any such view is not on the allowlist in
`docs/SCHEMA.md` §2f.

**Requires a `SUPABASE_DB_URL` GitHub Actions secret** — a direct Postgres connection
string for `wtncuzcskpigqpmnxwws` (Project Settings → Database → Connection string). The
script fails loudly with an explanation if the secret is unset, rather than silently
skipping the gate.

*(Corrected 2026-09-10, KAN-175. This paragraph said the secret did "not exist yet" and
that cto or the PO needed to add it. It was provisioned **2026-08-29**, and
`gh run list --workflow=anon-allowlist-check.yml` shows the gate completing **success** in
8–20s on every push to `Canary` and PR into `main` since. The gate is live and really is
querying the database. Left corrected in place rather than deleted, because "the secret is
missing" was quoted more than once as a reason the gate could not be trusted.)*

The connection only needs to read `pg_catalog` (`pg_class`, `has_table_privilege`,
`pg_options_to_table`) — no elevated role is required.

`check_anon_allowlist_test.sh` proves the diff logic itself (shared with the real script via
`anon_allowlist_diff.sh`) rejects an unlisted view, using fixture data — no DB connection,
runnable anywhere:

```
bash scripts/ci/check_anon_allowlist_test.sh
```

## `check_anon_function_grants.sh` (KAN-175, `docs/SCHEMA.md` §2g)

**The view gate above covers views only.** Its SQL reads `WHERE c.relkind = 'v'` — there is
no `pg_proc`, no `proacl`, no `EXECUTE` anywhere in it. A `SECURITY DEFINER` **function**
that `anon` can call is a different Postgres object class and sat outside every control the
project had; the view gate ran green throughout the live window of the exposure it was
supposed to catch. This script covers the function class. It shares `SUPABASE_DB_URL` with
the view gate and needs no extra secret.

It prints a **census** (SECURITY DEFINER: 303; anon-executable: 292; both: 292 — measured
2026-09-10) which **never fails the build**, and fails on a narrow predicate: a function that
is `SECURITY DEFINER`, effectively executable by `anon`, takes a uuid argument whose name
denotes a person, and **never compares that argument to `auth.uid()`**. 74 live signatures
are recorded in `docs/SCHEMA.md` §2g as a baseline; a 75th turns the build red.

Three traps it is built around, each demonstrated failing in the self-test:

- **`has_function_privilege`, never a text match on `proacl`.** A bare `=X/postgres` entry
  grants `PUBLIC`, which `anon` inherits — 60 of the 292 are reachable only that way and are
  invisible to string matching.
- **Comparison, not mention.** 47 identity-taking functions mention `auth.uid()`; only **2**
  compare an argument to it. `COALESCE(p_user_id, auth.uid())` reads as authentication and is
  not.
- **No overload requirement.** An earlier draft required a shorter same-named overload; the
  worst live instance has no overload, so that requirement made the gate blind to it.

`DEFAULT auth.uid()` on a parameter is decoration, not mitigation — it applies only when the
caller omits the argument.

### The self-test really uses a database

```
bash scripts/ci/check_anon_function_grants_test.sh
```

Unlike `check_anon_allowlist_test.sh` — which is a pure text diff over fixture files and
never executes the catalogue SQL it exists to validate — this one **creates real functions in
a real, disposable Postgres** and asserts on what the shipped predicate actually returns. It
fabricates nine cases (five that must be flagged, four that must not), none named
`rpc_potential_vibes` and none sharing a parameter name with it, so it proves the gate catches
functions nobody has written yet rather than the one instance already known.

Substrate: set `KAN175_TEST_DB_URL` to a service-container Postgres in CI, or leave it unset
locally and the script starts and destroys its own Docker container (no local `psql` needed).
**It never touches `wtncuzcskpigqpmnxwws`.** If neither substrate is available it fails rather
than falling back to fixtures, because a fixture fallback would silently stop testing the only
thing worth testing.

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
