# KAN-792 part 2 — pin audit against the blocker files (KAN-838, for KAN-811 blocker X2)

AUDIT ONLY. No migration was edited and nothing was applied anywhere except a throwaway local PG16 cluster
(port 55838, since torn down). The audited file is
`supabase/migrations/20261105110000_kan714_events_parent_reads_2.sql` ("part 2") at `alpha-luxor` 67c75707.

## What "pin matches" means here

Part 2's drift guard (`DO $pins$`, lines 133-189) computes `SELECT md5(prosrc) FROM pg_proc` for each of its
39 repointed functions (plus 3 helpers) and raises if the value differs from its literal. **This audit uses
exactly that convention: md5(prosrc).**

**Pin matches = yes** when part 2's literal equals md5(prosrc) of the body that is live when part 2 runs at
**step 30** of the KAN-811 apply order, i.e. after D04 (step 25) and steps 26-29. The ruling extract does not
list steps 1-24 or 26-29. The state used here is the repository chain dated before part 2, in the order the
existing KAN-834 proof chain (`tmp/k834/build834.sh`) uses: KAN-710/711/712/713 migrations, **KAN-714
B01-B14** (`20261104100100`-`20261104101400`), KAN-785, KAN-786, KAN-716, D07, **D04**, **D05**. The
candidates for steps 26-29 that are not blocker files (D05, D07, KAN-785, KAN-786, KAN-716, KAN-713 location
triggers) were grepped: **only KAN-786 replaces one of the 39** (`rpc_meetup_rsvp`), and its post-image is
part 2's literal. None of the others replaces any of the 42 pinned functions.

**This differs from what X2 assumes.** X2 treats the conflict as part 2 against the blocker files. In fact
**part 2's literals are the pre-B01-B14 baseline images.** For 15 of the 39, a KAN-714 B-file (B04, B05, B08,
B09, B10, B11, B12 or B13), dated **before** D04, has already replaced the body by step 30. Those rows say
"no" even where no blocker file touches the function. If steps 1-24 do NOT include B01-B14, those 15 rows
would match. See "Conditional", below.

**"Last body"** is the body live after step 40 if every file applied as written. As written, though, **part
2 aborts at step 30** on its first drifted pin (row 1, `active_stream`), so none of its 39 replacements
lands. The blocker files at steps 31-39 then find the pre-image they pinned and apply. "Last body" below
describes the INTENDED end state, where part 2 has been fixed so that it applies.

## Methods

- **(a) literal**: a pin literal read from a migration file with `git show <ref>:<path>`.
- **(b) measured**: md5(prosrc) measured on the throwaway PG16 16.15 cluster at
  `/Users/moataz/.claude/jobs/dcb6a775/tmp/k838/`, port 55838. The build was `build838.sh`, which is
  `tmp/k834/build834.sh` cut off before seed781/harness801/KAN-801/KAN-808, with logs redirected to k838 and
  a `createdb -T` snapshot taken just before D04. It was built from `git archive 67c75707 supabase`.
  - 15 of the 39 functions are absent from that harness chain. Each was installed in a scratch copy from
    the last repository definition before step 30: `20260829080500_baseline_schema.sql`, or
    `20260915120000_meetups_hardening.sql` for the two meetup request RPCs, or `20261008160000` for the
    5-argument `rpc_get_nearby_games`. Those bodies were installed verbatim with
    `check_function_bodies=off`.
  - No November migration before step 30 redefines those 15. This was checked by grep: B05 lists
    `nearby_games`, `rpc_search_entities` and `rpc_autocomplete_entities` as "UNCHANGED". B08 lists
    `rpc_decide_join_request`, `rpc_remove_player`, `rpc_meetup_decide_request` and `rpc_join_game` as
    "REPORTED, not changed" or "no own read". `20261013135000` only REVOKEs.
