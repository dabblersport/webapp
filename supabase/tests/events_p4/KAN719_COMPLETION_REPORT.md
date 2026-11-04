# KAN-719 Z06 — migration completion report (KAN-783)

Measured 2026-11-04 by `backend-3` (Shed) on branch `alpha-luxor`, base HEAD `4ffe2d71`. All measurement ran on a
throwaway local PostgreSQL 16 cluster (port 55783, `initdb -A trust`). **No production or hosted Supabase database was
read or written.** Every statement about production below is therefore "not documented" unless a recorded apply is cited.

Proof is reproducible: `bash /Users/moataz/.claude/jobs/dcb6a775/tmp/k783/run783.sh <sha>` (builds the cluster from
`git archive <sha> supabase`, runs everything below, tears the cluster down). The SQL check is
`supabase/tests/events_p4/kan719_z06_report_check.sql` (this commit).

## (a) Migration identities — applied vs authored

Adding commit = `git log --diff-filter=A` on this branch. md5 = `md5 -q` of the file at this commit.

**Apply status for every row: authored, not applied to production.** A search of the migrations, the
`supabase/tests/events_p*` documents and the KAN-77x/78x result files found no recorded operations apply of any of these
versions to project `wtncuzcskpigqpmnxwws`; production apply state is therefore **not documented**. Production
`supabase_migrations.schema_migrations` was not read (out of scope: no hosted access).

