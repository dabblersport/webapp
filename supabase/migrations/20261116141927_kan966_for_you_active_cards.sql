-- KAN-966: "For you" returns posts and ranked Active cards merged server-side.
-- Applied under G-002 by backend-1 (Shu). Live test: supabase/tests/events_p4/kan966_for_you_active_cards_live_test.sql.
--
-- 1. public.home_feed_impressions (profile_id, entity_type, entity_id, first_seen_at), PK on the first three.
--    RLS: the owner (a profile of auth.uid()) reads and inserts only their own rows. No UPDATE/DELETE grant, and
--    INSERT is granted on (profile_id, entity_type, entity_id) only, so first_seen_at is always the server's now().
-- 2. public.rpc_mark_feed_impressions(p_items jsonb) -> integer (rows newly recorded). SECURITY INVOKER (RLS applies),
--    authenticated + service_role only. p_items = [{"entity_type":"game|meetup|venue|profile","entity_id":"<uuid>"}]
--    ("entity_kind" is accepted as an alias of "entity_type"). ON CONFLICT DO NOTHING: the first first_seen_at is kept.
-- 3. public.get_home_feed: DROP of the 4-arg signature + CREATE of ONE 6-arg function (no overload left), so the
--    2/3/4-arg named PostgREST calls still resolve. Body re-authored from the live pg_get_functiondef
--    (pre-image md5 4a5f31e4ac392587b35c3d76bed494ae, guarded). Post paths (push / pull / discovery, dedupe,
--    KAN-959/KAN-962 sport filters) are unchanged; the cursor is now applied after dedupe on the merged keyset
--    (live check: 0 feed_items rows whose created_at differs from public_activities.created_at, so the post set of
--    every legacy page is unchanged).
--    New optional params: p_cursor_id uuid, p_cursor_kind text ('post' | 'active').
--    New columns (NULL on posts unless stated): item_kind ('post' | 'active', never NULL), feed_at (never NULL),
--    cursor_id (never NULL), score, then the active_stream card columns: event_type, event_at, entity_kind, entity_id,
--    city, title, actor_display_name, actor_avatar_url, detail, start_at, end_at, is_live, sport_names_en,
--    sport_names_ar, participant_count, capacity, space_count. On an active row the legacy columns are:
--    activity_id = entity_id, activity_type = event_type, parent_activity_id NULL, actor_profile_id = card actor,
--    created_at = feed_at, seen_at = first_seen_at (NULL before the first impression), source = 'active'.
--    ACL: EXECUTE to authenticated and service_role only. The pre-image also granted PUBLIC and anon (which got an
--    empty result); KAN-966 requires anon to be denied, so PUBLIC and anon are deliberately not re-granted.
--
-- Candidates (viewer = the active persona: profiles of auth.uid() ordered is_active DESC, created_at, id):
--   game (game_created, or game_started once start_at <= now()), meetup (meetup_created / meetup_started),
--   venue_added (venue created in the last 30 days), player_joined (personal profile created in the last 14 days);
--   one row per entity. Around the viewer: the entity's city (areas.city; profiles.city for a player), normalised
--   (lower, trimmed, trailing " City" dropped), equals the viewer's normalised profiles.city or the city of an area
--   whose name/district equals it ("Bur Dubai" -> Dubai). In the viewer's interests (profiles.interests), always:
--   game/meetup sport, a venue's space sports or sport keys, a new player's primary/preferred/interests overlap.
--   Excluded: cancelled, finished (COALESCE(end_at, start_at) <= now()), full (capacity reached), already joined
--   (active game_roster row / 'going' RSVP of the viewer's user), created by the viewer, blocked either way,
--   not visible (_can_view_game / kan713_meetup_visible / is_profile_publicly_visible). p_sport_id / p_sport_ids
--   narrow the cards exactly as they narrow posts.
--
-- Score (0..100) = time + sport + distance + social + joinability:
--   time        game/meetup: live 35; starts within 48h 20 + 15 * (1 - hours_to_start / 48);
--               later max(0, 10 - days_to_start). player: 20 * max(0, 1 - age / 14d). venue: 20 * max(0, 1 - age / 30d).
--   sport       20 when a card sport is the viewer's primary_sport or preferred_sport, else 14 (interest match).
--   distance    15 same area (event/venue area is the viewer's area; player city equals the viewer city exactly),
--               else 10 (same city). No coordinates exist on profiles (0 of 189 rows), so there is no km term.
--   social      20 when the viewer follows the actor (host / new player); else 12 when the viewer follows a joined
--               participant (game roster or going RSVP) or, for a new player, the player follows the viewer; else 0.
--   joinability game/meetup: open (no capacity) 4; else 4 + 6 * participants / capacity (nearly full is higher).
--               player/venue 0.
--   Threshold: score < 40 is dropped. At most 30 cards per viewer.
--
-- Placement (deterministic for a given data state, so the keyset pages are stable):
--   Anchor posts are the visible rows (post, repost, news), numbered 1..N newest first.
--   Unseen card: desired anchor = 1 + floor((100 - score) / 4) (score 100 -> after post 1, 40 -> after post 16).
--   Seen card: its feed time is first_seen_at; desired anchor = number of anchor posts with created_at >=
--   first_seen_at, at least 1. It sinks with the posts and is never boosted again.
--   Spacing: cards ordered (desired, score DESC, entity) get assigned = max(desired, previous assigned + 1), so
--   one card per anchor, a post always sits between two cards, and the first item is a post. A card whose assigned
--   anchor is beyond N is not shown. A card sorts right after its anchor post.
--   Keyset on merged rows: ORDER BY feed_at DESC, cursor_id DESC, kind ASC (post 0, active 1). A post's key is
--   (created_at, activity_id, 0); a card's key is (anchor.created_at, anchor.activity_id, 1).
--   Next page: pass p_cursor = last row feed_at, p_cursor_id = last row cursor_id, p_cursor_kind = last row item_kind.
--   p_cursor without p_cursor_id keeps the legacy meaning (feed_at < p_cursor).
-- Duplicates: a game_create / meetup_create row whose event is shown as a card is dropped from the merged output.

DO $pre$
DECLARE v_md5 text; v_n int;
BEGIN
  SELECT md5(pg_get_functiondef(p.oid)) INTO v_md5
    FROM pg_proc p WHERE p.oid = 'public.get_home_feed(integer,timestamptz,uuid,uuid[])'::regprocedure;
  IF v_md5 IS DISTINCT FROM '4a5f31e4ac392587b35c3d76bed494ae' THEN
    RAISE EXCEPTION 'KAN-966 pre-image md5 mismatch: %', v_md5;
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'get_home_feed';
  IF v_n <> 1 THEN RAISE EXCEPTION 'KAN-966 expected one get_home_feed, found %', v_n; END IF;
  IF to_regclass('public.home_feed_impressions') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-966 public.home_feed_impressions already exists';
  END IF;
  IF to_regprocedure('public.rpc_mark_feed_impressions(jsonb)') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-966 public.rpc_mark_feed_impressions already exists';
  END IF;
END
$pre$;

-- 1. Impressions -------------------------------------------------------------------------------------------------
CREATE TABLE public.home_feed_impressions (
  profile_id    uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  entity_type   text        NOT NULL CHECK (entity_type IN ('game', 'meetup', 'venue', 'profile')),
  entity_id     uuid        NOT NULL,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (profile_id, entity_type, entity_id)
);
COMMENT ON TABLE public.home_feed_impressions IS
  'KAN-966: first time a viewer profile saw an Active card in For you. After it, the card sorts by first_seen_at.';

ALTER TABLE public.home_feed_impressions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.home_feed_impressions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.home_feed_impressions TO authenticated;
GRANT INSERT (profile_id, entity_type, entity_id) ON TABLE public.home_feed_impressions TO authenticated;
GRANT ALL ON TABLE public.home_feed_impressions TO service_role;

CREATE POLICY home_feed_impressions_owner_select ON public.home_feed_impressions
  FOR SELECT TO authenticated
  USING (profile_id IN (SELECT p.id FROM public.profiles p WHERE p.user_id = (SELECT auth.uid())));
CREATE POLICY home_feed_impressions_owner_insert ON public.home_feed_impressions
  FOR INSERT TO authenticated
  WITH CHECK (profile_id IN (SELECT p.id FROM public.profiles p WHERE p.user_id = (SELECT auth.uid())));

CREATE FUNCTION public.rpc_mark_feed_impressions(p_items jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_me  uuid;
  v_n   integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'auth_required';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'p_items must be a json array';
  END IF;
  IF jsonb_array_length(p_items) > 200 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'p_items has more than 200 items';
  END IF;

  -- The active persona, chosen exactly as get_home_feed chooses it.
  SELECT p.id INTO v_me
    FROM public.profiles p
   WHERE p.user_id = v_uid
   ORDER BY p.is_active DESC NULLS LAST, p.created_at ASC, p.id
   LIMIT 1;
  IF v_me IS NULL THEN RETURN 0; END IF;

  INSERT INTO public.home_feed_impressions (profile_id, entity_type, entity_id)
  SELECT DISTINCT v_me, t.et, t.eid::uuid
    FROM (SELECT COALESCE(x ->> 'entity_type', x ->> 'entity_kind') AS et, x ->> 'entity_id' AS eid
            FROM jsonb_array_elements(p_items) x
           WHERE jsonb_typeof(x) = 'object') t
   WHERE t.et IN ('game', 'meetup', 'venue', 'profile')
     AND t.eid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ON CONFLICT (profile_id, entity_type, entity_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$;

ALTER FUNCTION public.rpc_mark_feed_impressions(jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_mark_feed_impressions(jsonb) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_mark_feed_impressions(jsonb) TO authenticated, service_role;

-- 2. get_home_feed -----------------------------------------------------------------------------------------------
DROP FUNCTION public.get_home_feed(integer, timestamp with time zone, uuid, uuid[]);

CREATE FUNCTION public.get_home_feed(p_limit integer DEFAULT 50, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone, p_sport_id uuid DEFAULT NULL::uuid, p_sport_ids uuid[] DEFAULT NULL::uuid[], p_cursor_id uuid DEFAULT NULL::uuid, p_cursor_kind text DEFAULT NULL::text)
 RETURNS TABLE(activity_id uuid, activity_type text, parent_activity_id uuid, actor_profile_id uuid, created_at timestamp with time zone, seen_at timestamp with time zone, source text,
               item_kind text, feed_at timestamp with time zone, cursor_id uuid, score numeric,
               event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, city text, title text,
               actor_display_name text, actor_avatar_url text, detail text, start_at timestamp with time zone,
               end_at timestamp with time zone, is_live boolean, sport_names_en text[], sport_names_ar text[],
               participant_count integer, capacity integer, space_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
DECLARE
  v_my_uid         uuid := auth.uid();
  v_my_profile_id  uuid;
  v_city           text;
  v_interests      uuid[];
  v_primary        uuid;
  v_preferred      uuid;
  v_threshold      integer;
  v_ckind          integer;
BEGIN
  IF v_my_uid IS NULL THEN RETURN; END IF;

  -- Active persona (KAN-966): the active profile of the caller, oldest first.
  SELECT p.id, p.city, COALESCE(p.interests, '{}'::uuid[]), p.primary_sport, p.preferred_sport
    INTO v_my_profile_id, v_city, v_interests, v_primary, v_preferred
    FROM public.profiles p
   WHERE p.user_id = v_my_uid
   ORDER BY p.is_active DESC NULLS LAST, p.created_at ASC, p.id
   LIMIT 1;

  IF v_my_profile_id IS NULL THEN RETURN; END IF;

  IF p_cursor_kind IS NOT NULL AND p_cursor_kind NOT IN ('post', 'active') THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'p_cursor_kind must be post or active';
  END IF;
  v_ckind := CASE WHEN p_cursor_kind = 'active' THEN 1 ELSE 0 END;

  SELECT push_pull_threshold INTO v_threshold FROM public.feed_rank_config LIMIT 1;
  v_threshold := COALESCE(v_threshold, 1000);

  RETURN QUERY
  WITH blocked_profile_ids AS (
    SELECT p.id
    FROM public.profiles p
    JOIN public.user_blocks ub
      ON (ub.blocker_user_id = v_my_uid AND ub.blocked_user_id = p.user_id)
      OR (ub.blocked_user_id = v_my_uid AND ub.blocker_user_id = p.user_id)
  ),
  combined AS (
    -- Push path: pre-materialised rows for this recipient
    SELECT fi.activity_id, fi.activity_type, fi.parent_activity_id, fi.actor_profile_id, fi.created_at, fi.seen_at,
           1 AS path_priority, 'push'::text AS source
    FROM public.feed_items fi
    WHERE fi.recipient_profile_id = v_my_profile_id
      AND fi.hidden_at IS NULL
      AND fi.actor_profile_id NOT IN (SELECT id FROM blocked_profile_ids)
    UNION ALL
    -- Pull path: activities from high-follower users the caller follows
    SELECT pa.id, pa.activity_type, pa.parent_activity_id, pa.actor_profile_id, pa.created_at, NULL::timestamptz,
           2, 'pull'::text
    FROM public.public_activities pa
    WHERE pa.activity_type IN ('post', 'news', 'repost', 'game_create', 'meetup_create')
      AND NOT pa.is_deleted
      AND NOT pa.is_hidden_admin
      AND pa.actor_profile_id NOT IN (SELECT id FROM blocked_profile_ids)
      AND pa.actor_profile_id IN (
        SELECT pf.following_profile_id
        FROM public.profile_follows pf
        WHERE pf.follower_profile_id = v_my_profile_id
          AND (SELECT COUNT(*) FROM public.profile_follows
                WHERE following_profile_id = pf.following_profile_id) >= v_threshold)
    UNION ALL
    -- Discovery path: all recent public activities (ensures feed is never empty)
    SELECT pa.id, pa.activity_type, pa.parent_activity_id, pa.actor_profile_id, pa.created_at, NULL::timestamptz,
           3, 'discovery'::text
    FROM public.public_activities pa
    WHERE pa.activity_type IN ('post', 'news', 'repost', 'game_create', 'meetup_create')
      AND NOT pa.is_deleted
      AND NOT pa.is_hidden_admin
      AND pa.visibility = 'public'
      AND pa.actor_profile_id NOT IN (SELECT id FROM blocked_profile_ids)
  ),
  -- Deduplicate: keep highest-priority path per activity
  deduped AS (
    SELECT DISTINCT ON (c.activity_id)
      c.activity_id, c.activity_type, c.parent_activity_id, c.actor_profile_id, c.created_at, c.seen_at, c.source
    FROM combined c
    ORDER BY c.activity_id, c.path_priority ASC, c.created_at DESC
  ),
  posts AS (
    SELECT d.*
    FROM deduped d
    -- KAN-959 sport filter (NULL: every row). post: posts.id = activity_id; repost: posts.id = parent_activity_id;
    -- game_create / meetup_create: events.id = activity_id; news and anything else: dropped when filtering.
    WHERE (p_sport_id IS NULL
       OR (d.activity_type = 'post' AND EXISTS (
             SELECT 1 FROM public.posts po WHERE po.id = d.activity_id AND po.sport_id = p_sport_id))
       OR (d.activity_type = 'repost' AND EXISTS (
             SELECT 1 FROM public.posts po WHERE po.id = d.parent_activity_id AND po.sport_id = p_sport_id))
       OR (d.activity_type IN ('game_create', 'meetup_create') AND EXISTS (
             SELECT 1 FROM public.events e WHERE e.id = d.activity_id AND e.sport_id = p_sport_id)))
    -- KAN-962 "My sports": any of p_sport_ids. NULL: every row. '{}': no row.
      AND (p_sport_ids IS NULL
       OR (d.activity_type = 'post' AND EXISTS (
             SELECT 1 FROM public.posts po WHERE po.id = d.activity_id AND po.sport_id = ANY (p_sport_ids)))
       OR (d.activity_type = 'repost' AND EXISTS (
             SELECT 1 FROM public.posts po WHERE po.id = d.parent_activity_id AND po.sport_id = ANY (p_sport_ids)))
       OR (d.activity_type IN ('game_create', 'meetup_create') AND EXISTS (
             SELECT 1 FROM public.events e WHERE e.id = d.activity_id AND e.sport_id = ANY (p_sport_ids))))
  ),
  -- KAN-966: visible rows a card can follow, numbered newest first.
  anchors AS (
    SELECT po.activity_id AS a_id, po.created_at AS a_at,
           row_number() OVER (ORDER BY po.created_at DESC, po.activity_id DESC) AS ai
    FROM posts po
    WHERE po.activity_type IN ('post', 'repost', 'news')
  ),
  -- Around the viewer: normalised city names, and the areas the viewer's city names.
  vcity AS (
    SELECT DISTINCT x.c
    FROM (SELECT lower(btrim(regexp_replace(v_city, '\s+city\s*$', '', 'i'))) AS c
          UNION ALL
          SELECT lower(btrim(regexp_replace(a.city, '\s+city\s*$', '', 'i')))
            FROM public.areas a
           WHERE lower(btrim(a.name)) = lower(btrim(v_city)) OR lower(btrim(a.district)) = lower(btrim(v_city))) x
    WHERE x.c IS NOT NULL AND x.c <> ''
  ),
  varea AS (
    SELECT a.id FROM public.areas a
     WHERE lower(btrim(a.name)) = lower(btrim(v_city)) OR lower(btrim(a.district)) = lower(btrim(v_city))
  ),
  fol AS (
    SELECT pf.following_profile_id AS pid FROM public.profile_follows pf WHERE pf.follower_profile_id = v_my_profile_id
  ),
  cand AS (
    -- games: one row per game, game_started once it has started, else game_created
    SELECT CASE WHEN e.start_at <= now() THEN 'game_started' ELSE 'game_created' END AS c_event_type,
           CASE WHEN e.start_at <= now() THEN e.start_at ELSE e.created_at END AS c_event_at,
           'game'::text AS c_kind, g.id AS c_entity, e.id AS c_event_id, e.creator_profile_id AS c_actor,
           a.city AS c_city, e.title AS c_title, COALESCE(vn.name_en, a.name) AS c_detail,
           e.start_at AS c_start, e.end_at AS c_end, ARRAY[e.sport_id] AS c_sports,
           (e.area_id IN (SELECT id FROM varea)) AS c_same_area,
           rc.n AS c_participants, e.capacity AS c_capacity, NULL::integer AS c_spaces, e.created_at AS c_created,
           EXISTS (SELECT 1 FROM public.game_roster gf WHERE gf.game_id = g.id AND gf.status = 'active'
                      AND gf.profile_id IN (SELECT pid FROM fol)) AS c_social_any
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
      JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id
      CROSS JOIN LATERAL (
        SELECT count(*)::int AS n FROM public.game_roster gr
         WHERE gr.game_id = g.id AND gr.status = 'active'
           AND (gr.role = 'player' OR (gr.role = 'host' AND g.game_type IN ('hosted', 'casual')))) rc
     WHERE e.is_cancelled = false
       AND COALESCE(e.end_at, e.start_at) > now()
       AND e.sport_id = ANY (v_interests)
       AND e.creator_user_id IS DISTINCT FROM v_my_uid
       AND (e.capacity IS NULL OR rc.n < e.capacity)
       AND NOT EXISTS (SELECT 1 FROM public.game_roster gm
                        WHERE gm.game_id = g.id AND gm.user_id = v_my_uid AND gm.status = 'active')
       AND lower(btrim(regexp_replace(a.city, '\s+city\s*$', '', 'i'))) IN (SELECT c FROM vcity)
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(v_my_uid, e.creator_user_id)
    UNION ALL
    -- meetups: meetup_started once started, else meetup_created
    SELECT CASE WHEN e.start_at <= now() THEN 'meetup_started' ELSE 'meetup_created' END,
           CASE WHEN e.start_at <= now() THEN e.start_at ELSE e.created_at END,
           'meetup'::text, m.id, e.id, e.creator_profile_id,
           a.city, e.title, COALESCE(vn.name_en, a.name),
           e.start_at, COALESCE(e.end_at, e.start_at), ARRAY[e.sport_id],
           (e.area_id IN (SELECT id FROM varea)),
           rc.n, e.capacity, NULL::integer, e.created_at,
           EXISTS (SELECT 1 FROM public.meetup_rsvps mf WHERE mf.meetup_id = m.id AND mf.status = 'going'
                      AND mf.profile_id IN (SELECT pid FROM fol))
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
      JOIN public.areas a ON a.id = e.area_id
      LEFT JOIN public.venues vn ON vn.id = e.venue_id
      CROSS JOIN LATERAL (
        SELECT count(*)::int AS n FROM public.meetup_rsvps mr WHERE mr.meetup_id = m.id AND mr.status = 'going') rc
     WHERE e.is_cancelled = false
       AND COALESCE(e.end_at, e.start_at) > now()
       AND e.sport_id = ANY (v_interests)
       AND e.creator_user_id IS DISTINCT FROM v_my_uid
       AND (e.capacity IS NULL OR rc.n < e.capacity)
       AND NOT EXISTS (SELECT 1 FROM public.meetup_rsvps mm
                        WHERE mm.meetup_id = m.id AND mm.user_id = v_my_uid AND mm.status = 'going')
       AND lower(btrim(regexp_replace(a.city, '\s+city\s*$', '', 'i'))) IN (SELECT c FROM vcity)
       AND public.kan713_meetup_visible(m.event_id)
       AND NOT public.is_blocked(v_my_uid, e.creator_user_id)
    UNION ALL
    -- venues added in the last 30 days that offer one of the viewer's sports
    SELECT 'venue_added', v.created_at, 'venue'::text, v.id, NULL::uuid, NULL::uuid,
           a.city, v.name_en, a.name, NULL::timestamptz, NULL::timestamptz, vs.sports,
           (v.area_id IN (SELECT id FROM varea)),
           NULL::integer, NULL::integer,
           (SELECT count(*)::int FROM public.venue_spaces vsc WHERE vsc.venue_id = v.id AND vsc.is_active),
           v.created_at, false
      FROM public.venues v
      JOIN public.areas a ON a.id = v.area_id
      CROSS JOIN LATERAL (
        SELECT array_agg(s.id ORDER BY s.name_en, s.id) AS sports
          FROM public.sports s
         WHERE EXISTS (SELECT 1 FROM public.venue_spaces vs2 WHERE vs2.venue_id = v.id AND vs2.sport_id = s.id)
            OR s.sport_key = ANY (v.sports)) vs
     WHERE v.is_active = true
       AND v.created_at > now() - interval '30 days'
       AND vs.sports && v_interests
       AND v.owner_user_id IS DISTINCT FROM v_my_uid
       AND (v.owner_user_id IS NULL OR NOT public.is_blocked(v_my_uid, v.owner_user_id))
       AND lower(btrim(regexp_replace(a.city, '\s+city\s*$', '', 'i'))) IN (SELECT c FROM vcity)
    UNION ALL
    -- new players (last 14 days) who share a sport with the viewer
    SELECT 'player_joined', p.created_at, 'profile'::text, p.id, NULL::uuid, p.id,
           p.city, p.display_name, NULL::text, NULL::timestamptz, NULL::timestamptz, ps.sports,
           (lower(btrim(p.city)) = lower(btrim(v_city))),
           NULL::integer, NULL::integer, NULL::integer, p.created_at,
           EXISTS (SELECT 1 FROM public.profile_follows pb
                    WHERE pb.follower_profile_id = p.id AND pb.following_profile_id = v_my_profile_id)
      FROM public.profiles p
      CROSS JOIN LATERAL (
        SELECT array_agg(s.id ORDER BY s.name_en, s.id) AS sports
          FROM public.sports s
         WHERE s.id = p.primary_sport OR s.id = p.preferred_sport OR s.id = ANY (p.interests)) ps
     WHERE p.profile_type = 'personal'
       AND p.created_at > now() - interval '14 days'
       AND p.user_id IS DISTINCT FROM v_my_uid
       AND ps.sports && v_interests
       AND lower(btrim(regexp_replace(p.city, '\s+city\s*$', '', 'i'))) IN (SELECT c FROM vcity)
       AND public.is_profile_publicly_visible(p.id)
       AND NOT public.is_blocked(v_my_uid, p.user_id)
  ),
  cand_f AS (
    SELECT c.*
      FROM cand c
     WHERE (p_sport_id IS NULL OR p_sport_id = ANY (c.c_sports))
       AND (p_sport_ids IS NULL OR c.c_sports && p_sport_ids)
  ),
  scored AS (
    SELECT c.*, imp.first_seen_at AS c_seen,
      round((
        -- time
        CASE
          WHEN c.c_kind IN ('game', 'meetup') THEN
            CASE WHEN c.c_start <= now() THEN 35
                 WHEN c.c_start <= now() + interval '48 hours'
                   THEN 20 + 15 * (1 - extract(epoch FROM (c.c_start - now())) / 172800.0)
                 ELSE greatest(0, 10 - extract(epoch FROM (c.c_start - now())) / 86400.0) END
          WHEN c.c_kind = 'profile' THEN 20 * greatest(0, 1 - extract(epoch FROM (now() - c.c_created)) / 1209600.0)
          ELSE 20 * greatest(0, 1 - extract(epoch FROM (now() - c.c_created)) / 2592000.0)
        END
        -- sport
        + CASE WHEN v_primary = ANY (c.c_sports) OR v_preferred = ANY (c.c_sports) THEN 20 ELSE 14 END
        -- distance
        + CASE WHEN c.c_same_area THEN 15 ELSE 10 END
        -- social
        + CASE WHEN c.c_actor IN (SELECT pid FROM fol) THEN 20 WHEN c.c_social_any THEN 12 ELSE 0 END
        -- joinability
        + CASE WHEN c.c_kind NOT IN ('game', 'meetup') THEN 0
               WHEN c.c_capacity IS NULL OR c.c_capacity <= 0 THEN 4
               ELSE 4 + 6 * c.c_participants::numeric / c.c_capacity END
      )::numeric, 2) AS c_score
      FROM cand_f c
      LEFT JOIN public.home_feed_impressions imp
        ON imp.profile_id = v_my_profile_id AND imp.entity_type = c.c_kind AND imp.entity_id = c.c_entity
  ),
  kept AS (
    SELECT s.*,
           CASE WHEN s.c_seen IS NULL THEN 1 + floor((100 - s.c_score) / 4)::int
                ELSE greatest(1, (SELECT count(*)::int FROM anchors an WHERE an.a_at >= s.c_seen)) END AS c_desired
      FROM scored s
     WHERE s.c_score >= 40
     ORDER BY s.c_score DESC, s.c_kind, s.c_entity
     LIMIT 30
  ),
  ordered AS (
    SELECT k.*, row_number() OVER (ORDER BY k.c_desired, k.c_score DESC, k.c_kind, k.c_entity) AS rn
      FROM kept k
  ),
  spaced AS (
    -- assigned_i = max(desired_i, assigned_{i-1} + 1) = i + max_{j<=i}(desired_j - j)
    SELECT o.*, (o.rn + max(o.c_desired - o.rn) OVER (ORDER BY o.rn ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))::bigint AS c_assigned
      FROM ordered o
  ),
  placed AS (
    SELECT sp.*, an.a_at, an.a_id
      FROM spaced sp
      JOIN anchors an ON an.ai = sp.c_assigned
  ),
  merged AS (
    SELECT po.activity_id AS m_activity_id, po.activity_type AS m_activity_type, po.parent_activity_id AS m_parent,
           po.actor_profile_id AS m_actor, po.created_at AS m_created, po.seen_at AS m_seen, po.source AS m_source,
           'post'::text AS m_item_kind, po.created_at AS m_feed_at, po.activity_id AS m_cursor_id, 0 AS m_kind,
           NULL::numeric AS m_score,
           NULL::text AS m_event_type, NULL::timestamptz AS m_event_at, NULL::text AS m_entity_kind, NULL::uuid AS m_entity_id,
           NULL::text AS m_city, NULL::text AS m_title, NULL::text AS m_detail, NULL::timestamptz AS m_start,
           NULL::timestamptz AS m_end, NULL::uuid[] AS m_sports, NULL::integer AS m_participants,
           NULL::integer AS m_capacity, NULL::integer AS m_spaces
      FROM posts po
     WHERE NOT (po.activity_type IN ('game_create', 'meetup_create')
                AND po.activity_id IN (SELECT pl.c_event_id FROM placed pl WHERE pl.c_event_id IS NOT NULL))
    UNION ALL
    SELECT pl.c_entity, pl.c_event_type, NULL::uuid, pl.c_actor, pl.a_at, pl.c_seen, 'active'::text,
           'active'::text, pl.a_at, pl.a_id, 1, pl.c_score,
           pl.c_event_type, pl.c_event_at, pl.c_kind, pl.c_entity,
           pl.c_city, pl.c_title, pl.c_detail, pl.c_start, pl.c_end, pl.c_sports, pl.c_participants,
           pl.c_capacity, pl.c_spaces
      FROM placed pl
  ),
  page AS (
    SELECT mg.*
      FROM merged mg
     WHERE p_cursor IS NULL
        OR (p_cursor_id IS NULL AND mg.m_feed_at < p_cursor)
        OR (p_cursor_id IS NOT NULL AND (mg.m_feed_at, mg.m_cursor_id, -mg.m_kind) < (p_cursor, p_cursor_id, -v_ckind))
     ORDER BY mg.m_feed_at DESC, mg.m_cursor_id DESC, mg.m_kind ASC
     LIMIT p_limit
  )
  SELECT pg.m_activity_id, pg.m_activity_type, pg.m_parent, pg.m_actor, pg.m_created, pg.m_seen, pg.m_source,
         pg.m_item_kind, pg.m_feed_at, pg.m_cursor_id, pg.m_score,
         pg.m_event_type, pg.m_event_at, pg.m_entity_kind, pg.m_entity_id, pg.m_city, pg.m_title,
         CASE WHEN pg.m_kind = 1 THEN ap.display_name END, CASE WHEN pg.m_kind = 1 THEN ap.avatar_url END,
         pg.m_detail, pg.m_start, pg.m_end,
         CASE WHEN pg.m_kind = 1
              THEN COALESCE(pg.m_entity_kind IN ('game', 'meetup') AND pg.m_start <= now() AND now() < pg.m_end, false) END,
         sn.en, sn.ar,
         pg.m_participants, pg.m_capacity, pg.m_spaces
    FROM page pg
    LEFT JOIN public.profiles ap ON pg.m_kind = 1 AND ap.id = pg.m_actor
    LEFT JOIN LATERAL (
      SELECT COALESCE(array_agg(s.name_en ORDER BY s.name_en, s.id), '{}'::text[]) AS en,
             COALESCE(array_agg(s.name_ar ORDER BY s.name_en, s.id), '{}'::text[]) AS ar
        FROM public.sports s WHERE s.id = ANY (pg.m_sports)
    ) sn ON pg.m_kind = 1
   ORDER BY pg.m_feed_at DESC, pg.m_cursor_id DESC, pg.m_kind ASC;
END;
$function$;

ALTER FUNCTION public.get_home_feed(integer, timestamp with time zone, uuid, uuid[], uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_home_feed(integer, timestamp with time zone, uuid, uuid[], uuid, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_home_feed(integer, timestamp with time zone, uuid, uuid[], uuid, text) TO authenticated, service_role;

DO $post$
DECLARE v_acl text; v_def boolean; v_cfg text[]; v_owner text; v_n int;
BEGIN
  SELECT (SELECT string_agg(x, ',' ORDER BY x) FROM unnest(p.proacl::text[]) x), p.prosecdef, p.proconfig, pg_get_userbyid(p.proowner)
    INTO v_acl, v_def, v_cfg, v_owner
    FROM pg_proc p WHERE p.oid = 'public.get_home_feed(integer,timestamptz,uuid,uuid[],uuid,text)'::regprocedure;
  IF v_acl IS DISTINCT FROM 'authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres'
     OR NOT v_def OR v_cfg IS DISTINCT FROM ARRAY['search_path=public'] OR v_owner <> 'postgres' THEN
    RAISE EXCEPTION 'KAN-966 get_home_feed post-assert failed: acl=% secdef=% cfg=% owner=%', v_acl, v_def, v_cfg, v_owner;
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'get_home_feed';
  IF v_n <> 1 THEN RAISE EXCEPTION 'KAN-966 expected one get_home_feed after, found %', v_n; END IF;

  SELECT (SELECT string_agg(x, ',' ORDER BY x) FROM unnest(p.proacl::text[]) x), p.prosecdef, pg_get_userbyid(p.proowner)
    INTO v_acl, v_def, v_owner
    FROM pg_proc p WHERE p.oid = 'public.rpc_mark_feed_impressions(jsonb)'::regprocedure;
  IF v_acl IS DISTINCT FROM 'authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres' OR v_def OR v_owner <> 'postgres' THEN
    RAISE EXCEPTION 'KAN-966 rpc_mark_feed_impressions post-assert failed: acl=% secdef=% owner=%', v_acl, v_def, v_owner;
  END IF;

  IF has_table_privilege('anon', 'public.home_feed_impressions', 'SELECT')
     OR has_table_privilege('anon', 'public.home_feed_impressions', 'INSERT')
     OR has_table_privilege('authenticated', 'public.home_feed_impressions', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.home_feed_impressions', 'DELETE')
     OR has_column_privilege('authenticated', 'public.home_feed_impressions', 'first_seen_at', 'INSERT')
     OR NOT has_table_privilege('authenticated', 'public.home_feed_impressions', 'SELECT')
     OR NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.home_feed_impressions'::regclass) THEN
    RAISE EXCEPTION 'KAN-966 home_feed_impressions grant/RLS post-assert failed';
  END IF;
END
$post$;

NOTIFY pgrst, 'reload schema';
