-- KAN-967 (backend half): public.active_stream gains the trending, honour and venue-rating event types the Active
-- cards (ActivityCard.dc.html) already render. The 18 KAN-964 columns stay first and in order; 10 columns are
-- appended, NULL on every pre-existing row:
--   metric_kind text, metric_value numeric, period_start date, stats jsonb ([{key,value}]), rating numeric,
--   rating_count int, photo_url text, quote text, rated_game_at timestamptz, venue_rating_avg numeric.
-- New event types (exact strings the client maps in ActiveType / ActiveLook):
--   trending_sport    entity_kind 'sport', entity_id sports.id. Per areas.city: non-cancelled events.event_type='game'
--                     with start_at in [now-7d, now) vs [now-14d, now-7d). growth = (now-prev)*100/prev, 1 dp;
--                     prev = 0 counts as growth 100. Kept: >= 3 games this week AND growth >= 10; at most 2 per
--                     city (growth desc, games desc, sport id). metric_kind 'games_growth_pct', metric_value growth.
--                     event_at = today 00:00 Asia/Dubai. title sports.name_en (sport_names_en/ar filled).
--   trending_hashtag  entity_kind 'hashtag', entity_id hashtags.id. Per posts.posted_from_city: distinct posts the
--                     VIEWER can see (can_view_post, not deleted, not admin-hidden, author not blocked) that carry
--                     the hashtag, posted on today's Asia/Dubai date; a city with none today uses yesterday.
--                     Banned or unapproved hashtags excluded. At most 2 per city (count desc, hashtag id).
--                     metric_kind 'posts_today' | 'posts_yesterday', metric_value the post count.
--                     title '#'||COALESCE(display_tag, tag); detail hashtags.slug. event_at = today 00:00 Dubai.
--   player_week       entity_kind 'profile', entity_id = actor_profile_id = the winner's profile. The last
--   player_month      COMPLETED ISO week (Mon..Mon) / calendar month in Asia/Dubai. Games = distinct non-cancelled
--                     games with end_at in the period where the player's game_roster row is status 'active' and
--                     role player|host. score = games x avg(stars) of ratings target_type 'user' received for those
--                     games (context_id = the game or its event; flagged excluded); no rating = neutral 3.0
--                     (midpoint of 1..5). >= 3 games; one winner per lower(profiles.city), ranked among personal,
--                     publicly visible profiles (score, games, hosted, id). stats exactly games, rating (the avg, or
--                     3.0 when none), hosted (events created by the profile that ended in the period). rating /
--                     rating_count = the real avg (NULL when none) and count. period_start = the Monday / the 1st;
--                     event_at = end of the period (00:00 Dubai of the next Monday / 1st). No MVP or wins figure.
--   venue_week        entity_kind 'venue'. Same periods. games = non-cancelled game events at events.venue_id that
--   venue_month       ended in the period (>= 1). One per lower(areas.city) among active venues (games desc,
--                     venues.rating desc nulls last, id). stats bookings (confirmed venue_bookings starting in the
--                     period on the venue's spaces), games, rating (venues.rating; omitted when NULL). rating /
--                     rating_count from venues, photo_url = first venue_photos by sort_order, space_count as before.
--   venue_rating      entity_kind 'venue', entity_id the venue. Source venue_rating_events (the table
--                     rpc_rate_venue writes; ratings has no venue writer and is empty). event_at = created_at,
--                     actor = rater profile, rating = mean of the rater's numeric dimension scores (1 dp),
--                     venue_rating_avg / rating_count = venue_rating_aggregate composite_score / event_count,
--                     quote = comment, rated_game_at = the rated game's start_at. The existing dedupe on
--                     (event_type, entity_id) keeps the newest rating per venue.
--   venue_day         NOT emitted (CEO 2026-11-16: a paid placement later).
-- Visibility as the existing branches: a signed-in viewer only; profiles publicly visible (is_profile_publicly_visible)
-- and not blocked; venues active and their owner not blocked. Honours are ranked on global data and the block
-- filter is applied after ranking, so a blocked winner hides that card instead of promoting a runner-up.
-- Dedupe: the DISTINCT ON order gains a tiebreak (metric_value desc, city) so a sport or hashtag trending in two
-- cities resolves deterministically when no city filter is set; old types are unique per (event_type, entity_id), so
-- their rows are unaffected (asserted below on a real viewer's page 1).
-- Body re-authored from the live pg_get_functiondef (pre-image md5 2aa91bfcd8cf0380a6d4de31beccd01f guarded).
-- Return type change => DROP + CREATE; owner, SECURITY DEFINER, search_path, comment and the pre-image ACL
-- (postgres, authenticated, service_role; no PUBLIC, no anon) are restored and asserted.
-- Callers: lib/ via SupabaseConfig.activeStreamRpc (PostgREST); no SQL function or view references active_stream.
-- Applied under G-002 by backend-3.

CREATE TEMP TABLE _kan967_snap (viewer uuid, n int, digest text) ON COMMIT DROP;

DO $pre$
DECLARE v_md5 text; v_acl text[]; v_viewer uuid;
BEGIN
  SELECT md5(pg_get_functiondef(p.oid)), (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x)
    INTO v_md5, v_acl
    FROM pg_proc p WHERE p.oid = 'public.active_stream(text[],text,integer,timestamptz,text,uuid)'::regprocedure;
  IF v_md5 IS DISTINCT FROM '2aa91bfcd8cf0380a6d4de31beccd01f' THEN
    RAISE EXCEPTION 'KAN-967 pre-image md5 mismatch: %', v_md5;
  END IF;
  IF v_acl IS DISTINCT FROM ARRAY['authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres'] THEN
    RAISE EXCEPTION 'KAN-967 pre-image ACL mismatch: %', v_acl;
  END IF;

  -- Snapshot page 1 (50 rows, 18 columns) for a real viewer, to prove the old types are unchanged after the swap.
  SELECT pr.user_id INTO v_viewer FROM public.profiles pr
   WHERE pr.profile_type = 'personal' AND pr.user_id IS NOT NULL ORDER BY pr.created_at, pr.id LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_viewer, 'role', 'authenticated')::text, true);
  INSERT INTO _kan967_snap
  SELECT v_viewer, count(*), md5(COALESCE(string_agg(s::text, '|' ORDER BY s.event_at DESC, s.event_type DESC, s.entity_id DESC), ''))
    FROM public.active_stream(NULL, NULL, 50) s;