| File | Version | Adding commit | md5 |
|---|---|---|---|
| `20261101140000_kan710_events_parent_schema.sql` | 20261101140000 | e847a1fd | `abb33f2794c42bf42c8e47b4340989a4` |
| `20261102110000_kan711_events_mirror_triggers.sql` | 20261102110000 | 5cbbf781 | `03ded49a8deae8000d2e82284af24928` |
| `20261102120000_kan711_events_backfill.sql` | 20261102120000 | 5cbbf781 | `d6064b8d1fb2eac1d265cfcd2c30ae05` |
| `20261103100000_kan712_events_write_contract.sql` | 20261103100000 | 9d9ab7ce | `4e6431f6a89c7756895943629d982359` |
| `20261103110000_kan712_cutover.sql` | 20261103110000 | 9d9ab7ce | `0b2d4b0eecacb0a1b1afc5e5807e2f95` |
| `20261104100000_kan713_access_helpers.sql` | 20261104100000 | aaa3898e | `3686f8a8de8ee3a1478ae8ac8c998082` |
| `20261104100100_kan714_b01_views_game_card_my_games.sql` | 20261104100100 | 7d9be26c | `d134e3ba53c59d08d0ba8806d69ba9de` |
| `20261104100200_kan714_b02_views_meetup_list_counts.sql` | 20261104100200 | 62efd916 | `bf552f1472d8202d0cb327b80deb383e` |
| `20261104100300_kan714_b03_views_rating_host_metrics.sql` | 20261104100300 | 6e47b63f | `b89c6ea3cd5cff648e8b5ffc79374647` |
| `20261104100400_kan714_b04_rpc_nearby_following.sql` | 20261104100400 | 4de93e4f | `fe28c403f7d5bc4d2ecffad76795b708` |
| `20261104100500_kan714_b05_search_filter_indexes.sql` | 20261104100500 | c1d7d13d | `37ca5274d54714eaa4f9fab0592be6e3` |
| `20261104100600_kan714_b06_rpc_meetup_reads.sql` | 20261104100600 | 3514b6be | `f25d7e3f73b0b977d9720527210e772b` |
| `20261104100700_kan714_b07_sport_overview_counts.sql` | 20261104100700 | be5dcaf0 | `8c8c7b28ddab1c41fe1c3cc9f595092a` |
| `20261104100800_kan714_b08_capacity_join_rating_checks.sql` | 20261104100800 | aba8732e | `4946e4ebe89e4faf2bd1ac711806c458` |
| `20261104100900_kan714_b09_booking_conflicts_hold.sql` | 20261104100900 | 44a3494d | `d199042c76a383386ec49eb2a79b5385` |
| `20261104101000_kan714_b10_settle_game_reads.sql` | 20261104101000 | 4af89787 | `670612778402cc264eee5ef988ac7c74` |
| `20261104101100_kan714_b11_msg_functions.sql` | 20261104101100 | 914e486a | `461f7a311df94e9f6b868745191d49be` |
| `20261104101200_kan714_b12_feed_notifications_stream.sql` | 20261104101200 | d7dd5113 | `28b5ce26cd249fa9eba96ec8345c79f9` |
| `20261104101300_kan714_b13_analytics_admin_export_cleanup.sql` | 20261104101300 | 0e62436c | `405216adc76a9e215004c0a2fef98416` |
| `20261104101400_kan714_b14_series_rpc_reads.sql` | 20261104101400 | 85230c71 | `4425a4f0d0bdb1bb12c4c09d333883c7` |
| `20261104102000_kan716_events_realtime_publication.sql` | 20261104102000 | cc481bc9 | `69b10b60c6e39b14d1aa558f973d3a8f` |
| `20261104110000_kan713_location_triggers.sql` | 20261104110000 | aaa3898e | `dd28640a9ea7f43e32c4d6634387970e` |
| `20261104110100_kan718_d04_last_shared_field_reads.sql` | 20261104110100 | 5abda4d2 | `d6c191c6599640d64893f6d63ad5422e` |
| `20261104110200_kan718_d05_old_client_compat_projection.sql` | 20261104110200 | edeeb099 | `b48eff0abf80ce0a136e8c85b7d4d6a4` |
| `20261104110300_kan718_d07_series_occurrence_unique.sql` | 20261104110300 | 00564a7c | `765fa6548e25ffbcdf6d93eb4d6d2066` |
| `20261104110400_kan785_retire_rpc_meetup_my.sql` | 20261104110400 | 9cea2d89 | `e6bfd258354fa745322dd24c22ce5333` |
| `20261104110500_kan786_meetup_leave.sql` | 20261104110500 | b7052576 | `9201572006173a02cd70c3bf9e9d9c8a` |
| `20261104110600_kan798_d04_blockers_join_invite.sql` | 20261104110600 | 97369708 | `aa8d23a74c6897d72aa54fe9c460c506` |
| `20261104110600_kan799_d04_blockers_remove_recreate.sql` | 20261104110600 | 9a42c849 | `2b154eaced63988beb7bad3de6e3a9c4` |
| `20261104110600_kan801_d04_blockers_meetup_rsvp.sql` | 20261104110600 | 78723a71 | `adb312af168cf44cd238a7ef240088aa` |
| `20261104110700_kan800_d04_blockers_meetup_requests.sql` | 20261104110700 | 67201194 | `85f969202dde822ea672b39ba55b54e5` |
| `20261104110700_kan806_kan712_write_path_after_z01.sql` | 20261104110700 | 3f112f9c | `3ecccdbc993e46fd273be671dcb2bf86` |
| `20261104110700_kan808_join_recheck_cancelled.sql` | 20261104110700 | 872f00ad | `7f8d84d516ce172eafc0879735db0b13` |
| `20261104110800_kan803_d04_blockers_frozen_guards_a.sql` | 20261104110800 | 8ca6d3d3 | `e78d6bc53ed6d779fcfcef85720a38eb` |
| `20261104110800_kan809_update_game_stale_guard.sql` | 20261104110800 | cc8b65e4 | `c831edbb74e79d2329c4d29fb401160c` |
| `20261104110900_kan804_d04_blockers_frozen_guards_b.sql` | 20261104110900 | ab0a4d44 | `d4bec70ee814d11a05e611cc3d38e543` |
| `20261104110900_kan807_d04_residual_a.sql` | 20261104110900 | 97e5e6df | `11c3d850c5b11e1d83d93be842c7e3be` |
| `20261104111000_kan807_d04_residual_b.sql` | 20261104111000 | 97e5e6df | `a30e5c3cdf0c00969805a03a5cf91abf` |
| `20261104112000_kan810_cancel_game_idempotent.sql` | 20261104112000 | 1e1f591a | `c31f93266e4b33b6172350946e9e85fc` |
| `20261104112100_kan834_d04_residual_c.sql` | 20261104112100 | 67c75707 | `a7d4215dd14fe4aa92b7b69851b34b69` |
| `20261105100000_kan714_events_parent_reads.sql` (part 1) | 20261105100000 | **missing from branch (X1 in the KAN-811 ruling)** — untracked in the worktree only | `c9d398b5e537605bf1251fd0ce76492a` |
| `20261105100000_kan719_z01_remove_replaced_columns.sql` | 20261105100000 | 7255541d | `e2c30568be1bb771337eabbed915a1a5` |
| `20261105100100_kan719_z05_remove_fallbacks.sql` | 20261105100100 | 167fff89 | `33280a07f39cce1bc95341aa4330692f` |
| `20261105110000_kan714_events_parent_reads_2.sql` | 20261105110000 | 2ad61afc | `0ada038e40ac5a78d4da03cf3d477429` |

