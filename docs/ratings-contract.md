# Player ratings: server contract (KAN-664, Ratings B1)

Status 2026-10-27. Derived from the repository (`supabase/migrations/20260829080500_baseline_schema.sql`, KAN-86 and KAN-26 migrations) and the additive
migration `20261027120000_kan664_ratings_read_paths.sql`. **The live database was not queried** (this team may not run SQL): every statement about live
grants, policies and row data is repo-derived until Operations runs `supabase/tests/kan664_ratings_b1/probes.sql` and reads the result.
No Dart code calls any rating RPC today (`grep rpc_rate_ lib` is empty), so there are no existing callers to keep compatible.

## 1. The three existing rating RPCs (unchanged)

| RPC | Subject | Notes |
|---|---|---|
| `rpc_rate_user(p_game_id uuid, p_rater_profile_id uuid, p_ratee_user_id uuid, p_scores jsonb, p_comment text default null) returns text` | a co-player or the host | **the player rating** |
| `rpc_rate_game(p_game_id, p_rater_profile_id, p_scores jsonb, p_comment)` | the game | not in scope |
| `rpc_rate_venue(p_game_id, p_venue_id, p_rater_profile_id, p_scores jsonb, p_comment)` | the venue | not in scope (no venue ratings in this epic) |

All `SECURITY DEFINER`, `search_path = public`, owner `postgres`. Baseline granted EXECUTE to `anon`, `authenticated`, `service_role`; the body refuses a signed-out
caller with `auth_required`, so anon cannot write, but the anon EXECUTE grant itself is a drift to be confirmed by probe P2.2 (this ticket does not change it).

### 1.1 Submit: `rpc_rate_user` as built
Returns `'ok'`. Writes `user_reputation_events(game_id, rater_user_id, rater_profile_id, ratee_user_id, scores, comment<=280)`; an AFTER INSERT trigger and the RPC call
`reputation_recompute(ratee)`.

Enforced: signed in; game exists and is not cancelled; `now() <= end_at + 7 days`; `p_rater_profile_id` belongs to the caller; the rater profile has
`profile_type = 'player'`; rater is an `active` `game_roster` member; ratee is an `active` roster member or the game creator; no self-rating; one rating per
(game, rater, ratee) (`ux_repu_once_per_game`); `p_scores` is a JSON object; every active dimension applicable to the ratee that is present in `p_scores` is numeric
and in 0..5.

Error codes (`errcode P0001`, stable `message`): `auth_required`, `game_not_ratable`, `rating_window_closed`, `not_profile_owner`, `organiser_cannot_rate_user`,
`rater_not_in_game`, `ratee_not_in_game`, `cannot_rate_self`, `already_rated`, `invalid_scores`, `score_not_numeric`, `score_out_of_range`.

### 1.2 Gaps found in submit (PROVEN from the function body; NOT changed here: replacing a SECURITY DEFINER body whose live text is unverified is outside "additive only")
1. **Finished game is not enforced.** Only the upper bound (`end_at + 7 days`) is checked; a rating before `end_at` is accepted. The new `rpc_get_unrated_coplayers` refuses
   `game_not_finished`, so a client that uses it is correct, but the write path itself does not enforce it.
2. **Scale is 0..5 numeric, per dimension; there is no single 1..5 integer.** Decimals and 0 pass. The ticket text says "1 to 5 integer plus fixed tags".
3. **Unknown keys in `p_scores` are stored.** Only keys that are active dimensions are range-checked; any other key is persisted in the jsonb and ignored by the aggregate.
4. **Contributor accounts are refused.** `profile_type <> 'player'` raises `organiser_cannot_rate_user`; the unified Contributor profile (KAN-645) carries
   `profile_type = 'personal'`. A Contributor therefore cannot rate until this check is relaxed. This touches the personas surface and is a decision, not a silent change.
5. The 7-day window is a literal in the body, not configuration.

Each of 1..4 needs a replacement of `rpc_rate_user` (same signature) and is a separate, explicitly approved migration.

## 2. Who has the caller not rated yet: `rpc_get_unrated_coplayers(p_game_id uuid)` (NEW, read-only)
Returns `table(user_id uuid, profile_id uuid, is_host boolean)`: every active roster member of the game plus the creator, minus the caller, minus anyone the caller
already rated in this game, host first. `STABLE SECURITY DEFINER`, `search_path = public`, EXECUTE to `authenticated` only.
Errors: `auth_required`, `game_not_ratable` (missing or cancelled), `game_not_finished` (`now() < end_at`), `rating_window_closed` (`> end_at + 7 days`),
`rater_not_in_game` (caller not an active roster member). "Already rated" is the same predicate `rpc_rate_user` uses, so the two cannot disagree.
Empty result = everyone is rated. It lists people the caller may rate; it never returns a rater.

