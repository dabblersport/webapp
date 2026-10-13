# KAN-497 caller map: is_blocked and the block / unblock / unfollow RPCs

Status: AUTHORED from the repo and the supplied KAN-496 catalog reads. Nothing was measured live
for this ticket and nothing was run against any database.

Scope (five functions, project wtncuzcskpigqpmnxwws only):
`public.is_blocked(uuid,uuid)`, `public.rpc_block_user(uuid)`, `public.rpc_block_user(uuid,boolean)`,
`public.rpc_unblock_user(uuid)`, `public.rpc_unfollow_user(uuid)`.

## Evidence recorded

Starting list: `KAN-496_CONSOLIDATED_REPORT.md` section 2.2 and `LIVE_EVIDENCE.md` E8 (catalog read,
2026-10-13 ~09:20 UTC). It was extended or checked with these commands, run on Alpha `6a4223f6`:

| Command | Result |
|---|---|
| `git grep -n "is_blocked" -- . ':!*.md'` outside `supabase/migrations` | `lib/data/models/social/friend_model.dart:191` (a JSON field named `is_blocked`, not the function); `scripts/ci/anon_function_grants_diff.sh:46` (a comment); two files under `supabase/schema/archive/` (history, not applied). **App code never calls the function.** |
| `git grep -n "is_blocked" -- supabase/migrations` | baseline definition + 4 baseline callers; `20260912190747` (comment only); `20261008140000:426` and `20261008160000:89` (rpc_get_nearby_games). No other migration calls it. |
| `git grep -n "rpc_block_user\|rpc_unblock_user\|rpc_unfollow_user\|is_blocked" -- supabase/functions scripts tests integration_test test_driver .github` | **0 hits.** No edge function, CI script call, API test or e2e test calls any of the five. |
| `git grep -n "rpcBlockUserFn\|rpcUnblockUserFn\|rpcUnfollowUserFn" -- lib` | the callers in section C. |
| Latest definition of every caller (a script that takes the last `CREATE [OR REPLACE] FUNCTION/VIEW` across migrations in filename order) | the "Latest def" column in section A. |
| `GRANT`/`REVOKE` lines in migrations after the baseline for each caller | the "Anon-reachable" column. |

Caveats stated once: (1) "anon-reachable" here is repo-derived (baseline grants plus later revokes);
the catalog read E1/E8 is the live evidence for `is_blocked` and for the dependent list, and the
probes in `probes.sql` re-check reachability at apply time. (2) A role without EXECUTE on a function
fails when the statement is prepared, even if a `viewer IS NOT NULL AND ...` guard would short-circuit,
so for the revoke decision every invoker caller counts, not only the paths that reach the call.
(3) `no JWT` means `auth.uid()` is NULL: service_role, cron, a trigger fired outside a request.

## A. Callers of `is_blocked` (directly, or through the visibility resolvers)

"Passes auth.uid()" answers decision 4: is the viewer argument always `auth.uid()`?

### A1. Direct callers (they contain the text `is_blocked(`)

| # | Caller | Kind | Latest def | First arg is | Passes auth.uid()? | Anon-reachable | Runs with no JWT |
|---|---|---|---|---|---|---|---|
| 1 | `_can_view_with_scope_canonical(viewer,owner,scope)` | invoker fn | baseline:835 | parameter `viewer_user_id`, guarded `IS NOT NULL` | **not by itself** (parameter); no repo caller at all | yes: anon holds EXECUTE (baseline grant) | yes if called, but short-circuits on NULL viewer |
| 2 | `can_view_with_scope(viewer,owner,scope,squad)` | invoker fn | baseline:4321 | parameter | **every repo caller passes `auth.uid()` or a variable assigned `auth.uid()`** (A2); direct RPC callers could pass anything | yes: anon EXECUTE, and reached from anon-readable views | yes, short-circuits on NULL viewer |
| 3 | `can_view_with_scope3(viewer,owner,scope)` | invoker fn | baseline:4367 | parameter | callers `rpc_meetup_*` pass `me := auth.uid()` | yes: anon EXECUTE | yes, short-circuits |
| 4 | `get_feed(limit,offset)` | definer fn | baseline:7126 | `auth.uid()` literally | **yes** | yes: anon EXECUTE (returns no rows without a caller) | not meant to |
| 5 | `rpc_get_nearby_games(lat,lng,radius,sport,sort[,max_price])` (see note below the table) | definer fn | `20261008160000:25` | `auth.uid()` literally, twice | **yes** | **yes by design** (`20261008140000:444` grants anon) | n/a |
| 6 | `rpc_get_nearby_games_legacy_v1`, `_v2`, `_v3` | definer fn | baseline:13185 body and later renames | catalog E8 lists three legacy forms; the bodies that exist in the repo use `auth.uid()` | yes | **no**: `20261008180000` revokes v1, v2 from PUBLIC/anon/authenticated; `20261008140000:576` does v3 | no |

