-- KAN-87 (MEDIUM), Commit 2 of 2 — DO NOT APPLY BEFORE COMMIT 1 LANDS.
--
-- v_game_card is deliberately anon-readable (SCHEMA.md §2f allowlist, T-034 --
-- legitimate pre-login surface). The defect is not that it's public; it's
-- that it carries creator_user_id, a raw auth.users UUID. Measured live
-- 2026-08-29: 217 rows to anon, 26 distinct creator_user_id values -- 26
-- users' auth identifiers readable with no account. creator_profile_id is
-- already selected alongside it and is the identifier the app should use.
--
-- SEQUENCING (T-017/KAN-87 ruling, do not re-litigate): Dart call sites move
-- to creator_profile_id FIRST (commit 1, flutter-feature-agent), verified
-- working, THEN this view redefinition ships (commit 2). Dropping the column
-- first turns the game_history_providers.dart:79-80 filter into silently
-- wrong results (a user sees someone else's games, or none of their own),
-- which is worse than the leak this closes. This migration must not be
-- applied until commit 1 is confirmed live on Canary.
--
-- creator_user_id stays in the view's internal SQL (is_creator computation,
-- the WHERE-clause ownership check, can_view_with_scope's third arg) -- it is
-- only dropped from the SELECT list, i.e. from what a caller can read.
-- auth.uid() is still compared server-side inside the view; that comparison
-- never leaves the server, so this is not a re-exposure.
--
-- security_invoker: v_game_card is not currently set to security_invoker
-- (reloptions is NULL -- confirmed live) and this migration does not add it.
-- Leaving it off is deliberate here, unlike v_notifications_feed/ranked and
-- v_comments -- this view is meant to be broadly anon-readable pre-login
-- surface, not scoped to a caller's own rows. CREATE OR REPLACE VIEW resets
-- reloptions to their default regardless of what's specified, so the
-- pre/post state (both NULL, i.e. off) is unchanged by this migration --
-- verify that continuity below, not just that the column is gone.
--
-- G-002: authored by backend-owner, NOT applied here. cto applies after (a)
-- confirming commit 1 is live and confirmed on Canary, (b) measuring
-- preconditions live, and posting verification back to KAN-87.

CREATE OR REPLACE VIEW public.v_game_card AS
 SELECT g.id,
    g.title,
    g.game_type,
    g.start_at,
    g.end_at,
    g.capacity,
    g.bench_slots,
    g.capacity + g.bench_slots AS total_slots,
    g.min_skill,
    g.max_skill,
    g.listing_visibility,
    g.join_policy,
    g.allow_spectators,
    g.allows_waitlist,
    g.is_cancelled,
    g.rules,
    g.created_at,
    g.updated_at,
    g.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    g.sport_variant_id,
    sv.variant_key,
    sv.name_en AS variant_name_en,
    sv.name_ar AS variant_name_ar,
    sv.required_players,
    sv.players_per_side,
    g.creator_profile_id,
    cp.username AS creator_username,
    cp.display_name AS creator_display_name,
    cp.avatar_url AS creator_avatar_url,
    g.geo_location_id,
    g.area_id,
    a.name AS area_name,
    g.venue_space_id,
    g.venue_id,
    vs.name_en AS venue_space_name,
    v.name_en AS venue_name,
    g.joining_rule,
    g.cost_cover,
    ( SELECT count(*) AS count
           FROM game_roster gr
          WHERE gr.game_id = g.id AND gr.status = 'active'::text) AS roster_count,
    g.creator_user_id = auth.uid() AS is_creator,
    (EXISTS ( SELECT 1
           FROM game_roster grv
          WHERE grv.game_id = g.id AND grv.user_id = auth.uid() AND grv.status = 'active'::text)) AS is_joined
   FROM games g
     LEFT JOIN sports s ON s.id = g.sport_id
     LEFT JOIN sport_variants sv ON sv.id = g.sport_variant_id
     LEFT JOIN profiles cp ON cp.id = g.creator_profile_id
     LEFT JOIN areas a ON a.id = g.area_id
     LEFT JOIN venue_spaces vs ON vs.id = g.venue_space_id
     LEFT JOIN venues v ON v.id = COALESCE(vs.venue_id, g.venue_id)
  WHERE g.creator_user_id = auth.uid() OR is_admin(auth.uid()) OR (EXISTS ( SELECT 1
           FROM game_roster grm
          WHERE grm.game_id = g.id AND grm.user_id = auth.uid() AND grm.status = 'active'::text)) OR (EXISTS ( SELECT 1
           FROM game_waitlist gw
          WHERE gw.game_id = g.id AND gw.user_id = auth.uid())) OR can_view_with_scope(auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id);

-- ============================================================
-- VERIFICATION (run all, all must hold)
-- ============================================================
-- 0. PRECONDITION -- confirm commit 1 is live on Canary before applying this
--    at all: game_history_providers.dart, game_view_controller.dart and
--    game_model.dart all read creator_profile_id instead of creator_user_id
--    from this view, and game history for a user who both created and
--    joined games has been exercised in the running app (not just compiled).
--
-- 1. Column is gone from the view's output.
--    SELECT column_name FROM information_schema.columns
--    WHERE table_schema='public' AND table_name='v_game_card'
--      AND column_name = 'creator_user_id';
--    -- expect 0 rows
--
-- 2. creator_profile_id still present.
--    SELECT column_name FROM information_schema.columns
--    WHERE table_schema='public' AND table_name='v_game_card'
--      AND column_name = 'creator_profile_id';
--    -- expect 1 row
--
-- 3. Still anon-readable, same row count as before (217 measured 2026-08-29;
--    re-measure live immediately pre-apply, since games are created/expire
--    continuously -- a drop to 0 is a regression, not the fix).
--    SET LOCAL ROLE anon;
--    SELECT count(*) FROM public.v_game_card;
--
-- 4. reloptions unchanged by the CREATE OR REPLACE (both NULL = invoker off,
--    which is correct for this deliberately-public view).
--    SELECT reloptions FROM pg_class WHERE relname = 'v_game_card';
--    -- expect NULL, same as pre-apply
--
-- 5. docs/SCHEMA.md §2 updated to record that v_game_card exposes
--    creator_profile_id and deliberately not creator_user_id (T-002 CI gate).