- **Cross-check of the measurement.** All 15 baseline-installed bodies reproduce part 2's literal exactly.
  So does every pre-D04 value of the D04 rows. Every measured post-B value that a later file also pins
  agrees with that file's literal: the KAN-807 a/b pre pins (rows 1, 20, 22, 29-31), the KAN-834 pre pin
  for `_user_hosted_game`, and the B13/B10 literals. The convention and the chain therefore agree with the
  files.
- The KAN-714 B-file bodies are literal `CREATE OR REPLACE` statements. None of them is derived by
  `regexp_replace` from its input. Their measured output therefore does not depend on harness inputs.
- Cluster torn down: `pg_ctl stop`, then data directory removed. `lsof -nP -iTCP:55838` returned nothing.
  `ls .s.PGSQL.55838` returned "No such file or directory".

## Blocker files read (`git ls-tree` confirmed)

- D04 `20261104110100_kan718_d04_last_shared_field_reads.sql` (origin/Alpha 576432af; identical on HEAD)
- KAN-798 `20261104110600_kan798_d04_blockers_join_invite.sql`, KAN-806
  `20261104110700_kan806_kan712_write_path_after_z01.sql`, KAN-804
  `20261104110900_kan804_d04_blockers_frozen_guards_b.sql` (origin/Alpha-karnak 0c0eb763)
- KAN-799 `20261104110600_kan799_d04_blockers_remove_recreate.sql`, KAN-800
  `20261104110700_kan800_d04_blockers_meetup_requests.sql`, KAN-803
  `20261104110800_kan803_d04_blockers_frozen_guards_a.sql`, KAN-807 a
  `20261104110900_kan807_d04_residual_a.sql`, KAN-807 b `20261104111000_kan807_d04_residual_b.sql`
  (origin/alpha-habu 29e1c415)
- KAN-801 `20261104110600_kan801_d04_blockers_meetup_rsvp.sql`, KAN-808
  `20261104110700_kan808_join_recheck_cancelled.sql`, KAN-834 `20261104112100_kan834_d04_residual_c.sql`
  (alpha-luxor HEAD 67c75707)

**KAN-803, KAN-804 and KAN-806 replace none of the 42 functions part 2 pins.** KAN-806 replaces
`kan712_update_event_shared`, and KAN-803/804 replace `trgfn_*` guards and `trgfn_posts_set_geo`. **KAN-834
replaces none of the 39 either.** It replaces the part 2 helper `_user_hosted_game` (see "Helpers"), plus
`can_current_user_join_game`, `_recent_activity_score` and `game_is_joinable`, none of which part 2 pins.
KAN-834 is not a named owner in the ruling.

## The 39 repointed functions

Column key: **step-30 md5** = md5(prosrc) live at step 30. **Other files** = every other migration that
replaces the function, as `file (literal pre -> post)`. B-files are listed because they cause the drift,
although they are not blocker files.