END
$pre$;

DROP FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid);

CREATE FUNCTION public.active_stream(p_event_types text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_type text DEFAULT NULL::text, p_before_entity uuid DEFAULT NULL::uuid)
 RETURNS TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text,
               actor_display_name text, actor_avatar_url text, detail text, start_at timestamp with time zone, end_at timestamp with time zone,
               is_live boolean, sport_names_en text[], sport_names_ar text[],
               participant_count integer, capacity integer, space_count integer,
               metric_kind text, metric_value numeric, period_start date, stats jsonb, rating numeric, rating_count integer,
               photo_url text, quote text, rated_game_at timestamp with time zone, venue_rating_avg numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH prm AS (
    SELECT auth.uid() AS viewer,
           LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50) AS lim,
           NULLIF(btrim(p_city), '') AS city
  ),
  ev0 AS (
    -- player_joined
    SELECT 'player_joined'::text AS event_type, p.created_at AS event_at, 'profile'::text AS entity_kind,
           p.id AS entity_id, p.id AS actor_profile_id, p.city AS city, p.display_name AS title,
           NULL::text AS detail, NULL::timestamptz AS start_at, NULL::timestamptz AS end_at, NULL::uuid AS sport_id
      FROM public.profiles p, prm
     WHERE prm.viewer IS NOT NULL
       AND p.profile_type = 'personal'
       AND p.created_at IS NOT NULL
       AND public.is_profile_publicly_visible(p.id)
       AND NOT public.is_blocked(prm.viewer, p.user_id)
    UNION ALL
    -- venue_added
    SELECT 'venue_added'::text, v.created_at, 'venue'::text, v.id, NULL::uuid, a.city, v.name_en,
           a.name, NULL::timestamptz, NULL::timestamptz, NULL::uuid
      FROM public.venues v
      JOIN public.areas a ON a.id = v.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND v.is_active = true
       AND (v.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, v.owner_user_id))
    UNION ALL
    -- game_created
    SELECT 'game_created'::text, e.created_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, e.end_at, e.sport_id
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, e.start_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, e.end_at, e.sport_id
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- game_ended
    SELECT 'game_ended'::text, e.end_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, e.end_at, e.sport_id
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.end_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_created
    SELECT 'meetup_created'::text, e.created_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, COALESCE(e.end_at, e.start_at), e.sport_id
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, e.start_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, COALESCE(e.end_at, e.start_at), e.sport_id
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_completed
    SELECT 'meetup_completed'::text, COALESCE(e.end_at, e.start_at), 'meetup'::text, m.id, e.creator_profile_id,
           a.city, e.title,
           COALESCE(vn.name_en, a.name), e.start_at, COALESCE(e.end_at, e.start_at), e.sport_id
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND COALESCE(e.end_at, e.start_at) <= now()
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
  ),
  -- KAN-967 BEGIN new branches -----------------------------------------------------------------------------------
  -- Asia/Dubai calendar: today 00:00, and the last completed ISO week and calendar month.
  clk AS (
    SELECT (date_trunc('day', now() AT TIME ZONE 'Asia/Dubai') AT TIME ZONE 'Asia/Dubai') AS today0,
           (now() AT TIME ZONE 'Asia/Dubai')::date AS today
  ),
  prd AS (
    SELECT k.kind, k.ps::date AS period_start,
           (k.ps AT TIME ZONE 'Asia/Dubai') AS ps_at, (k.pe AT TIME ZONE 'Asia/Dubai') AS pe_at
      FROM (SELECT 'week'::text AS kind,
                   date_trunc('week', now() AT TIME ZONE 'Asia/Dubai') - interval '7 days' AS ps,
                   date_trunc('week', now() AT TIME ZONE 'Asia/Dubai') AS pe
            UNION ALL
            SELECT 'month'::text,
                   date_trunc('month', now() AT TIME ZONE 'Asia/Dubai') - interval '1 month',
                   date_trunc('month', now() AT TIME ZONE 'Asia/Dubai')) k
  ),
  -- trending_sport: games per (area city, sport) this 7 days vs the previous 7.
  ts AS (
    SELECT a.city AS city, e.sport_id AS sport_id,
           count(*) FILTER (WHERE e.start_at >= now() - interval '7 days') AS n_now,
           count(*) FILTER (WHERE e.start_at <  now() - interval '7 days') AS n_prev
      FROM public.events e
      JOIN public.areas a ON a.id = e.area_id
     WHERE e.event_type = 'game'
       AND e.is_cancelled = false
       AND e.sport_id IS NOT NULL
       AND a.city IS NOT NULL
       AND e.start_at >= now() - interval '14 days'
       AND e.start_at <  now()
     GROUP BY a.city, e.sport_id
  ),
  tsr AS (
    SELECT ts.city, ts.sport_id, ts.n_now, gr.growth,
           row_number() OVER (PARTITION BY lower(ts.city) ORDER BY gr.growth DESC, ts.n_now DESC, ts.sport_id) AS rk
      FROM ts
      CROSS JOIN LATERAL (
        SELECT CASE WHEN ts.n_prev = 0 THEN 100::numeric
                    ELSE round((ts.n_now - ts.n_prev) * 100.0 / ts.n_prev, 1) END AS growth
      ) gr
     WHERE ts.n_now >= 3
       AND gr.growth >= 10
  ),
  -- trending_hashtag: viewer-visible posts per (posted_from_city, hashtag), today and yesterday (Dubai dates).
  th AS (
    SELECT p.posted_from_city AS city, ph.hashtag_id AS hashtag_id,
           count(DISTINCT p.id) FILTER (WHERE p.created_at >= clk.today0) AS n_today,
           count(DISTINCT p.id) FILTER (WHERE p.created_at <  clk.today0) AS n_yday
      FROM public.post_hashtags ph
      JOIN public.posts p ON p.id = ph.post_id
      JOIN public.hashtags h ON h.id = ph.hashtag_id, clk, prm
     WHERE prm.viewer IS NOT NULL
       AND p.created_at >= clk.today0 - interval '1 day'
       AND p.created_at <  clk.today0 + interval '1 day'
       AND NULLIF(btrim(p.posted_from_city), '') IS NOT NULL
       AND p.is_deleted IS NOT TRUE
       AND p.is_hidden_admin IS NOT TRUE
       AND h.is_banned IS NOT TRUE
       AND h.is_approved IS TRUE
       AND public.can_view_post(p.id, prm.viewer, NULL::uuid)
       AND NOT public.is_blocked(prm.viewer, p.author_user_id)
     GROUP BY p.posted_from_city, ph.hashtag_id
  ),
  thc AS (
    SELECT th.city, bool_or(th.n_today > 0) AS has_today FROM th GROUP BY th.city
  ),
  thr AS (
    SELECT th.city, th.hashtag_id, n.kind, n.n,
           row_number() OVER (PARTITION BY th.city ORDER BY n.n DESC, th.hashtag_id) AS rk
      FROM th
      JOIN thc ON thc.city = th.city
      CROSS JOIN LATERAL (
        SELECT CASE WHEN thc.has_today THEN 'posts_today' ELSE 'posts_yesterday' END::text AS kind,
               CASE WHEN thc.has_today THEN th.n_today ELSE th.n_yday END AS n
      ) n
     WHERE n.n > 0
  ),
  -- player_week / player_month: completed games per player in the period.
  hon_g AS (
    SELECT prd.kind, gr.profile_id, g.id AS game_id, e.id AS event_id
      FROM prd
      JOIN public.events e ON e.event_type = 'game' AND e.is_cancelled = false
                          AND e.end_at >= prd.ps_at AND e.end_at < prd.pe_at
      JOIN public.games g ON g.event_id = e.id
      JOIN public.game_roster gr ON gr.game_id = g.id AND gr.status = 'active' AND gr.role IN ('player', 'host')
  ),
  hon_p AS (
    SELECT hg.kind, hg.profile_id, count(DISTINCT hg.game_id)::int AS games,
           array_agg(DISTINCT hg.game_id) AS game_ids, array_agg(DISTINCT hg.event_id) AS event_ids
      FROM hon_g hg
     GROUP BY hg.kind, hg.profile_id
    HAVING count(DISTINCT hg.game_id) >= 3
  ),
  hon_ps AS (
    SELECT hp.kind, prd.period_start, prd.pe_at, hp.profile_id, pr.user_id, pr.city, pr.display_name,
           hp.games, rt.avg_stars, rt.n_ratings, hs.hosted,
           hp.games * COALESCE(rt.avg_stars, 3.0) AS score,
           row_number() OVER (PARTITION BY hp.kind, lower(pr.city)
                              ORDER BY hp.games * COALESCE(rt.avg_stars, 3.0) DESC, hp.games DESC, hs.hosted DESC,
                                       hp.profile_id) AS rk
      FROM hon_p hp
      JOIN prd ON prd.kind = hp.kind
      JOIN public.profiles pr ON pr.id = hp.profile_id
      LEFT JOIN LATERAL (
        SELECT avg(r.stars)::numeric AS avg_stars, count(*)::int AS n_ratings
          FROM public.ratings r
         WHERE r.target_type = 'user' AND r.target_user_id = pr.user_id
           AND r.context_type = 'game' AND r.is_flagged IS NOT TRUE
           AND (r.context_id = ANY (hp.game_ids) OR r.context_id = ANY (hp.event_ids))
      ) rt ON true
      LEFT JOIN LATERAL (
        SELECT count(*)::int AS hosted
          FROM public.events eh
         WHERE eh.event_type = 'game' AND eh.is_cancelled = false AND eh.creator_profile_id = hp.profile_id
           AND eh.end_at >= prd.ps_at AND eh.end_at < prd.pe_at
      ) hs ON true
     WHERE pr.profile_type = 'personal'
       AND NULLIF(btrim(pr.city), '') IS NOT NULL
       AND public.is_profile_publicly_visible(pr.id)
  ),
  -- venue_week / venue_month: games played at the venue in the period.
  hon_v AS (
    SELECT prd.kind, prd.period_start, prd.ps_at, prd.pe_at, v.id AS venue_id, a.city, a.name AS area_name,
           v.name_en, v.rating AS v_rating, v.rating_count AS v_rating_count, v.owner_user_id,
           count(DISTINCT e.id)::int AS games
      FROM prd
      JOIN public.events e ON e.event_type = 'game' AND e.is_cancelled = false AND e.venue_id IS NOT NULL
                          AND e.end_at >= prd.ps_at AND e.end_at < prd.pe_at
      JOIN public.venues v ON v.id = e.venue_id AND v.is_active = true
      JOIN public.areas a ON a.id = v.area_id
     WHERE a.city IS NOT NULL
     GROUP BY prd.kind, prd.period_start, prd.ps_at, prd.pe_at, v.id, v.name_en, v.rating, v.rating_count,
              v.owner_user_id, a.city, a.name
  ),
  hon_vr AS (
    SELECT hv.*,
           row_number() OVER (PARTITION BY hv.kind, lower(hv.city)
                              ORDER BY hv.games DESC, hv.v_rating DESC NULLS LAST, hv.venue_id) AS rk
      FROM hon_v hv
  ),
  ev AS (
    SELECT ev0.*,
           NULL::text AS metric_kind, NULL::numeric AS metric_value, NULL::date AS period_start, NULL::jsonb AS stats,
           NULL::numeric AS rating, NULL::int AS rating_count, NULL::text AS photo_url, NULL::text AS quote,
           NULL::timestamptz AS rated_game_at, NULL::numeric AS venue_rating_avg
      FROM ev0
    UNION ALL
    -- trending_sport
    SELECT 'trending_sport'::text, clk.today0, 'sport'::text, tsr.sport_id, NULL::uuid, tsr.city, s.name_en,
           NULL::text, NULL::timestamptz, NULL::timestamptz, tsr.sport_id,
           'games_growth_pct'::text, tsr.growth, NULL::date, NULL::jsonb,
           NULL::numeric, NULL::int, NULL::text, NULL::text, NULL::timestamptz, NULL::numeric
      FROM tsr
      JOIN public.sports s ON s.id = tsr.sport_id, clk, prm
     WHERE prm.viewer IS NOT NULL
       AND tsr.rk <= 2
    UNION ALL
    -- trending_hashtag
    SELECT 'trending_hashtag'::text, clk.today0, 'hashtag'::text, h.id, NULL::uuid, thr.city,
           '#' || COALESCE(NULLIF(btrim(h.display_tag), ''), h.tag),
           h.slug, NULL::timestamptz, NULL::timestamptz, NULL::uuid,
           thr.kind, thr.n::numeric, NULL::date, NULL::jsonb,
           NULL::numeric, NULL::int, NULL::text, NULL::text, NULL::timestamptz, NULL::numeric
      FROM thr
      JOIN public.hashtags h ON h.id = thr.hashtag_id, clk
     WHERE thr.rk <= 2
    UNION ALL
    -- player_week / player_month
    SELECT 'player_' || hps.kind, hps.pe_at, 'profile'::text, hps.profile_id, hps.profile_id, hps.city,
           hps.display_name, NULL::text, NULL::timestamptz, NULL::timestamptz, NULL::uuid,
           NULL::text, NULL::numeric, hps.period_start,
           jsonb_build_array(jsonb_build_object('key', 'games', 'value', hps.games),
                             jsonb_build_object('key', 'rating', 'value', round(COALESCE(hps.avg_stars, 3.0), 1)),
                             jsonb_build_object('key', 'hosted', 'value', hps.hosted)),
           round(hps.avg_stars, 1), hps.n_ratings, NULL::text, NULL::text, NULL::timestamptz, NULL::numeric
      FROM hon_ps hps, prm
     WHERE prm.viewer IS NOT NULL
       AND hps.rk = 1
       AND NOT public.is_blocked(prm.viewer, hps.user_id)
    UNION ALL
    -- venue_week / venue_month
    SELECT 'venue_' || hvr.kind, hvr.pe_at, 'venue'::text, hvr.venue_id, NULL::uuid, hvr.city, hvr.name_en,
           hvr.area_name, NULL::timestamptz, NULL::timestamptz, NULL::uuid,
           NULL::text, NULL::numeric, hvr.period_start,
           jsonb_build_array(jsonb_build_object('key', 'bookings', 'value', bk.n),
                             jsonb_build_object('key', 'games', 'value', hvr.games))
             || CASE WHEN hvr.v_rating IS NULL THEN '[]'::jsonb
                     ELSE jsonb_build_array(jsonb_build_object('key', 'rating', 'value', hvr.v_rating)) END,
           hvr.v_rating, hvr.v_rating_count, ph.url, NULL::text, NULL::timestamptz, NULL::numeric
      FROM hon_vr hvr
      CROSS JOIN LATERAL (
        SELECT count(*)::int AS n
          FROM public.venue_bookings vb
          JOIN public.venue_spaces vs ON vs.id = vb.venue_space_id
         WHERE vs.venue_id = hvr.venue_id AND vb.status = 'confirmed'
           AND vb.starts_at >= hvr.ps_at AND vb.starts_at < hvr.pe_at
      ) bk
      LEFT JOIN LATERAL (
        SELECT vp.url FROM public.venue_photos vp
         WHERE vp.venue_id = hvr.venue_id
         ORDER BY vp.sort_order NULLS LAST, vp.created_at, vp.id
         LIMIT 1
      ) ph ON true, prm
     WHERE prm.viewer IS NOT NULL
       AND hvr.rk = 1
       AND (hvr.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, hvr.owner_user_id))
    UNION ALL
    -- venue_rating
    SELECT 'venue_rating'::text, vre.created_at, 'venue'::text, v.id, vre.rater_profile_id, a.city, v.name_en,
           a.name, NULL::timestamptz, NULL::timestamptz, NULL::uuid,
           NULL::text, NULL::numeric, NULL::date, NULL::jsonb,
           (SELECT round(avg((j.value #>> '{}')::numeric), 1)
              FROM jsonb_each(vre.scores) j WHERE jsonb_typeof(j.value) = 'number'),
           vra.event_count, NULL::text, vre.comment, eg.start_at, vra.composite_score
      FROM public.venue_rating_events vre
      JOIN public.venues v ON v.id = vre.venue_id
      JOIN public.areas a ON a.id = v.area_id
      LEFT JOIN public.venue_rating_aggregate vra ON vra.venue_id = v.id
      LEFT JOIN public.games gm ON gm.id = vre.game_id
      LEFT JOIN public.events eg ON eg.id = gm.event_id, prm
     WHERE prm.viewer IS NOT NULL
       AND v.is_active = true
       AND (v.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, v.owner_user_id))
       AND public.is_profile_publicly_visible(vre.rater_profile_id)
       AND NOT public.is_blocked(prm.viewer, vre.rater_user_id)
  ),
  -- KAN-967 END new branches -------------------------------------------------------------------------------------
  filtered AS (
    SELECT DISTINCT ON (ev.event_type, ev.entity_id) ev.*
      FROM ev, prm
     WHERE (p_event_types IS NULL OR ev.event_type = ANY (p_event_types))
       AND (prm.city IS NULL OR lower(ev.city) = lower(prm.city))
       AND (
         p_before IS NULL
         OR ev.event_at < p_before
         OR (p_before_type IS NOT NULL AND p_before_entity IS NOT NULL
             AND ev.event_at = p_before
             AND (ev.event_type, ev.entity_id) < (p_before_type, p_before_entity))
       )
     ORDER BY ev.event_type, ev.entity_id, ev.event_at DESC, ev.metric_value DESC NULLS LAST, ev.city  -- KAN-967 tiebreak
  ),
  page AS (
    SELECT f.*
      FROM filtered f
     ORDER BY f.event_at DESC, f.event_type DESC, f.entity_id DESC
     LIMIT (SELECT lim FROM prm)
  )
  SELECT pg.event_type, pg.event_at, pg.entity_kind, pg.entity_id, pg.actor_profile_id, pg.city, pg.title,
         ap.display_name, ap.avatar_url,
         pg.detail, pg.start_at, pg.end_at,
         COALESCE(pg.entity_kind IN ('game', 'meetup') AND pg.start_at <= now() AND now() < pg.end_at, false),
         COALESCE(sp.en, '{}'::text[]), COALESCE(sp.ar, '{}'::text[]),
         cn.participant_count, cn.capacity, cn.space_count,  -- KAN-964
         pg.metric_kind, pg.metric_value, pg.period_start, pg.stats, pg.rating, pg.rating_count,  -- KAN-967
         pg.photo_url, pg.quote, pg.rated_game_at, pg.venue_rating_avg                             -- KAN-967
    FROM page pg
    LEFT JOIN public.profiles ap ON ap.id = pg.actor_profile_id
    LEFT JOIN LATERAL (
      SELECT array_agg(s.name_en ORDER BY s.name_en, s.id) AS en,
             array_agg(s.name_ar ORDER BY s.name_en, s.id) AS ar
        FROM public.sports s
       WHERE (pg.entity_kind IN ('game', 'meetup') AND s.id = pg.sport_id)
          OR (pg.entity_kind = 'sport' AND s.id = pg.entity_id)  -- KAN-967
          OR (pg.entity_kind = 'venue'
              AND (EXISTS (SELECT 1 FROM public.venue_spaces vs WHERE vs.venue_id = pg.entity_id AND vs.sport_id = s.id)
                   OR EXISTS (SELECT 1 FROM public.venues v WHERE v.id = pg.entity_id AND s.sport_key = ANY (v.sports))))
          OR (pg.entity_kind = 'profile'
              AND EXISTS (SELECT 1 FROM public.profiles pp
                           WHERE pp.id = pg.entity_id
                             AND (s.id = pp.primary_sport OR s.id = pp.preferred_sport OR s.id = ANY (pp.interests))))
    ) sp ON true
    -- KAN-964: Active card counts, resolved only for the page rows (<= 50; index lookups, no full aggregate).
    --   game:   active roster, players plus a hosted/casual host (KAN-934 rule, as v_game_card.roster_count);
    --           for game_ended this is the final roster.
    --   meetup: RSVPs with status 'going' (the host's own RSVP included, as the seeding RPCs count it).
    --   capacity: events.capacity for game/meetup (NULL when open). space_count: active venue_spaces.
    LEFT JOIN LATERAL (
      SELECT CASE pg.entity_kind
               WHEN 'game' THEN (SELECT count(*)::int FROM public.game_roster gr
                                  WHERE gr.game_id = pg.entity_id AND gr.status = 'active'
                                    AND (gr.role = 'player' OR (gr.role = 'host' AND ec.game_type IN ('hosted', 'casual'))))
               WHEN 'meetup' THEN (SELECT count(*)::int FROM public.meetup_rsvps mr
                                    WHERE mr.meetup_id = pg.entity_id AND mr.status = 'going')
             END AS participant_count,
             ec.capacity AS capacity,
             CASE WHEN pg.entity_kind = 'venue'
                  THEN (SELECT count(*)::int FROM public.venue_spaces vsc
                         WHERE vsc.venue_id = pg.entity_id AND vsc.is_active)
             END AS space_count
        FROM (SELECT 1) dflt
        LEFT JOIN LATERAL (
          SELECT e2.capacity, g2.game_type
            FROM public.games g2 JOIN public.events e2 ON e2.id = g2.event_id AND e2.event_type = 'game'
           WHERE pg.entity_kind = 'game' AND g2.id = pg.entity_id
          UNION ALL
          SELECT e2.capacity, NULL::text
            FROM public.meetups m2 JOIN public.events e2 ON e2.id = m2.event_id AND e2.event_type = 'meetup'
           WHERE pg.entity_kind = 'meetup' AND m2.id = pg.entity_id
        ) ec ON true
    ) cn ON true
   ORDER BY pg.event_at DESC, pg.event_type DESC, pg.entity_id DESC;
$function$;

ALTER FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.active_stream(text[], text, integer, timestamptz, text, uuid) IS
  'KAN-595 Active stream: player_joined, venue_added, game_created/started/ended, meetup_created/started/completed; newest first; viewer-visible, block-filtered; selected-city text filter, no location. KAN-957: + actor_display_name, actor_avatar_url, detail, start_at, end_at, is_live, sport_names_en, sport_names_ar. KAN-964: + participant_count, capacity, space_count. KAN-967: + trending_sport, trending_hashtag, player_week, player_month, venue_week, venue_month, venue_rating; + metric_kind, metric_value, period_start, stats, rating, rating_count, photo_url, quote, rated_game_at, venue_rating_avg.';

DO $post$
DECLARE r record; s record; v_n int; v_digest text;
BEGIN
  SELECT pg_get_userbyid(p.proowner) AS owner, p.prosecdef, p.proconfig, p.provolatile,
         (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x) AS acl,
         pg_get_function_result(p.oid) AS res
    INTO r
    FROM pg_proc p WHERE p.oid = 'public.active_stream(text[],text,integer,timestamptz,text,uuid)'::regprocedure;
  IF r.owner <> 'postgres' OR NOT r.prosecdef OR r.provolatile <> 's'
     OR r.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     OR r.acl IS DISTINCT FROM ARRAY['authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres']
     OR has_function_privilege('anon', 'public.active_stream(text[],text,integer,timestamptz,text,uuid)', 'EXECUTE')
     OR r.res <> 'TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text, actor_display_name text, actor_avatar_url text, detail text, start_at timestamp with time zone, end_at timestamp with time zone, is_live boolean, sport_names_en text[], sport_names_ar text[], participant_count integer, capacity integer, space_count integer, metric_kind text, metric_value numeric, period_start date, stats jsonb, rating numeric, rating_count integer, photo_url text, quote text, rated_game_at timestamp with time zone, venue_rating_avg numeric)' THEN
    RAISE EXCEPTION 'KAN-967 post-image mismatch: owner=% secdef=% vol=% cfg=% acl=% res=%',
      r.owner, r.prosecdef, r.provolatile, r.proconfig, r.acl, r.res;
  END IF;

  -- Page 1 of the old types, 18 columns, for the same viewer: byte-identical to the pre-image snapshot.
  SELECT * INTO s FROM _kan967_snap;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', s.viewer, 'role', 'authenticated')::text, true);
  SELECT count(*), md5(COALESCE(string_agg(
           ROW(x.event_type, x.event_at, x.entity_kind, x.entity_id, x.actor_profile_id, x.city, x.title,
               x.actor_display_name, x.actor_avatar_url, x.detail, x.start_at, x.end_at, x.is_live,
               x.sport_names_en, x.sport_names_ar, x.participant_count, x.capacity, x.space_count)::text,
           '|' ORDER BY x.event_at DESC, x.event_type DESC, x.entity_id DESC), ''))
    INTO v_n, v_digest
    FROM public.active_stream(ARRAY['player_joined','venue_added','game_created','game_started','game_ended',
                                    'meetup_created','meetup_started','meetup_completed'], NULL, 50) x;
  IF v_n IS DISTINCT FROM s.n OR v_digest IS DISTINCT FROM s.digest OR s.n = 0 THEN
    RAISE EXCEPTION 'KAN-967 old-type page 1 changed: pre n=% md5=% post n=% md5=%', s.n, s.digest, v_n, v_digest;
  END IF;
  PERFORM set_config('request.jwt.claims', '', true);
END
$post$;
