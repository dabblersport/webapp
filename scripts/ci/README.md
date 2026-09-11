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

It prints a **census** — of 1,761 `public` functions: `SECURITY DEFINER` 303; effectively
`anon`-executable **1,746**; both 290 (measured 2026-09-10) — which **never fails the build**,
and fails on a narrow predicate: a function that is `SECURITY DEFINER`, effectively executable
by `anon`, takes a uuid argument whose name denotes a person, and **never compares that
argument to `auth.uid()`**. 74 live signatures are recorded in `docs/SCHEMA.md` §2g as a
baseline; any flagged signature not on that list turns the build red.

*(The anon-executable figure was stated as 292 until 2026-09-10, when `backend-5` measured it
during the KAN-175 peer review. 292 is the `both` count; the anon-executable population is
~6× larger. The script itself was always correct — it prints the live value under its own
label — so this was prose drift, never a gate defect. Read the census output, not this
paragraph, for current numbers. The derivation command and date are recorded in
`docs/SCHEMA.md` §2g so the next drift is checkable rather than a matter of trust.)*

Three traps it is built around, each demonstrated failing in the self-test:

- **`has_function_privilege`, never a text match on `proacl`.** A bare `=X/postgres` entry
  grants `PUBLIC`, which `anon` inherits — 60 of the 292 definer+anon functions (2026-09-10
  reading; 290 later that day) are reachable only that way and are invisible to string
  matching.
- **Comparison, not mention.** 47 identity-taking functions mention `auth.uid()`; only **2**
  compare an argument to it. `COALESCE(p_user_id, auth.uid())` reads as authentication and is
  not.
- **No overload requirement.** An earlier draft required a shorter same-named overload; the
  worst live instance has no overload, so that requirement made the gate blind to it.

`DEFAULT auth.uid()` on a parameter is decoration, not mitigation — it applies only when the
caller omits the argument.

### It reports MEMBERSHIP, not just a count (KAN-193)

Every run prints the full flagged population between `--- ANON_FUNCTION_FLAGGED_BEGIN ---` and
`--- ANON_FUNCTION_FLAGGED_END ---`, `LC_ALL=C` sorted, one signature per line — **on both the
green and the red exit**. Extract that block from two runs' logs and `comm`/`diff` them to name
exactly which signatures entered and which left.

**Why this is not cosmetic.** The gate used to report only `OK: all 72 flagged function
signature(s) are on the allowlist`. A function newly becoming `anon`-reachable while a different
one is contained, in the same window, moves that number by **zero** — both runs print an
identical line, both are green, and the change is invisible. That is not hypothetical: it was
reproduced on a disposable Postgres before the fix, one signature out and a different one in,
and the two runs' outputs were **byte-identical**. It is also not academic — a real `72 → 70`
move was observed and could not be attributed to specific functions afterwards, because no log at
either point enumerated the set.

The red exit prints the population too, and needs it more, not less: the failure branch names only
the **offenders**, and without the population they were drawn from, whoever is looking at a red
gate cannot tell a real regression from a baseline that shifted underneath them.

**When reading any count-based gate, ask which members, not how many.** This is the second defect
found in this area by that question — the first was KAN-175's `LIMIT 1` hole, where the gate was
right about the population and wrong about which members were in it.

`74` is the **§2g allowlist size**, not a flagged count; the flagged count is a different
measurement and comparing the two as if they were the same is the KAN-175 AC6 error.

### The self-test really uses a database

```
bash scripts/ci/check_anon_function_grants_test.sh
```

Unlike `check_anon_allowlist_test.sh` — which is a pure text diff over fixture files and
never executes the catalogue SQL it exists to validate — this one **creates real functions in
a real, disposable Postgres** and asserts on what the shipped predicate actually returns. It
fabricates its cases from scratch, none named `rpc_potential_vibes` and none sharing a parameter
name with it, so it proves the gate catches functions nobody has written yet rather than the one
instance already known.

It seeds **ten** cases — six that must be flagged, four that must not — and then introduces an
eleventh mid-run, `rpc_late_arrival`, as the entrant in the KAN-193 add-and-drop check below.
*(Counted 2026-09-11 by running it. The paragraph above read "nine cases (five that must be
flagged, four that must not)" until this edit: the sixth must-flag case is
`rpc_second_arg_unguarded`, added by KAN-175's own AC7 without the prose being updated alongside
it. The count now appears in exactly one place — carrying it in two was how the stale one
survived, and a first draft of this correction left the old figure standing two lines above the
new one while claiming in the past tense that it had been fixed. `backend-6` caught that in peer
review. Same failure as the `74`-vs-`72` mislabel: two counts of different things, read as one.)*

Beyond the predicate cases it asserts, with the output **captured** rather than discarded:

- the full flagged population is emitted and reconstructs exactly, on the green exit **and** the
  red one;
- on the red exit the block is the population and not merely the offender list;
- a **masked add-and-drop** — one signature contained, a different one introduced, count
  unchanged, allowlist covering both so the gate stays green on both runs — is named exactly, in
  both directions, by diffing the two runs' blocks.

That last one is the criterion that matters. A test that only checked "the script prints a list"
would pass against an unsorted or static list that is not diffable at all.

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