Note on row 5: `20261008140000` creates the 6-argument form (`p_max_price`) and grants it to anon; `20261008160000` is a record file whose `CREATE OR REPLACE` text shows a 5-argument signature, while its own header says the live function has one overload. Replayed from the repo alone it would add a second, 5-argument overload. This is drift between the repo and the live record, not changed here; probe A3 lists the live overloads, and the probes call the 6-argument form explicitly so a second overload cannot make the call ambiguous.

Triggers calling `is_blocked`: **none** in the repo. Policies calling it: **none** (E8 agrees).
Edge functions: **none**. App code (`lib/`): **none**.

### A2. Callers of the resolvers (second hop). Each passes the viewer from `auth.uid()`

| Caller | Kind | Latest def | Viewer passed | Passes auth.uid()? | Anon-reachable | No JWT |
|---|---|---|---|---|---|---|
| `can_view_owner(owner,scope)` | invoker fn | baseline:4117 | `auth.uid()` literal | yes | yes (anon EXECUTE; used by policies and views) | NULL viewer short-circuits |
| `can_view_post(uuid,posts)` (2-arg) | invoker fn | `20260912182108:67` | `auth.uid()` literal (KAN-180 removed `p_viewer`) | yes | yes | NULL short-circuits |
| `can_view_post(uuid,uuid,uuid)` (3-arg) | definer fn | `20260912182108:86` | does not call the resolvers at all (reads `auth.uid()` into `v_user_id`) | n/a | yes (in the section 2g allowlist) | n/a |
| `can_current_user_join_game` | invoker fn | baseline:3630 | `viewer := auth.uid()`; returns early if NULL | yes | no call survives for anon (NULL returns first), but anon holds EXECUTE | no |
| `_can_view_game_for_join(game)` | invoker fn | baseline:816 | `auth.uid()` literal | yes | yes (anon EXECUTE) | NULL short-circuits |
| `_can_view_game(game)` | definer fn | baseline:784 | `auth.uid()` literal | yes | yes (used by roster/waitlist policies) | NULL short-circuits |
| `can_current_user_rsvp_meetup` | definer fn | `20260912190747:33` | `u := auth.uid()` (KAN-180); anon answers `'anon'` first | yes | yes, by design (`20260915120000:830`) | no |
| `rpc_meetup_attendees` | definer fn | `20260915120000:406` | `me := auth.uid()` | yes | **no**: revoked from PUBLIC/anon (`20260915120000:771`) | no |
| `rpc_meetup_card` | definer fn | `20260915130000:79` | `me := auth.uid()` (into `can_view_with_scope`) | yes | yes, by design (`20260915130000:187`) | no |
| `rpc_meetup_*` family (baseline:13530, 13596, 13866 callers of the 3-arg resolver) | definer fn | baseline then `20260915120000` | `me := auth.uid()` | yes | write RPCs revoked from anon by KAN-427; reads as above | no |
| `rpc_join_game` | definer fn | baseline:13415 | via `can_current_user_join_game` | yes | authenticated path | no |
| `rpc_games_following_joined`, `rpc_search_entities`, `meetup_counts`, `can_read_row` | definer/invoker fn | various | via `_can_view_game`, `v_game_card`, `can_view_owner` | not individually read; they reach the resolvers only through the objects above, which all use `auth.uid()` | not enumerated further; none references any of the five by name | n/a |
| `v_game_card` | view (anon SELECT, section 2f allowlist) | `20261008140000:89` | `can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id)` | yes | **yes (anon allowlist)** | n/a |
| `v_challenge_card` | view (anon SELECT, section 2f allowlist) | baseline:25272 | `can_view_with_scope(auth.uid(), c.owner_user_id, ...)` | yes | **yes (anon allowlist)** | n/a |
| `v_meetup_list` | view (anon SELECT, section 2f allowlist) | `20261008140000:18` | `can_view_owner(...)` | yes | **yes (anon allowlist)** | n/a |
| `v_meetup_counts` | view | `20260915120000:136` | `can_view_owner(...)` | yes | no (anon revoked, `20260915120000:214`) | n/a |
| Policies `meetups_select_visible`, `roster_select_visible`, `waitlist_select_visible`, `challenges_select`, `demo_content_select`, `meetup_attendees_select` | RLS policy | baseline | `auth.uid()` via the resolvers | yes | evaluated for any role whose table grant allows SELECT; `posts_select_policy` is `TO authenticated` | n/a |