| # | Function (identity signature) | Part 2 pin | Other files replacing it | Required final owner (hazard 3) | Step-30 md5 | Pin matches | Method | Last body | Action |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `public.active_stream(text[],text,integer,timestamp with time zone,text,uuid)` | `0e7b7eddfce6dee2746734fb47fbf332` | B12 (pre 0e7b7edd); KAN-807 a (pre 3cad1cfa -> post 8dcd3004) | KAN-807 | `3cad1cfaaa6fb56e1cbd7ac86e7e5192` (B12 post) | no | (b), = KAN-807 a pre literal (a) | KAN-807 a | drop the function from part 2 |
| 2 | `public.admin_cleanup_user_data(uuid,boolean)` | `978ae882109662a5e229bb87aebad01b` | B13 (pre 978ae882 -> post 09baee67) | none | `09baee67932be2618af9043c89155db2` (B13 post) | no | (b), = B13 literal (a) | part 2 | re-pin part 2 |
| 3 | `public.admin_overview_row()` | `f5a9160e240140ed7c5a373a3d494e79` | B13 (pre f5a9160e -> post 42573e04) | none | `42573e04bc2aae0af755ded1f8eceb5a` (B13 post) | no | (b), = B13 literal (a) | part 2 | re-pin part 2 |
| 4 | `public.fn_game_roster_activity_sync()` | `3274cca43042f67a81c9853dd82b4415` | none | none | `3274cca43042f67a81c9853dd82b4415` (baseline) | yes | (b) baseline body | part 2 | none |
| 5 | `public.fn_generate_game_series_occurrences_kan712_inner(uuid)` | `2c36c743e9b82699fea440e2c93aa976` | none (B14 mentions it, body unchanged) | none | `2c36c743e9b82699fea440e2c93aa976` | yes | (b) | part 2 | none |
| 6 | `public.fn_meetup_rsvps_activity_sync()` | `ea879f6ac22b0e2a7e154201a7184a49` | none | none | `ea879f6ac22b0e2a7e154201a7184a49` (baseline) | yes | (b) baseline body | part 2 | none |
| 7 | `public.get_games_needing_players()` | `2938404e665ffa0ce504826bfd55b146` | D04 (pre 2938404e -> post c818c208) | KAN-792 | `c818c2082bf1a29e40202776869ad42b` (D04 post) | no | (a) D04 pre literal = part 2 pin; (b) post | part 2 | re-pin part 2 |
| 8 | `public.get_open_games_for_seeding()` | `261911f5b095b992ce3b463818ecf99f` | D04 (pre 261911f5 -> post 30333cbe) | KAN-792 | `30333cbe1d77a6a5ca5b1e757e3e945f` (D04 post) | no | (a) D04 pre literal = part 2 pin; (b) post | part 2 | re-pin part 2 |
| 9 | `public.msg_authorize(uuid,text)` | `6a3939c6c75a310d7c2769db059021f9` | B11 | none | `b55e059bcf494df887e48ebdf8139949` (B11 post) | no | (b) | part 2 | re-pin part 2 |
| 10 | `public.msg_evaluate(uuid,uuid,text)` | `240ca1a775de5a611aee06c60e92148d` | B11 | none | `3276466a3d192afd4ee4675135637859` (B11 post) | no | (b) | part 2 | re-pin part 2 |
| 11 | `public.msg_my_conversations(integer)` | `e06086af6b1f7c076e7ee6498ae7c3e4` | B11 | none | `1297831ca8202108ba9001a750c8935d` (B11 post) | no | (b) | part 2 | re-pin part 2 |
| 12 | `public.nearby_games(double precision,double precision,integer,text,integer,integer)` | `19b0a6c0ce028c4273f46ece71713d9a` | none (B05: UNCHANGED) | none | `19b0a6c0ce028c4273f46ece71713d9a` (baseline) | yes | (b) baseline body | part 2 | none |
| 13 | `public.rpc_autocomplete_entities(text,text[],text,integer)` | `10369e0dba10ae05a27221a448eb5caf` | none (B05: UNCHANGED) | none | `10369e0dba10ae05a27221a448eb5caf` (baseline) | yes | (b) baseline body | part 2 | none |
| 14 | `public.rpc_booking_cancel(uuid)` | `574e008d904dbb4e40db298559a9192d` | none (B09 mentions it, body unchanged) | none | `574e008d904dbb4e40db298559a9192d` | yes | (b) | part 2 | none |
| 15 | `public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamp with time zone,timestamp with time zone)` | `df2359a7c9fb031cb350836139a13ab9` | none (B09 mentions it, body unchanged) | none | `df2359a7c9fb031cb350836139a13ab9` | yes | (b) | part 2 | none |
| 16 | `public.rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone)` | `ff1ee16988a8c15d1065795cf940c435` | B09 | none | `0b7e53391b2a44007316d42036d95134` (B09 post) | no | (b) | part 2 | re-pin part 2 |
| 17 | `public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)` | `5b8883b2ab8b55f8d2119c6fbd023dcc` | D04 (pre aa4876c6 -> post e565a2ba); step 25 `20261105120000` KAN-794 (pre 0b8161fa -> post 5b8883b2) | KAN-792 | `5b8883b2ab8b55f8d2119c6fbd023dcc` (step-25 post, `20261105120000`:297) | yes | (a) step-25 post literal = part 2 pin; (b) local chain, `kan887_part2_after_kan794_test.sh` | part 2 (post `1b3aa6f2b8033bdf64c5bc856d6c7f43`) | re-pinned and re-authored on the step-25 body, only the replay read moved to the overlay (KAN-887, dreq-9e4edd4c). **Hazard 4 closed** |
| 18 | `public.rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)` | `0f5ba02e7123f095436350842f229dae` | D04 (pre ef0d41b5 -> post 77a14a22); step 25 `20261105120000` KAN-794 (pre 713db51a -> post 0f5ba02e) | KAN-792 | `0f5ba02e7123f095436350842f229dae` (step-25 post, `20261105120000`:299) | yes | (a) step-25 post literal = part 2 pin; (b) local chain, `kan887_part2_after_kan794_test.sh` | part 2 (post `f347168e1c1a6b424ebabea41ff3e85f`) | re-pinned and re-authored on the step-25 body, only the replay read moved to the overlay (KAN-887, dreq-9e4edd4c). **Hazard 4 closed** |
| 19 | `public.rpc_decide_join_request(uuid,boolean)` | `7c03f9298eb4754f9a281e3620af7f93` | KAN-798 (pre 7c03f929; post not pinned in file) | KAN-798 | `7c03f9298eb4754f9a281e3620af7f93` (baseline) | yes | (a) KAN-798 pre literal; (b) baseline body | KAN-798 | drop the function from part 2 |
| 20 | `public.rpc_get_activity_feed(text,integer,timestamp with time zone)` | `73036a69dbec39c5bd44209b80147f1e` | B12 (pre 73036a69); KAN-807 a (pre 1d6bb179 -> post 88455cac) | KAN-807 | `1d6bb17983ba2ed632cb4f7602257162` (B12 post) | no | (b), = KAN-807 a pre literal (a) | KAN-807 a | drop the function from part 2 |
| 21 | `public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)` | `11c52abd9873a93cf71db5ca6b29c480` | B04, only if the overload exists (pre 11c52abd -> post 63e5a660) | KAN-807 by name (the ruling gives no signature; KAN-807 replaces only the 6-arg overload) | `63e5a660f80100f02e2674db40b58a3a` if present (B04 post); absent per B04 ("expected on live") | no | (b) B04 `$n5$` block run on the 20261008160000 body; (a) B04 guard text | B04 if present, else nothing | drop the function from part 2 |
| 22 | `public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)` | `e14430bad3dedb8540287f70ccfaa208` | B04 (pre e14430ba); KAN-807 a (pre b96323a7 -> post 3a27dca7) | KAN-807 | `b96323a71f8726e0ce6ab8ccc1a1dc69` (B04 post) | no | (b), = KAN-807 a pre literal (a) | KAN-807 a | drop the function from part 2 |
| 23 | `public.rpc_invite_user(uuid,uuid)` | `f090ca17e10a837091f19c1e0597f164` | KAN-798 (pre f090ca17; post not pinned in file) | KAN-798 | `f090ca17e10a837091f19c1e0597f164` (baseline) | yes | (a) KAN-798 pre literal; (b) baseline body | KAN-798 | drop the function from part 2 |
| 24 | `public.rpc_join_game(text,uuid,uuid)` | `9d1ca06d255364137a456b31980a5c60` | KAN-808 (pre 9d1ca06d -> post 63915136) | KAN-808 | `9d1ca06d255364137a456b31980a5c60` | yes | (a) KAN-808 pre literal; (b) | KAN-808 | drop the function from part 2 |
| 25 | `public.rpc_meetup_decide_request(uuid,uuid,text)` | `d8c60f06cbc35e6b1e579a266863ba14` | KAN-800 (pre d8c60f06; post not pinned in file) | KAN-800 | `d8c60f06cbc35e6b1e579a266863ba14` (20260915120000) | yes | (a) KAN-800 pre literal; (b) 20260915120000 body | KAN-800 | drop the function from part 2 |
| 26 | `public.rpc_meetup_remove_attendee(uuid,uuid)` | `7fec2761af25e3e0fd414922b7d07e6d` | KAN-800 (pre 7fec2761; post not pinned in file) | KAN-800 | `7fec2761af25e3e0fd414922b7d07e6d` (20260915120000) | yes | (a) KAN-800 pre literal; (b) 20260915120000 body | KAN-800 | drop the function from part 2 |
| 27 | `public.rpc_meetup_rsvp(uuid,text,uuid,uuid)` | `acc145f2fa5cf81db600beef47fc6a6d` | KAN-786 (post acc145f2, step <= 29); KAN-801 (pre acc145f2 -> post 179b6c26) | KAN-801 | `acc145f2fa5cf81db600beef47fc6a6d` (KAN-786 post) | yes | (a) KAN-801 pre literal; (b) | KAN-801 | drop the function from part 2 |
| 28 | `public.rpc_mint_join_link(uuid,timestamp with time zone,integer)` | `6ffbb7cdf8421eef95f4060659084bbe` | KAN-798 (pre 6ffbb7cd; post not pinned in file) | KAN-798 | `6ffbb7cdf8421eef95f4060659084bbe` (baseline) | yes | (a) KAN-798 pre literal; (b) baseline body | KAN-798 | drop the function from part 2 |
| 29 | `public.rpc_rate_game(uuid,uuid,jsonb,text)` | `195bf3e5b9bc14165fe0feba89635b3b` | B08 (pre 195bf3e5); KAN-807 a (pre d6f6f577 -> post de0f3b8f) | KAN-807 | `d6f6f57755538391ece9aa19b6dd8a50` (B08 post) | no | (b), = KAN-807 a pre literal (a) | KAN-807 a | drop the function from part 2 |
| 30 | `public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)` | `12cb3bf4c0fa33a6a8f11aec94da1e96` | B08 (pre 12cb3bf4); KAN-807 b (pre fd2700e7 -> post dffe5f8e) | KAN-807 | `fd2700e72e60bdf7f7eb9e1b36201b10` (B08 post) | no | (b), = KAN-807 b pre literal (a) | KAN-807 b | drop the function from part 2 |
| 31 | `public.rpc_rate_venue(uuid,uuid,uuid,jsonb,text)` | `2bce0cd675ee5865731d05adb90883e9` | B08 (pre 2bce0cd6); KAN-807 b (pre d1dab200 -> post fe2f803c) | KAN-807 | `d1dab20091ecef646714dc20edf8ea7d` (B08 post) | no | (b), = KAN-807 b pre literal (a) | KAN-807 b | drop the function from part 2 |
| 32 | `public.rpc_recreate_from_game(uuid,boolean)` | `6e410ca16771fbdf20a6f37553131e6c` | KAN-799 (pre 6e410ca1; post not pinned in file) | KAN-799 | `6e410ca16771fbdf20a6f37553131e6c` (baseline) | yes | (a) KAN-799 pre literal; (b) baseline body | KAN-799 | drop the function from part 2 |
| 33 | `public.rpc_remove_player(uuid,uuid)` | `ab3b5239eb5bb283622679c842ba9cd7` | KAN-799 (pre ab3b5239; post not pinned in file) | KAN-799 | `ab3b5239eb5bb283622679c842ba9cd7` (baseline) | yes | (a) KAN-799 pre literal; (b) baseline body | KAN-799 | drop the function from part 2 |
| 34 | `public.rpc_search_entities(text,text[],text,integer)` | `802a43a24f290110b614aa1ff9c04570` | none (B05: UNCHANGED) | none | `802a43a24f290110b614aa1ff9c04570` (baseline) | yes | (b) baseline body | part 2 | none |
| 35 | `public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)` | `fe3382197842fa66564b2f62d9b754f5` | B05 (pre fe338219) | none | `399680ac808bddb5a34ef081410dfbd4` (B05 post) | no | (b) | part 2 | re-pin part 2 |
| 36 | `public.settle_game(uuid,boolean)` | `9357b0e9dc93ba715811aa0ae101cd76` | B10 (pre 9357b0e9 -> post ee62121d) | none | `ee62121d87bee5c6dd1109e6ad11d8b4` (B10 post) | no | (b), = B10 literal (a) | part 2 | re-pin part 2 |
| 37 | `public.trg_game_join_request_notify()` | `65f55b54654b9fe12ef5e6afef4ebe6f` | none | none | `65f55b54654b9fe12ef5e6afef4ebe6f` (baseline) | yes | (b) baseline body | part 2 | none |
| 38 | `public.trg_game_waitlist_promoted_notify()` | `263d03c2b3ac0a1ca281e40a1ae71c46` | none | none | `263d03c2b3ac0a1ca281e40a1ae71c46` (baseline) | yes | (b) baseline body | part 2 | none |
| 39 | `public.trg_meetup_rsvps_notify()` | `55efefd5cf5b5556d11f6ac093fd64b8` | B12 (pre 55efefd5) | none | `a22ed63dec19a237b005e30e9c038dc1` (B12 post) | no | (b) | part 2 | re-pin part 2 |