Notes on identity:
- **Version collision:** part 1 (untracked) and Z01 both carry version `20261105100000` (also recorded in
  `KAN719_POSTCHECK.md`). Versions `20261104110600`–`20261104110900` are each shared by 2–3 files; a version-keyed
  migration runner would treat each group as one version.
- **Brief correction:** KAN-807 (`97e5e6df`) **is** on this branch — an ancestor of HEAD, also contained in
  `origin/Alpha`, `alpha-habu`, `alpha-karnak`; its functions exist on the local chain. The line that the KAN-807 residual
  functions are only on `alpha-habu` is stale.
- **Applied locally (this proof):** the harness chain (KAN-834 recipe: kan710–kan714 B01–B14, kan716, kan713 location,
  D04, D05, kan785, kan786, KAN-801, KAN-808 + local harness/seed), then kan806, kan809, kan807a, kan807b, kan810, kan834
  rc=0. **Refused locally at their own pre-image guard (rc=3), not applied:** kan798, kan799, kan800, kan803, kan804 —
  the functions they replace (`rpc_decide_join_request`, `rpc_invite_user`, `rpc_mint_join_link`, `rpc_remove_player`,
  `rpc_recreate_from_game`, `rpc_meetup_decide_request`, `rpc_meetup_remove_attendee`, the four
  `trgfn_*_frozen_guard` trigger functions, `trgfn_posts_set_geo`) are absent from the local chain. d07 and part 2 are
  not on the local chain (part 2 aborts on drifted pins, see (b) KAN-838).

## (b) Predecessor results

| Step | Ticket / commit | Test file | Recorded result |
|---|---|---|---|
| Z01 removal | KAN-778 `7255541d` | `kan719_z01_removal_test.sql` | Commit message records the manifest identity, the gate, the publication correction and a rolled-back dry run. **A separate recorded run result was not found — not documented** beyond the commit message and the test header (which expects the gate to refuse exactly on G3 and G6 on the test chain). |
| Z02 restore path | KAN-779 `20b130b3` | `KAN719_RESTORE_PATH.md`, `kan719_z02_restore_test.sql` | `kan779_result.md`: rc=0, `KAN-779 RESTORE TEST PASS`, `KAN-779 ALL PASS`, 17 PASS lines (its run was on port 55437). |
| Z03 pre-stop gate | KAN-780 `abfebc46` | `kan719_z03_prestop_gate.sql`, `kan719_z03_prestop_gate_test.sql` | Commit message: gate authored only, never applied. **Recorded run result not found — not documented.** |
| Z04 post-check | KAN-781 `169ecfa6` (cherry-pick of `cdb6856e`) | `KAN719_POSTCHECK.md`, `kan719_z04_postcheck.sql` | Doc records results on HEAD `44514216`: PASS S0 (44 columns removed, 3 HELD), C1 (3020 games / 2021 meetups), C2 except `meetups.search_tsv`, C3, M1 games, M2, M3 events UPDATE, M5, S1, S5, R. **FAIL** C2/M1 `meetups.search_tsv` (2010/2021), S2 (21 live functions), S3 (8 SQL bodies), S4 (harness stub trigger), M3 (`kan712_update_event_shared` 55000), M4 (42703). Verdict recorded: removal not safe on that chain. Checker proven on `04740e4f`: `kan781_fix3_rescoped_result.md` rc=0 `KAN-781 ALL PASS`, 15 ok lines. |
| KAN-819 fix | `29e1c415` | `kan805_s4_harness_skip_test.sql` | S4 trigger scan skips harness objects; test RED on the cherry-picked post-check, GREEN after the fix. |
| Z05 fallbacks | KAN-782 `167fff89` | `kan719_z05_fallbacks.sql` | `kan782_completed_result.md`: `KAN-782 Z05 TEST PASS: 53 checks + R; fallback inventory 6 HTP + 9 DUAL + 1 HELD + 0 COALESCE, all LIVE; removable set empty; Z05 a no-op`, `KAN-782 ALL PASS`; negatives N1–N3 caught. |
| Part-2 pin audit | KAN-838 `6d398925` | `KAN792_PIN_AUDIT.md` | Part 2 aborts at step 30 on the first drifted pin (row 1, `active_stream`); 20 of 39 pins mismatch; the audit's literals are pre-B01–B14 baseline images. |

