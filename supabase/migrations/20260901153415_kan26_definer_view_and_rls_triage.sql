-- KAN-26: SECURITY DEFINER view sweep (Part 1) + RLS no-policy triage (Part 2)
-- Author: backend-owner, 2026-09-01. NOT APPLIED — per G-002, only cto/PO applies.
--
-- ============================================================================
-- PART 1 — anon-exposed SECURITY DEFINER-style views: NO NEW FIX NEEDED
-- ============================================================================
-- Re-ran the ticket's enumeration live against wtncuzcskpigqpmnxwws (2026-09-01).
-- All 19 named views were re-checked. First pass used a buggy catalogue query
-- (`'security_invoker=true' = any(reloptions)` — wrong spelling; Postgres
-- stores the reloption as `security_invoker=on`, not `=true`) that produced
-- false "still open" positives for v_comments, v_circle_feed, v_meetup_counts,
-- v_user_reputation, v_notifications_feed/_ranked. Caught before authoring
-- anything by re-reading raw `reloptions` and then empirically probing every
-- candidate as `anon` via `set local role anon` (never trust the catalogue
-- flag alone — see backend-owner memory rls-policy-count-is-not-permission).
--
-- Corrected, empirically-verified state, all 19:
--   v_mod_queue_open, v_safety_overview, v_user_badges_summary, v_game_rating,
--   v_challenge_standings: no longer anon-selectable at all (table grant
--   revoked). Closed, matches docs/SCHEMA.md.
--   v_space_slots_today: security_invoker=on (KAN-104). Closed.
--   v_post_comments: renamed away entirely (task18_rename_post_comments_to_comments);
--   superseded by `comments` (base table) + `v_comments` (view).
--   v_comments, v_circle_feed, v_user_reputation, v_meetup_counts,
--   v_notifications_feed, v_notifications_ranked: all have
--   `reloptions = {security_invoker=on}` live. Probed as anon:
--     - v_user_reputation: 0 rows.
--     - v_meetup_counts: 0 rows.
--     - v_comments as anon: `permission denied for table profiles` (anon has
--       no SELECT grant on profiles; the view's LEFT JOIN profiles fails
--       closed rather than returning an empty set — a robustness wart, not a
--       leak). As authenticated: 66 rows, matching docs/SCHEMA.md's earlier
--       "67 -> 66" count exactly.
--     - v_circle_feed as anon: also `permission denied for table profiles`,
--       despite v_circle_feed's own SELECT list never referencing `profiles`.
--       Traced to `circle_member_count(uuid)`: it is `SECURITY DEFINER` but
--       `LANGUAGE sql` and trivially simple, so Postgres's planner is free to
--       *inline* it into the calling query — and an inlined SQL function does
--       NOT run with the definer's privileges, it runs as whatever role is
--       executing the outer query. That's why its internal
--       `profiles`-referencing subquery is evaluated as `anon` and denied.
--       The net effect today is safe (fails closed — anon gets an error, not
--       data), but the `SECURITY DEFINER` marking on `circle_member_count` is
--       not reliably doing what its name promises; noted in docs/SCHEMA.md as
--       a documentation finding, not fixed here (fixing it would mean forcing
--       non-inlining, e.g. `LANGUAGE plpgsql`, which is a function-body change
--       outside this ticket's view-sweep scope — filed as a follow-up note,
--       not a new ticket, since nothing is currently exploitable).
--     - v_notifications_feed / v_notifications_ranked: notification-domain
--       views (table `notifications`) — NOT probed/fixed by this migration,
--       out of this agent's ownership per CONTRACT.md. Flagged to
--       notifications-specialist directly; see the KAN-26 Jira comment.
--   v_potential_vibes_default, v_recreate_quickpicks: `reloptions IS NULL`
--   (security_invoker is a documented no-op here — both are function-backed,
--   `FROM a_set_returning_function(...)`, not a table read; the invoker flag
--   only governs table/view access checks inside the view, and there are none
--   to govern). Probed as anon: 0 rows for both — the wrapped functions
--   (`rpc_potential_vibes`, `rpc_recreate_suggestions`) already gate on auth
--   internally. Matches docs/SCHEMA.md T-027 exactly.
--   username_registry_public, geography_columns, geometry_columns: unchanged,
--   intentionally public per T-027 / PostGIS system views.
--
-- Conclusion: Part 1 requires no new migration. Every one of the 19 named
-- views already carries a verified verdict, live-reconfirmed today. This
-- migration makes no view/grant changes for Part 1.
--
-- ============================================================================
-- PART 2 — 30 tables with RLS enabled + zero policies (deny-all triage)
-- ============================================================================
-- Fresh live re-enumeration (2026-09-01) confirms exactly 30 tables still
-- match `rls_enabled = true AND policy_count = 0`:
--   admins, app_admins, blackouts, challenge_fixtures, challenge_invites,
--   challenge_squads, challenge_stages, challenge_types, content_drafts,
--   context_rating_config, game_invites, game_link_tokens, games,
--   meetup_invites, meetup_link_tokens, moderation_ban_terms,
--   moderation_tickets, reputation_config, reuse_fingerprints,
--   reuse_user_stats, safety_blocklist_terms, safety_takedowns,
--   space_slot_holds, squad_invites, squad_join_requests, squad_link_tokens,
--   squad_members, surface_catalog, user_hidden_modes, vibes_reco_config.
--
-- 28 of 30: at least one live `SECURITY DEFINER` function body references the
-- table (checked via pg_proc.prosrc ILIKE '%tablename%' — a population count,
-- not an advisor guess, per T-020). Reached only through vetted RPCs;
-- deny-all-at-the-table is the intended shape. No policy added; documented in
-- docs/SCHEMA.md instead. `games` in particular: 38 definer-function
-- references confirm the RPC path is real and live (rpc_create_game,
-- rpc_join_game, v_game_card, find_slots, etc.) — but `games` ALSO has a
-- direct-table `GamesRepository`/`games_repository_impl.dart` in
-- lib/features/games (~15.5k LOC across the slice) that is never imported by
-- any provider or screen (grepped lib/ for the class/file name — zero
-- callers, not in lib/providers.dart). That code is dead, not
-- dead-and-broken: nothing live exercises the direct-table path this
-- deny-all would break, because nothing live calls it. Left as-is; a
-- dead-code removal call belongs to KAN-31/32 or master-analyst, not this
-- ticket.
--
-- 2 of 30 are a genuine gap, not an intentional RPC-only lock:
--   `challenge_types` (8 seed rows) and `surface_catalog` (30 seed rows).
-- Both are static, read-only reference/catalog tables (challenge type labels,
-- court surface labels) — the same shape as `sports`/`sport_variants`, which
-- already carry a `<table>_read_active` SELECT policy + `<table>_no_write`
-- deny-all policy pair. Zero SECURITY DEFINER functions and zero Dart callers
-- reference either table today, but the table-level GRANTs already present
-- for anon/authenticated (pre-KAN-67) show the intent was public read —
-- nobody added the RLS policy after enabling RLS, so today literally nothing,
-- not even an admin RPC, can read seeded catalog data that exists to be read.
-- Fixed below using the sports/sport_variants pattern exactly.