**C1 check.** The command is `grep -cE '^\| ([1-9]|[1-3][0-9]) \|' supabase/tests/events_p4/KAN792_PIN_AUDIT.md`.
It returns **39**. Helper rows below are labelled H1-H3 and are not counted.

## Totals

- **Pin matches: 19 yes, 20 no.** Of the 20 "no" rows, 4 are caused by D04 (rows 7, 8, 17, 18). The other
  16 are caused by KAN-714 B-files dated before D04 (rows 1, 2, 3, 9, 10, 11, 16, 20, 21, 22, 29, 30, 31,
  35, 36, 39). Row 21 says "no" on both branches: if the overload is present, B04 rewrites it; if it is
  absent, part 2's guard raises.
- **Actions: 16 "drop the function from part 2", 13 "re-pin part 2", 10 "none".**
  - **Drop** (16) covers every function with a named blocker owner: KAN-798 x3, KAN-799 x2, KAN-800 x2,
    KAN-801 x1, KAN-807 x7 (counting the 5-arg overload) and KAN-808 x1. Hazard 3 requires the blocker body
    to end last. Each of those blocker files pins the step-30 body as its pre-image, so a part 2 that
    replaced the function at step 30 would make the blocker fail closed. **Of the 16, 9 match today; the
    other 7 (all KAN-807) already drift.** The ruling leaves the choice between this and re-authoring the
    blocker to the PM.
  - **Re-pin** (13) covers KAN-792-owned functions and functions with no owner whose step-30 body moved.
    **"Re-pin" here means re-authoring from `pg_get_functiondef` of the step-30 body, not only changing
    the md5 literal.** Part 2's replacement bodies were derived from the pre-image. Changing only the
    literal would silently overwrite the D04 or B-file body with a stale one (T-058). For the B-file rows,
    whoever re-authors part 2 should also confirm that part 2 still has reads to move. The B-files already
    repoint shared-field reads, and if nothing is left, the right action becomes "drop".
  - **None** (10): the pin matches and no later file replaces the function.
