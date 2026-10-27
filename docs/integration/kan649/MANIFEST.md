# KAN-649 integration manifest (Personas S6)

Prepared 2026-10-27 by Deir el-Bahari so Memphis can run KAN-649 the moment KAN-645/646/648 land.
Nothing here touches the database. Rollback is in `ROLLBACK.md`.

## 1. Inputs (branch, sha at preparation time)

| Story | Branch | Sha | Notes |
|---|---|---|---|
| KAN-644 (S1) | `alpha-644-karnak` | `286a6393c87468b20d833b8812addec18954f8e9` | migration APPLIED on live; verify only |
| KAN-645 (S2) | `alpha-645-karnak` | `7896c41a0da02b173c2268bc2bf13f6ef37e687a` | migration not applied |
| KAN-646 (S3) | `alpha-646-ramesseum` | `c9487e7f553f4f34c2e6c662aff3bd7232207776` | migration not applied; blockers B1 (squads), B3 (partner social block) |
| KAN-647 | `alpha-647-karnak` | `5fc5fa2f45a0e734cf2ca25452255300b4896988` | app only |
| KAN-650 (648a) | `alpha-habu` | `64a5453b1e077b95b52635edce6bfbb214295eef` | app only; lands in the 648b chain |
| KAN-648 | `alpha-648-habu` | `ae6b2a33a9c833267f2dfd459b3608210a18966a` | app only; still being built, re-read the sha before use |
| Alpha | `origin/Alpha` | `f3f68dc35d663552deccc0f374a70e57b750315f` | already merged into this branch |

Re-read every sha with `git rev-parse` before integrating; 645/646/648 are moving.
`alpha-646-ramesseum` carries the 644/645 files too; its `kan644_personas_s1/probes.sql` differs from `alpha-644-karnak` by one line (older probes). Take the probes from this branch (hook-clean rewrite), not from 646.

## 2. Migrations, in the order to apply

Order follows schema dependency. 646 depends on 644 only and is independent of 645; 645 depends on 644's lock and guards.

| # | File | Hook sha256 (whitespace-normalised) | Raw sha256 | State |
|---|---|---|---|---|
| 1 | `supabase/migrations/20261026100000_kan644_personas_s1_schema_guards.sql` | `96222335936b0e023b6753597acce266fb99871d5a214132eafec212d94da5eb` | `b3d583848f2185356ed725ef0743cfa9306f6018607ab74bead58e930349e1be` | applied, verify only |
| 2 | `supabase/migrations/20261026110000_kan645_rpc_onboard_unified_profile.sql` | `882839cd6eac78d71a8684e27c586cf3631f7619aea5b050cb37651920582be5` | `ff60e292b381779877b06e97f5c5acd234521d77ec389e906bbcf9079138d7e8` | to apply |
| 3 | `supabase/migrations/20261026120000_kan646_personas_s3_capabilities.sql` | `5460689c4c9bf380ab0d5294de151a3d42c23e4161c02515fd7584a27bfd1bab` | `a305f3c5e788de4a0f252531ad506f08e1d8991dd7112a95d67e7eb3f7eca4f4` | to apply |

Hashes are of the files on `alpha-646-ramesseum` at c9487e7f. If a migration changes, recompute (`sql_hook.sha`) and re-release it in `agent/state/registry/sql_allow.json`; do not apply a file whose hash is not released.
KAN-647, KAN-648, KAN-650 carry no migrations. Apply nothing else.

## 3. Gates before step 3 (KAN-646)

CTO ruling (KAN-649 comment 14090): after KAN-645 is applied and before KAN-646 is, re-run KAN-646 probe sets G and J (`supabase/tests/kan646_personas_s3/probes.sql`) against S2's real `rpc_onboard_unified_profile` and attach the output. KAN-650 (648a) lands in the 648b chain.

## 4. Baseline compare (before any apply)