## (c) Catalogue before and after (local PG16)

`before` = harness chain + the six rc=0 migrations above (database `k783pre`). `after` = a copy of it with the real Z01
file run with **`ON_ERROR_STOP=0`**, then Z05. **Z01 refuses at its own gate on this chain**: `KAN-778: phase-4 removal
refused, 3 unmet precondition(s)`:
- **G1** — `kan719.phase4_manifest_md5` is not set (operations-only authorisation, E9/E10);
- **G3** — 13 manifest indexes missing on the local chain (`idx_games_area`, `_cancelled`, `_is_cancelled`, `_geo`,
  `_host`, `_search_tsv`, `_start_at`, `_time`, `_title_prefix`, `_visibility`, `idx_meetups_owner`, `_owner_time`,
  `_search_tsv`);
- **G6** — `kan718_meetups_compat` and `v_meetup_list` still read `meetups.description`, `is_indoor`, `location_name`.

Because the gate's refusal is one statement and `ON_ERROR_STOP=0` lets later statements run, the "after" state is what
Z01's remaining statements do when forced past the gate: 18 ERROR statements (1 gate, 13 missing indexes, 3 `cannot drop
column` on the three G6 columns, 1 post-assert `columns outside the retained list survived: meetups.description,
meetups.location_name, meetups.is_indoor`). **This is not an authorised or a successful Z01 run; it is a measurement of
its removal body.** Z05 then reports `no fallback qualifies for removal (inventory 6 HTP + 9 DUAL live, 1 HELD, 0
COALESCE); nothing changed`.

| | before | after |
|---|---|---|
| `games` columns | 36 | 13 (23 removed) |
| `meetups` columns | 30 | 9 (21 removed; 3 held by G6) |
| `events` columns | 25 | 25 |
| events-related functions (body names games/meetups/events) | 104 | 104, set md5 unchanged `e1adae62bb8a6502b1d223ae0c2732d6` |
| events-related views | 10 | 10, set md5 unchanged `6ce0b12854a8bb7bf5e5b4c50b8e5851` |
| triggers on the three tables | 50 | 16 (34 removed, incl. `events.trg_zz_kan712_events_compat_mirror`, 20 on games, 13 on meetups) |
| policies on the three tables | 2 | 2; `meetups.meetups_select_visible` changed |
| public functions (all languages) | 217 | 217 |

Data: compat projections and `events` are byte-identical before and after within a run (check R fingerprint, md5 of
all rows ordered by id). Run on the committed SHA: `kan718_games_compat` 3020 rows `fa51e2201185c5b18edac06fe1d04ac7`,
`kan718_meetups_compat` 2021 rows `8e1f591f37435b16fa022ad92de5f959`, `events` 5041 rows
`98d299f13db93bffdfa6af0bfa4f74a5`, the same on both sides. The absolute values differ between builds (the harness
stamps build-time timestamps); the invariant is before = after. Base `games`/`meetups` row md5 change, as expected from
dropped columns (before `games` = its compat image `fa51e220…`; after `games` `3927d3aa…`).

## (d) Integrity, compatibility, smoke, restoration

`kan719_z06_report_check.sql` captures (on `before`) shapes of `games`, `meetups`, `events` and both compat views, 44 `rpc_*`
signatures, row counts and per-caller visible-id fingerprints, then checks — inside `BEGIN … ROLLBACK` — compat shape
against the explicit legacy pairs, events shape, RPC signatures, counts, the seed rows, visibility for owner / stranger /
blocked (authenticated), anon and service_role, and a write probe (events title update seen through compat); after
ROLLBACK it asserts the data fingerprint and counts are unchanged and the probe edit is gone.

- `before`: `KAN-783 Z06 REPORT CHECK PASS (pre-Z01): 39 checks + R`
- `after`: `KAN-783 Z06 REPORT CHECK PASS (post-Z01): 39 checks + R`
- Visible rows (games / meetups / compat_games / compat_meetups), identical before and after: owner 0/415/0/415,
  stranger 0/411/0/411, blocked 0/401/0/401, anon 0/411/0/411, service_role 3020/2021/3020/2021. (`games` has RLS on
  and no policy on this chain, so authenticated and anon see 0 games — recorded, not changed.)
- Negative controls in the runner (each must make the check FAIL with rc≠0): N1 tampered capture count, N2 a permissive
  `games` select policy for authenticated, N3 a renamed compat column.
- **Restoration (Z02):** `kan719_z02_restore_test.sql` on a copy of `before` (`k779_k783z02`), with the manifest SQL
  from `kan718_d06_manifest_check.sql` and the Z01 text: rc=0, sections Z1, Z2, Z3, NEG V1, NEG VERIFY, NEG, NEG
  ROLLBACK, Z5, V1–V6, Z7 PASS, `KAN-779 RESTORE TEST PASS`. Z2 ran 117 statements, skipped 13, held 3 (704, 722, 723).

## (e) Known failures and limitations (cited, not fixed)

1. **Z01 cannot run on this chain**: G1 (no ops authorisation), G3 (13 baseline-only indexes absent locally), G6
   (`v_meetup_list` and `kan718_meetups_compat` read three meetups columns). The "after" catalogue is a forced
   measurement, see (c).
2. **Six functions break after the forced Z01** (all OK before; KAN-834 census): `_can_view_game_for_join` 42703
   `g.creator_user_id`; `_slot_conflicts_game` 42703 `g.is_cancelled`; `game_slots_left` as authenticated 42703
   `g.capacity`; `kan711_events_map_game` 42P01 `"g"`; `kan711_events_map_meetup` 42P01 `"m"`;
   `rpc_unified_search_sectioned` 42703 `g.listing_visibility`. Business refusals unchanged before/after
   (`rpc_join_game` not_visible, `rpc_meetup_rsvp` started, `rpc_challenge_spawn_game` fixture_not_found).
3. **Z04 FAILs** recorded on `44514216` stand (meetups.search_tsv, S2, S3, M3, M4); this report did not re-run Z04.
4. **Z02 finding F3** (in D08): the 44 restored columns move to the end of the attribute order.
5. **Five migrations not applied locally** (kan798, 799, 800, 803, 804): their pre-images do not exist on the local chain.
6. **X1** part 1 missing from the branch and colliding with Z01's version; **X2** part 2 pins drifted (KAN-838). The
   KAN-811 ruling text itself was not read here; X1/X2 are used as defined in the brief.
7. **Production state not read.** Apply status, row counts and the 13 indexes on production are not documented.
8. Z01 and Z03 recorded run results not documented (see (b)).

### Next prerequisites (before any production Z01)

1. Commit or resolve part 1 (X1) and its version collision; re-pin part 2 to the post-B01–B14 images (X2).
2. Fix the six functions in (e)2 so they no longer read removed columns.
3. Give `meetups.description`, `location_name`, `is_indoor` and `meetups.search_tsv` a home and clear G6
   (`v_meetup_list`, `kan718_meetups_compat`).
4. Operations sets the G1 manifest md5 authorisation (E9/E10).
5. Bring the 13 baseline-only indexes onto the local chain (or regenerate the manifest) so G3 can be tested.
6. Provide local pre-images for kan798/799/800/803/804 so they can be proven.
7. A read-only production measurement (schema_migrations, columns, indexes, counts) by an authorised seat.