- **Hazard 4 (rows 17, 18).** The local post-D04 md5s (`e565a2ba…`, `77a14a22…`) are from the repository
  chain. The ruling reports production drift: `rpc_create_game` live `0b8161fa…` against D04's pinned
  `aa4876c6…`, and `rpc_create_meetup` live `713db51a…` against pinned `ef0d41b5…`. **What part 2 would see
  on production at step 30 is not established.** It depends on how D04 is re-authored against production.
  Production was not read (no MCP and no production SQL, by brief).

## Helpers part 2 also pins (not part of the 39)

| H# | Helper | Part 2 pin | Other files | Step-30 md5 | Pin matches | Method |
|---|---|---|---|---|---|---|
| H1 | `public.game_slots_left(uuid)` | `1f6418851fd9c18d36165f111a4b1f5f` | B08 (pre 1f641885) | `bd773c6f559b9692753fdfccd1eee959` (B08 post) | no | (b) |
| H2 | `public.meetup_slots_left(uuid)` | `e80d0677a9a6fee5fb507efe93c2d158` | B08 (pre e80d0677) | `17e5926db75031e80ffdf8aedbb803a5` (B08 post) | no | (b) |
| H3 | `public._user_hosted_game(uuid,uuid)` | `dc84da3e337f875afecad11c80bf6e2e` | D04 (pre dc84da3e -> post 41a0f3b1); **KAN-834** (pre 41a0f3b1 -> post 792f07c4) | `41a0f3b192055a68f7dbaea2807c9933` (D04 post) | no | (b), = KAN-834 pre literal (a) |