Capture with `supabase/tests/kan644_personas_s1/catalog_capture.sql` and keep the output. Baseline known on 2026-10-27: 179 profiles, 176 auth users, 3 accounts with more than one profile, zero contributor/partner rows. After each step re-run and compare: legacy rows unchanged (count + md5 of pre-existing rows; probe P6 does this), function and schema hashes change only for the objects the step is allowed to touch.

## 5. Read-back after each migration (read-only)

After step 1 (verify only):
```sql
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
 WHERE conrelid = 'public.profiles'::regclass
   AND conname IN ('profiles_persona_type_check','profiles_onboarding_intention_values_check','profiles_onboarding_intention_persona_check');
SELECT tgname, tgenabled FROM pg_trigger
 WHERE NOT tgisinternal AND tgname IN ('trg_unified_persona_guard_ins','trg_unified_persona_guard_upd',
   'trg_contributor_sports_profiles','trg_contributor_sports_sp',
   'trg_player_profile_persona_guard','trg_organiser_profile_persona_guard','trg_host_profile_persona_guard');
SELECT p.proname, p.proacl::text FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname IN ('trgfn_unified_persona_guard','trgfn_contributor_sports_check',
   'trgfn_player_persona_guard_v2','trgfn_organiser_persona_guard_v2','trgfn_host_persona_guard_v2');
```
Expect: persona CHECK lists player, organiser, host, socialiser, contributor, partner; both intention CHECKs present and validated; the three extension triggers call the `_v2` functions; no trigger function grants EXECUTE to anon or authenticated.

After step 2 (KAN-645):
```sql
SELECT p.oid::regprocedure AS sig, p.prosecdef, p.proacl::text
  FROM pg_proc p WHERE p.proname = 'rpc_onboard_unified_profile' AND p.pronamespace = 'public'::regnamespace;
SELECT pg_get_function_result('public.rpc_onboard_unified_profile(uuid,text,text,integer,text,text,uuid,uuid[],text,text)'::regprocedure);
```
Expect: exactly one signature `rpc_onboard_unified_profile(uuid,text,text,integer,text,text,uuid,uuid[],text,text)`, returns `uuid`, `prosecdef = true`, ACL grants EXECUTE to `authenticated` and `service_role` only (no anon, no PUBLIC).

After step 3 (KAN-646):
```sql
SELECT p.oid::regprocedure AS sig, p.proacl::text FROM pg_proc p
 WHERE p.pronamespace = 'public'::regnamespace
   AND p.proname IN ('actor_is_host','choose_actor','actor_is_player','actor_is_organiser',
                     'can_create_meetup','rpc_create_game_legacy_v2','rpc_create_sport_profile');
```
Expect: `actor_is_host(uuid)` exists; `choose_actor(text)` ACL is exactly `{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` (unchanged by the patch); the other patched functions keep the ACL they had in the baseline capture.

## 6. Journey and operation checks (after step 3, after the app builds are merged)

- Onboarding for each of the four intentions: `connect_play`, `play_organise`, `organise` (all contributor) and `host_games` (partner). Each ends with one profile, `onboard = true`, the right `persona_type`, the right `onboarding_intention`, and the extension rows the intention implies.
- Operation matrix: `docs/personas/kan646_operation_matrix.md` (on `alpha-646-ramesseum`) — player, organiser, host, create game, create sport profile, meetups, for contributor, partner and the four legacy personas.
- Legacy controls: an existing player, organiser, host and socialiser account each do their current journey unchanged.
- Known: KAN-646 blockers B1 (squads) and B3 (partner social block) are carried, not fixed here.
- `flutter analyze` and `flutter test` on the integrated Alpha tree.
- Pass/fail matrix with the evidence for every line goes on KAN-649.

## 7. Controls

- Integration into Alpha goes through the integration owner. This preparation branch pushes nothing.
- Memphis (ops) applies the migrations and runs the probes under the existing DB controls: additive only, no DROP, no `auth.*` writes, probes in one BEGIN..ROLLBACK.
- No public rollout. No main/Canary.