## 3. Aggregate read: `rpc_get_user_rating_aggregate(p_user_id uuid)` (NEW, read-only)
Returns `table(user_id, composite_score numeric(3,2), event_count integer, dimension_means jsonb)` where `dimension_means` maps dimension key to mean (2 dp,
`sum / count` of the decayed aggregate). **Zero rows when `event_count < threshold`.** Never a partial average, never null-filled.
Errors: `auth_required`. EXECUTE to `authenticated` only. Reads `user_reputation_aggregate` only; it does not touch `user_reputation_events`.
Replaces direct reads of `user_reputation_aggregate` / `v_user_reputation` / `v_reputation_leaderboard`, none of which a client can use (section 5).

### 3.1 Threshold
**8 ratings.** Source: `public.v_reliable_teammate_candidates` takes `COALESCE(badge_rules.params->>'min_count' for badge_key 'reliable_teammate', 8)`; the new function
evaluates the identical expression, so the number is unchanged and has one definition. The repo default is 8; the live `badge_rules` row (if any) is data and unverified
here; probe P5 prints the value it used in the `detail` column. Note `reputation_config.prior_weight` is also 8 but is a Bayesian smoothing weight, not a visibility
threshold. **Fact to confirm (does not block):** that product accepts the reliable-teammate minimum as the single rating-visibility threshold; no other rating min-count
exists in the schema.

## 4. Fixed tag list: `rpc_list_rating_dimensions()` (NEW, read-only)
Returns `table(key, label_en, label_ar, applicable_to text[], sort_order)` for active rows of `public.reputation_dimensions` (`applicable_to` contains
`rate_player` and/or `rate_organiser`; `rpc_rate_user` uses `rate_organiser` when the ratee is the game creator, else `rate_player`). This table is the one
server-side fixed list; "tags" in the product language are these dimensions. The rows themselves are live data: the keys referenced by SQL in the repo are
`sportsmanship` and `reliability`; the complete live list is printed by probe P3b. `reputation_dimensions` is not client-readable after KAN-86 (all grants revoked, none
re-granted), which is why this function exists.

## 5. Anonymity (hard rule): how it holds
- `user_reputation_events` is the only place `rater_user_id` for player ratings is stored. RLS: one policy `ure_block_dml` (`USING false`, all commands). KAN-86
  revoked every table privilege from `anon` and `authenticated` and re-granted only verbs with a client write call site; none exists for rating tables. A ratee
  (or anyone) therefore cannot `select` rater ids. Same for `ratings`, `game_rating_events`, `venue_rating_events`, `rating_reports`.
- `v_user_reputation` is `security_invoker` and sits on `user_reputation_aggregate`, which also has no client grant; `v_reputation_leaderboard` and
  `v_reliable_teammate_candidates` are owner-rights views with only REFERENCES/TRIGGER/MAINTAIN granted to clients. None exposes a rater, and none is client-selectable.
- The only client read paths are the three new functions: co-players (not raters), a threshold-gated aggregate (no per-event data), and dimension labels.
- **Proven, not asserted:** probes P3 (privilege and policy checks on every rater-bearing table/view), P4 (a real ratee session: `select rater_user_id` is denied or
  empty), P1.5 (no function output column mentions a rater). Expected to PASS on a database matching the repo; a FAIL is a live drift and a proven gap for a follow-up migration.

## 6. Mapping Ratings F1/F2 client actions to server paths
| Client action | Server path |
|---|---|
| Show dimensions/tags to pick | `rpc_list_rating_dimensions()` |
| Who is left to rate for game G | `rpc_get_unrated_coplayers(G)` |
| Submit rating | `rpc_rate_user(...)` (gaps in 1.2 apply) |
| Already rated this person? | absent from the unrated list; submit returns `already_rated` |
| Show someone's rating | `rpc_get_user_rating_aggregate(u)`: row only past the threshold; no row means "not enough ratings yet" |

## 7. Evidence and rollback
Migration `supabase/migrations/20261027120000_kan664_ratings_read_paths.sql` (additive, three functions, EXECUTE to `authenticated` only, no PUBLIC/anon).
Probes `supabase/tests/kan664_ratings_b1/probes.sql` (one BEGIN..ROLLBACK). Rollback `supabase/tests/kan664_ratings_b1/rollback.sql` drops only the three functions.
The SQL has not been executed anywhere (no local Postgres, `execute_sql` refused for this team); Operations applies it and runs the probes.