Part 2's pin `dc84da3e…` for `_user_hosted_game` is the pre-D04 image, which confirms the earlier
measurement. KAN-834's authored post-image is `792f07c44f71c4dc154716a5905b0659` (literal). Part 2 copies
these three helpers into owner-only twins (`kan714_*`), so a re-authored part 2 must copy the step-30
bodies. KAN-834's position in the ruling order is not given in the extract.

## Conditional, and what is not established

- **If KAN-714 B01-B14 are not in steps 1-24**, 12 of the 16 B-caused "no" rows would match: rows 1, 2,
  3, 20, 21, 22, 29, 30, 31, 35, 36 and 39. For each of them, the B-file's own pre pin equals part 2's
  literal (method (a), from B04, B05, B08, B10, B12 and B13). **For rows 9, 10, 11 (B11) and 16 (B09) this
  is not established.** Those B-files do not carry part 2's literal, and the pre-B body was not measured
  for them. This audit assumes the B-files run before D04, because they are dated before it and KAN-807's
  pre pins are the post-B values.
- Steps 1-24 and 26-29 are not enumerated in the ruling extract. Membership was inferred from the
  repository order and the existing proof chain, and is stated above.
- No md5 is given for the post-images of KAN-798, KAN-799 or KAN-800. Those files carry no post literal,
  and the post-images were not measured, because they do not bear on whether part 2's pin matches.