Result for decision 4: **no caller in the repo passes a viewer other than `auth.uid()`**. The narrowing
is valid for every caller in this map. No stop condition is hit. The one residual: the three resolvers
are themselves public RPCs that take an arbitrary viewer. Calling them with someone else's id used to
return the block answer (the second oracle, see the migration header). After the narrowing they answer
as if nobody is blocked for a viewer who is not the caller. That is the intended closure, not a caller
that depends on it.

Result for decision 5 (hold the `is_blocked` revoke): **yes, there are anon-reachable INVOKER-rights
callers.** `can_view_with_scope`, `can_view_with_scope3`, `_can_view_with_scope_canonical`,
`can_view_owner`, `can_view_post` (2-arg), `_can_view_game_for_join` are invoker functions that anon can
reach through the anon-readable views `v_game_card`, `v_challenge_card`, `v_meetup_list` and through
direct anon RPC. They call `is_blocked` as the calling role. Therefore the revoke migration revokes the
four RPCs only. See README, section "Held for a CEO decision".

## B. Callers of the four mutating RPCs

| Caller | Kind | Function | Passes auth.uid()? | Anon-reachable | No JWT |
|---|---|---|---|---|---|
| `lib/data/repositories/block_repository_impl.dart:24` (`BlockRepositoryImpl.block`) | app | `rpc_block_user(p_peer)` | the function reads `auth.uid()`; the app sends only the peer | no: signed-in screens | no |
| `lib/data/repositories/block_repository_impl.dart:34` (`unblock`) | app | `rpc_unblock_user(p_peer)` | same | no | no |
| `lib/features/meetups/presentation/providers/meetup_follow.dart:25` | app | `rpc_unfollow_user` | same | no | no |
| `lib/features/profile/presentation/screens/profile/user_profile_screen.dart:504` | app | `rpc_unfollow_user` | same | no | no |
| `lib/features/social/presentation/screens/post_detail_screen.dart:241` | app | `rpc_unfollow_user` | same | no | no |
| `lib/features/social/presentation/screens/real_friends_screen.dart:348` | app | `rpc_unfollow_user` | same | no | no |
| `rpc_block_user(uuid,boolean)` | **no caller anywhere** (not in `lib/`, edge functions, migrations or tests) | | | grant only | |
| Triggers | `trg_notify_admins_of_block` (AFTER INSERT on `user_blocks`) **fires from** `rpc_block_user(uuid)`'s insert; it does not call any of the five | | | | the revoke does not touch it |
| Other functions / views / edge functions | none call any of the four | | | | |

App-code result: the app calls only the four mutating RPCs, as `authenticated`, from signed-in
screens. It never calls `is_blocked`. It does not call `rpc_block_user(uuid,boolean)`. **No call as anon
exists on purpose**, so no stop condition applies.

Nuance for decision 6: the three block/unblock bodies refuse a NULL `auth.uid()` (they raise).
`rpc_unfollow_user(uuid)` does not raise: with no caller it matches no row and returns 0. Either way an
anon call changes nothing, and the revoke is safe and independent of `is_blocked`.

## C. Anon-allowlist relationship (KAN-61, T-002; docs/SCHEMA.md sections 2f, 2g)

* Section 2f (views): `v_game_card`, `v_challenge_card`, `v_meetup_list` are on the allowlist and anon-readable.
  The narrowing does not change their grants, rows or columns. Under the narrowing, for anon
  `can_view_with_scope(NULL, ...)` short-circuits as before, so the rows anon sees are unchanged.
* Section 2g (functions): `is_blocked(user_a uuid, user_b uuid)`, `rpc_block_user(p_peer uuid)`,
  `rpc_block_user(p_peer uuid, p_block boolean)`, `rpc_unblock_user(p_peer uuid)` and
  `rpc_unfollow_user(p_target_profile_id uuid)` are listed in the 2g allowlist as known
  anon-executable exceptions. After the revoke migration, the four RPC entries are stale (they
  stop being anon-executable). A stale entry does not fail the gate (`scripts/ci/anon_function_grants_diff.sh:248-251` takes only live-not-in-allowlist; line 188 calls a stale entry "just a stale allowlist entry to tidy"); the gate fails on a function that is
  anon-executable and **not** listed. The block itself was deliberately not edited in this ticket (it is
  outside allowed paths); a separate cleanup removes the four lines after apply.
