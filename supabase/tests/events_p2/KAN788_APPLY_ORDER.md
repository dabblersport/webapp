# KAN-788 — apply order for KAN-713 location triggers vs KAN-714 B files

Linked from the KAN-714 contract (KAN714_CONTRACT §7 "Operations order"). The contract is not on this branch, so this
decision is recorded here and in `scripts/check_migration_apply_order.py`.

## The problem

`20261104110000_kan713_location_triggers.sql` sorts **after** the KAN-714 B files `20261104100100` … `20261104101400`.
Four of those files open with a prerequisite guard that requires the six `trg_kan713_*` triggers it creates: B03, B06,
B09 and B11. (B14 has the same kind of guard, but it requires only `kan713_meetup_visible`, which comes from
`20261104100000_kan713_access_helpers.sql` and is already in time.) Production applied KAN-713 before KAN-714, in the
contract §7 order: KAN-710 → 711 → 712 stage B → KAN-713 (access helpers, location triggers) → KAN-714. A fresh cluster
built in **filename order** (`supabase db reset`, or any per-file runner) therefore stops at B03:

```
ERROR:  KAN-722: prerequisite stage missing: public.events.trg_kan713_events_location, public.games.trg_kan713_games_a_location,
        public.games.trg_kan713_games_b_joining, public.games.trg_kan713_games_c_venue_geo,
        public.meetups.trg_kan713_meetups_a_location, public.meetups.trg_kan713_meetups_b_joining
```

## Decision: option (a) — a documented order, enforced by a check that fails loudly

**Chosen: (a).** Option (b), a retimestamp, was rejected. The fix stays out of the migration files themselves.

Why (a):

1. **Production already recorded these versions in this order.** `20261104110000` sits in production's migration
   history alongside the B versions. If the file were renamed to sort earlier, its new version would not be in that
   history: `supabase db push` would see it as unapplied and try to run it a second time. The old version would also
   stay in the history with no file, which is drift. Both outcomes are worse than the problem being fixed.
2. **The guards already fail safe.** B03/B06/B09/B11 refuse with a clear message rather than half-applying. The only
   thing missing was a way to know the right order before running, and a check that rejects the wrong one. Both are
   added here, and neither touches a migration.
3. The brief's default when both options are equally safe is (a), and here (a) is strictly safer.

**Production's applied-version list is unchanged.** No migration is renamed, edited or re-run, and this ticket made no
production or live-Supabase call of any kind. The only changes are the new check script, its test, the local builder
and this document.

## The order

The only change from filename order: **`20261104110000_kan713_location_triggers.sql` applies immediately after
`20261104100000_kan713_access_helpers.sql`, before `20261104100100_kan714_b01_…`.** Everything else stays in filename
order. For the events P2 range:

```
20261101140000_kan710_events_parent_schema.sql
20261102110000_kan711_events_mirror_triggers.sql
20261102120000_kan711_events_backfill.sql
20261103100000_kan712_events_write_contract.sql
20261103104000_kan851_capture_run_seed_meetup_template.sql
20261103105000_kan844_kan712_contract_flag_set_config.sql
20261103110000_kan712_cutover.sql
20261104100000_kan713_access_helpers.sql
20261104110000_kan713_location_triggers.sql      <-- moved up
20261104100100_kan714_b01 … 20261104101400_kan714_b14
(then 20261104110300_kan718_… and later, in filename order)
```

The full repaired order for the whole directory is printed by:

```bash
python3 scripts/check_migration_apply_order.py --print-order
```

**`supabase db reset` in plain filename order is unsupported for this range.** A fresh cluster must apply the order
above, either per file or by feeding `--print-order` to a runner.

## The check

`scripts/check_migration_apply_order.py` reads files only and never connects to a database.

- It reads the names each guarded migration requires: the quoted `'trg_…'` names, and `to_regprocedure('public.fn(`
  calls, in any file that raises `prerequisite stage missing`.
- It finds the migration that `CREATE`s each of those names.
- It exits **1** when a creator is applied after its dependent, or is missing from the order. The message names both
  files and their positions, then points back at `--print-order` and this document.

```bash
python3 scripts/check_migration_apply_order.py                 # filename order: exit 1, 24 violations (B03/B06/B09/B11 x 6 triggers)
python3 scripts/check_migration_apply_order.py --order FILE    # a planned order, one name per line: exit 0 when sound
python3 scripts/check_migration_apply_order.py --print-order   # the repaired order
python3 scripts/test_check_migration_apply_order.py            # offline unit tests
```

A name that no migration creates statically, such as one made by dynamic SQL or a harness object, is listed as
unresolved and does not fail the check.

## Proof on a throwaway PG16 cluster

```bash
bash supabase/tests/events_p2/build_kan788.sh /tmp/kan788_pg 54788
pg_ctl -D /tmp/kan788_pg stop -m fast
```

The builder runs the check on its own migration list first, and refuses to build if the check fails. It then builds a
brand new local cluster and applies all 21 KAN-710 … KAN-714 migrations in the order above, with `ON_ERROR_STOP`. Every
migration step must equal the next entry of the checked list.

Results:

- Order check: `apply order OK: 21 migrations, 56 guarded prerequisites checked`.
- Build: exit 0, with no `ERROR` and no `prerequisite stage missing`.
- Cluster state: all six `trg_kan713_*` triggers are present.

Fixture notes:

- **B04 runs in a second database, `k788b`.** Its harness and the KAN-714 harness both create `public.geometry`, in
  different shapes. `k788b` uses the same chain without the KAN-714 harness.
- **B11's `msg_*` pre-images are not in any tracked harness.** The builder generates them into `<datadir>.fixtures/` by
  cutting line ranges, verbatim, from the repository's own KAN-505/547/558/559/560/563 migrations. There are two marked
  stand-ins:
  - no `REFERENCES public.game_roster (id)`, because the harness `game_roster` has no `id`;
  - a reduced `v_profile_public`, projecting only `id`, `display_name` and `avatar_url`, which are the columns B11 reads.

  `local_harness_kan731.sql` loads before B11 to supply `profiles.created_at` and `game_roster.joined_at`. None of these
  generated files is committed.
- **`local_harness_kan725.sql` is not loaded.** It refuses on the KAN-714 harness chain, and B06 does not need it.
- **KAN-716 is outside this range.** It needs the platform `supabase_realtime` publication, which no local cluster has.

To confirm the RED, use the same chain with the location triggers left out of their decided place. B03 exits 3 with the
`KAN-722: prerequisite stage missing` error quoted above. The check reports the same thing without a database:
moving `20261104110000` after B03 in the builder's list makes `--order` exit 1 with six violations.