- Production bodies were not read for any row.

## KAN-858: pins now in part 2

Part 2 was re-authored under KAN-858 (KAN-839 ruling, Jira comment 15440: X1 option c, X2 part 2 only). The
16 "drop" rows are out of the file. It now pins 22 functions plus H1-H3, and the re-pinned rows' bodies are
`pg_get_functiondef` of the step-30 bodies, with only `public.games` / `public.meetups` reads moved to the
overlays. Measured on the local step-29 chain (`build_kan810.sh`). Production was not read. Proof:
`supabase/tests/events_p4/kan858_part2_guard_test.sh`.

| # | Function | Step-30 md5 (above) | Part 2 pin now | Equal | Note |
|---|---|---|---|---|---|
| 2 | `admin_cleanup_user_data` | `09baee67932be2618af9043c89155db2` | not pinned | — | **removed from part 2**: its step-30 body touches `public.games` only as a DELETE target, so it has no read to move, and the post-condition "body changed" could not hold |
| 3 | `admin_overview_row` | `42573e04bc2aae0af755ded1f8eceb5a` | `42573e04bc2aae0af755ded1f8eceb5a` | yes | re-authored |
| 7 | `get_games_needing_players` | `c818c2082bf1a29e40202776869ad42b` | `c818c2082bf1a29e40202776869ad42b` | yes | re-authored |
| 8 | `get_open_games_for_seeding` | `30333cbe1d77a6a5ca5b1e757e3e945f` | `30333cbe1d77a6a5ca5b1e757e3e945f` | yes | re-authored |
| 9 | `msg_authorize` | `b55e059bcf494df887e48ebdf8139949` | `b55e059bcf494df887e48ebdf8139949` | yes | re-authored |
| 10 | `msg_evaluate` | `3276466a3d192afd4ee4675135637859` | `3276466a3d192afd4ee4675135637859` | yes | re-authored |
| 11 | `msg_my_conversations` | `1297831ca8202108ba9001a750c8935d` | `1297831ca8202108ba9001a750c8935d` | yes | re-authored |
| 16 | `rpc_booking_hold_for_meetup` | `0b7e53391b2a44007316d42036d95134` | `0b7e53391b2a44007316d42036d95134` | yes | re-authored |
| 17 | `rpc_create_game` | `5b8883b2ab8b55f8d2119c6fbd023dcc` | `5b8883b2ab8b55f8d2119c6fbd023dcc` | yes | re-authored on the step-25 body (KAN-887); post `1b3aa6f2b8033bdf64c5bc856d6c7f43`, asserted in part 2 section 5. **Hazard 4 closed** |
| 18 | `rpc_create_meetup` | `0f5ba02e7123f095436350842f229dae` | `0f5ba02e7123f095436350842f229dae` | yes | re-authored on the step-25 body (KAN-887); post `f347168e1c1a6b424ebabea41ff3e85f`, asserted in part 2 section 5. **Hazard 4 closed** |
| 35 | `rpc_unified_search_sectioned` | `399680ac808bddb5a34ef081410dfbd4` | `399680ac808bddb5a34ef081410dfbd4` | yes | re-authored |
| 36 | `settle_game` | `ee62121d87bee5c6dd1109e6ad11d8b4` | `ee62121d87bee5c6dd1109e6ad11d8b4` | yes | re-authored |
| 39 | `trg_meetup_rsvps_notify` | `a22ed63dec19a237b005e30e9c038dc1` | `a22ed63dec19a237b005e30e9c038dc1` | yes | re-authored |
| H1 | `game_slots_left` | `bd773c6f559b9692753fdfccd1eee959` | `bd773c6f559b9692753fdfccd1eee959` | yes | twin `kan714_game_slots_left` re-authored |
| H2 | `meetup_slots_left` | `17e5926db75031e80ffdf8aedbb803a5` | `17e5926db75031e80ffdf8aedbb803a5` | yes | twin re-authored, as INVOKER (the original is DEFINER) |
| H3 | `_user_hosted_game` | `41a0f3b192055a68f7dbaea2807c9933` | `41a0f3b192055a68f7dbaea2807c9933` | yes | twin re-authored. **KAN-834 must apply after part 2**, or this pin trips |