DROP POLICY IF EXISTS challenge_types_read_active ON public.challenge_types;
CREATE POLICY challenge_types_read_active ON public.challenge_types
  FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS challenge_types_no_write ON public.challenge_types;
CREATE POLICY challenge_types_no_write ON public.challenge_types
  FOR ALL USING (false) WITH CHECK (false);

-- surface_catalog has no is_active column — all 30 seed rows are live labels.
DROP POLICY IF EXISTS surface_catalog_read ON public.surface_catalog;
CREATE POLICY surface_catalog_read ON public.surface_catalog
  FOR SELECT USING (true);
DROP POLICY IF EXISTS surface_catalog_no_write ON public.surface_catalog;
CREATE POLICY surface_catalog_no_write ON public.surface_catalog
  FOR ALL USING (false) WITH CHECK (false);

-- ============================================================================
-- VERIFICATION (run after apply, as anon/authenticated via `set local role`)
-- ============================================================================
-- set local role anon;
--   select count(*) from challenge_types;  -- expect: 8 rows (was: permission denied)
--   select count(*) from surface_catalog;  -- expect: 30 rows (was: permission denied)
--   insert into challenge_types (key, label_en) values ('x','x'); -- expect: denied (RLS)
-- reset role;
-- set local role authenticated;
--   select count(*) from challenge_types;  -- expect: 8 rows
--   select count(*) from surface_catalog;  -- expect: 30 rows
-- reset role;