The 10 "none" rows keep their bodies and pins. The 7 baseline-only functions reproduce those pins.

After X2, none of the 22 retained functions calls a twin. The step-30 helpers already read `public.events`
themselves when the caller can. The twins are kept because the brief says to re-author H1-H3.

**Stage guard (X1).** The part 1 check is gone. It is replaced by B01-B07/D04 post-image pins. Functions are
pinned by md5(prosrc). Views are pinned by md5 of the sorted `schema.relation.column` list from `pg_depend`
on their rewrite rule. D04 is also held by rows 7, 8, 17, 18 and H3.

| From | Object | Pin |
|---|---|---|
| B01 | `v_game_card` / `v_my_games` | `d7c7c593…` / `3b765364…` |
| B02 | `v_meetup_list` / `v_meetup_counts` | `8724655e…` / `372835d5…` |
| B03 | `v_rateable_after_game` | `1eeadf5e…` |
| B04 | `rpc_games_following_joined(uuid[])` | `2ca02c52…` (B04 post; the step-29 chain has B04's pre `d3b31f55…`, see RED-A) |
| B05 | `rpc_unified_search_sectioned` | `399680ac…` |
| B06 | `rpc_meetup_card(uuid,text)` / `rpc_meetup_attendees` | `c63da3ea…` / `59bdc97a…` |
| B07 | `rpc_sport_overview(uuid,text)` / `v_host_weekly_metrics` | `e7eb361a…` / `6ad1f78d…` |
| D04 | `meetup_counts(uuid)` | `e5982fbd…` |

**Not established.**
- These pins are local. The view dependency pins assume the production views depend on the same columns.
- `nearby_games`'s body (baseline, "none" row) reads `games.sport`. The local harness has no such column,
  so with `check_function_bodies` on the file fails there locally. Whether production has `games.sport` was
  not checked.
