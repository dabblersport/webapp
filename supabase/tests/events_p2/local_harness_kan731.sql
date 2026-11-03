-- KAN-731 LOCAL HARNESS. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
--
-- Load position: step 14 of the chain, AFTER KAN-718 (20261104110300) and BEFORE
-- 20261104101200_kan714_b12_feed_notifications_stream.sql and supabase/tests/events_p2/kan714_b12_feed_stream.sql.
-- Full ordered chain: the Build header of that test file, or supabase/tests/events_p2/build_kan731.sh, which runs
-- it end to end on a brand new cluster.
--
-- Why it exists: no earlier harness creates the three KAN-731 surfaces (the KAN-711 harness has only a STUB
-- trg_meetups_cancel_notify and no trg_meetup_rsvps_notify), so without this file the migration refuses at P5.
-- It COMMITS:
--   1. stand-in columns / tables the pre-images read that no earlier harness creates (profiles.display_name,
--      city, profile_type, created_at; areas.city; venues.created_at, name_en, is_active, owner_user_id;
--      game_roster.joined_at; user_status; is_benched STUB returning false) and three extra columns on the
--      notifications sink (actor_user_id, title, body) so notification PAYLOADS can be compared, not just counts.
--   2. process_notification_event: same signature and defaults as the KAN-711 stub, but records actor/title/body.
--   3. VERBATIM pre-images, extracted by line range with sed (not retyped):
--      a. is_profile_publicly_visible  20260829080500_baseline_schema.sql:8437-8450, grants :35669-35671
--      b. rpc_get_activity_feed        20261101130000_kan689_rpc_get_activity_feed_fix.sql:7-81 (latest definition),
--                                      owner baseline :12877, grants baseline :36361-36363
--      c. trg_meetup_rsvps_notify      20260915150000_meetups_notifications.sql:113-197 (function, owner, revoke, trigger)
--      d. trg_meetups_cancel_notify    20260915150000_meetups_notifications.sql:202-240 (replaces the KAN-711 stub)
--      e. active_stream                20261020120000_kan595_active_stream.sql:46-172 (function, revoke/grant, comment)
--   4. asserts md5(prosrc) of each pre-image equals the migration's P5 pin.

\set ON_ERROR_STOP 1
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-731 harness: this looks like a Supabase database; local throwaway cluster only';
  END IF;
  IF to_regprocedure('public.active_stream(text[],text,integer,timestamptz,text,uuid)') IS NOT NULL
     OR to_regprocedure('public.rpc_get_activity_feed(text,integer,timestamptz)') IS NOT NULL
     OR to_regprocedure('public.trg_meetup_rsvps_notify()') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-731 harness: a pre-image already exists; load this once, on a fresh chain';
  END IF;
END $$;

BEGIN;

-- 1. Stand-ins ---------------------------------------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name text, ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS profile_type text, ADD COLUMN IF NOT EXISTS created_at timestamptz;
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE public.venues ADD COLUMN IF NOT EXISTS created_at timestamptz, ADD COLUMN IF NOT EXISTS name_en text,
  ADD COLUMN IF NOT EXISTS is_active boolean, ADD COLUMN IF NOT EXISTS owner_user_id uuid;
ALTER TABLE public.game_roster ADD COLUMN IF NOT EXISTS joined_at timestamptz DEFAULT now();
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS actor_user_id uuid, ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS body text;
CREATE TABLE IF NOT EXISTS public.user_status (user_id uuid PRIMARY KEY, hide_in_search boolean);
CREATE OR REPLACE FUNCTION public.is_benched(p_user uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;  -- STUB

-- 2. Notification sink: KAN-711 stub signature and defaults, now also records actor / title / body ---------------
CREATE OR REPLACE FUNCTION public.process_notification_event(p_user uuid, p_kind text, p_entity_type text, p_entity uuid, p_actor uuid, p_title text DEFAULT NULL::text, p_body text DEFAULT NULL::text)
 RETURNS void LANGUAGE sql
AS $function$ INSERT INTO public.notifications(user_id, kind, entity_type, entity_id, actor_user_id, title, body)
              VALUES (p_user, p_kind, p_entity_type, p_entity, p_actor, p_title, p_body) $function$;

-- 3a. is_profile_publicly_visible, verbatim: baseline_schema.sql:8437-8450, grants :35669-35671 -----------------
CREATE OR REPLACE FUNCTION "public"."is_profile_publicly_visible"("p_profile_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select (p.is_active = true)
     and not public.is_benched(p.user_id)
     and coalesce(us.hide_in_search, true) = false  -- visible in search only if hide_in_search=false OR not benched
  from public.profiles p
  left join public.user_status us on us.user_id = p.user_id
  where p.id = p_profile_id
$$;


ALTER FUNCTION "public"."is_profile_publicly_visible"("p_profile_id" "uuid") OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."is_profile_publicly_visible"("p_profile_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_profile_publicly_visible"("p_profile_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_profile_publicly_visible"("p_profile_id" "uuid") TO "service_role";

-- 3b. rpc_get_activity_feed, verbatim: 20261101130000_kan689_rpc_get_activity_feed_fix.sql:7-81 ---------------
CREATE OR REPLACE FUNCTION public.rpc_get_activity_feed(_period text DEFAULT 'all'::text, _limit integer DEFAULT 50, _cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(id uuid, subject_type text, subject_id uuid, verb text, status text, time_bucket text, happened_at timestamp with time zone, scheduled_for timestamp with time zone, priority integer, payload jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  WITH me AS (
    SELECT auth.uid() AS user_id
  ),
  game_created AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'created'::text                                               AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN g.end_at < NOW()                              THEN 'past'
        WHEN g.start_at <= NOW() AND g.end_at >= NOW()    THEN 'present'
        WHEN g.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      g.created_at                                                  AS happened_at,
      g.start_at                                                    AS scheduled_for,
      90                                                            AS priority,
      jsonb_build_object('role', 'host')                            AS payload
    FROM public.games g
    JOIN me ON g.creator_user_id = me.user_id
    WHERE g.is_cancelled = false
  ),
  game_joined AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'joined'::text                                                AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN g.end_at < NOW()                              THEN 'past'
        WHEN g.start_at <= NOW() AND g.end_at >= NOW()    THEN 'present'
        WHEN g.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      gr.joined_at                                                  AS happened_at,
      g.start_at                                                    AS scheduled_for,
      80                                                            AS priority,
      jsonb_build_object('role', 'player')                          AS payload
    FROM public.game_roster gr
    JOIN public.games g ON g.id = gr.game_id
    JOIN me ON gr.user_id = me.user_id
    WHERE gr.status = 'active'
      AND g.is_cancelled = false
      AND g.creator_user_id <> me.user_id
  ),
  game_events AS (
    SELECT * FROM game_created
    UNION ALL
    SELECT * FROM game_joined
  ),
  filtered AS (
    SELECT * FROM game_events e
    WHERE (_period = 'all' OR e.time_bucket = _period)
      AND (_cursor IS NULL OR e.happened_at < _cursor)
  )
  SELECT f.* FROM filtered f
  ORDER BY
    CASE f.time_bucket WHEN 'upcoming' THEN 1 WHEN 'present' THEN 2 WHEN 'past' THEN 3 END,
    f.scheduled_for ASC,
    f.happened_at DESC,
    f.priority DESC
  LIMIT _limit;
END;
$function$;
-- owner baseline_schema.sql:12877, grants :36361-36363
ALTER FUNCTION "public"."rpc_get_activity_feed"("_period" "text", "_limit" integer, "_cursor" timestamp with time zone) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."rpc_get_activity_feed"("_period" "text", "_limit" integer, "_cursor" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_get_activity_feed"("_period" "text", "_limit" integer, "_cursor" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_get_activity_feed"("_period" "text", "_limit" integer, "_cursor" timestamp with time zone) TO "service_role";

-- 3c. trg_meetup_rsvps_notify, verbatim: 20260915150000_meetups_notifications.sql:113-197 --------------------
CREATE OR REPLACE FUNCTION public.trg_meetup_rsvps_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor      uuid := auth.uid();
  v_host_uid   uuid;
  v_title      text;
  v_name       text;
  v_old        text;
BEGIN
  -- OLD is unassigned on INSERT, so read it once, guarded.
  IF TG_OP = 'UPDATE' THEN v_old := OLD.status; END IF;

  -- Only status changes (and brand-new rows) are events.
  IF TG_OP = 'UPDATE' AND v_old IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT m.creator_user_id, m.title INTO v_host_uid, v_title
    FROM public.meetups m WHERE m.id = NEW.meetup_id;
  IF v_host_uid IS NULL THEN RETURN NEW; END IF;

  SELECT p.display_name INTO v_name
    FROM public.profiles p
   WHERE p.user_id = NEW.user_id AND p.is_active = true
   LIMIT 1;
  v_name := COALESCE(v_name, 'Someone');

  -- Someone asks to join (request policy): tell the host. Never the host's own row.
  IF NEW.status = 'pending'
     AND v_old IS DISTINCT FROM 'pending'
  THEN
    IF NEW.user_id <> v_host_uid THEN
      PERFORM public.process_notification_event(
        v_host_uid, 'meetup.request_received', 'meetup', NEW.meetup_id, NEW.user_id,
        v_name || ' asked to join your meet-up', v_title);
    END IF;
    RETURN NEW;
  END IF;

  -- Attendee flips to 'going' themselves (UPDATE only: a fresh INSERT is covered
  -- by the existing meetup.player_joined chain; see header).
  IF TG_OP = 'UPDATE' AND NEW.status = 'going'
     AND v_actor IS NOT NULL AND v_actor = NEW.user_id
  THEN
    IF NEW.user_id <> v_host_uid THEN
      PERFORM public.process_notification_event(
        v_host_uid, 'meetup.rsvp_received', 'meetup', NEW.meetup_id, NEW.user_id,
        v_name || ' is going to your meet-up', v_title);
    END IF;
    RETURN NEW;
  END IF;

  -- Somebody else (the host or an admin) decides a pending request: tell the attendee.
  IF TG_OP = 'UPDATE' AND v_old = 'pending'
     AND v_actor IS NOT NULL AND v_actor <> NEW.user_id
  THEN
    IF NEW.status = 'going' THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
        'You''re in! Your request to join was approved', v_title);
    ELSIF NEW.status = 'interested' THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
        'Your request was approved, but the meet-up is full', v_title);
    ELSIF NEW.status IN ('cancelled', 'declined') THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_declined', 'meetup', NEW.meetup_id, v_actor,
        'Your request to join was declined', v_title);
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

ALTER FUNCTION public.trg_meetup_rsvps_notify() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.trg_meetup_rsvps_notify() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER trg_meetup_rsvps_notify
  AFTER INSERT OR UPDATE OF status ON public.meetup_rsvps
  FOR EACH ROW EXECUTE FUNCTION public.trg_meetup_rsvps_notify();

-- 3d. trg_meetups_cancel_notify, verbatim: 20260915150000_meetups_notifications.sql:202-240 (replaces the stub)
CREATE OR REPLACE FUNCTION public.trg_meetups_cancel_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  r       record;
BEGIN
  IF NOT (NEW.is_cancelled IS TRUE AND OLD.is_cancelled IS DISTINCT FROM TRUE) THEN
    RETURN NEW;
  END IF;

  FOR r IN
    SELECT DISTINCT s.user_id
      FROM public.meetup_rsvps s
     WHERE s.meetup_id = NEW.id
       AND s.status IN ('going', 'interested', 'pending')
       AND s.user_id IS DISTINCT FROM v_actor
  LOOP
    PERFORM public.process_notification_event(
      r.user_id, 'meetup.cancelled', 'meetup', NEW.id,
      COALESCE(v_actor, NEW.creator_user_id),
      'A meet-up you signed up for was cancelled', NEW.title);
  END LOOP;

  RETURN NEW;
END;
$function$;

ALTER FUNCTION public.trg_meetups_cancel_notify() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.trg_meetups_cancel_notify() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER trg_meetups_cancel_notify
  AFTER UPDATE OF is_cancelled ON public.meetups
  FOR EACH ROW
  WHEN (NEW.is_cancelled IS TRUE AND OLD.is_cancelled IS DISTINCT FROM TRUE)
  EXECUTE FUNCTION public.trg_meetups_cancel_notify();

-- 3e. active_stream, verbatim: 20261020120000_kan595_active_stream.sql:46-172 ----------------------------------
CREATE OR REPLACE FUNCTION public.active_stream(
  p_event_types text[] DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_limit int DEFAULT 30,
  p_before timestamptz DEFAULT NULL,
  p_before_type text DEFAULT NULL,
  p_before_entity uuid DEFAULT NULL
)
RETURNS TABLE (
  event_type text,
  event_at timestamptz,
  entity_kind text,
  entity_id uuid,
  actor_profile_id uuid,
  city text,
  title text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public', 'pg_temp'
AS $$
  WITH prm AS (
    SELECT auth.uid() AS viewer,
           LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50) AS lim,
           NULLIF(btrim(p_city), '') AS city
  ),
  ev AS (
    -- player_joined
    SELECT 'player_joined'::text AS event_type, p.created_at AS event_at, 'profile'::text AS entity_kind,
           p.id AS entity_id, p.id AS actor_profile_id, p.city AS city, p.display_name AS title
      FROM public.profiles p, prm
     WHERE prm.viewer IS NOT NULL
       AND p.profile_type = 'personal'
       AND p.created_at IS NOT NULL
       AND public.is_profile_publicly_visible(p.id)
       AND NOT public.is_blocked(prm.viewer, p.user_id)
    UNION ALL
    -- venue_added
    SELECT 'venue_added'::text, v.created_at, 'venue'::text, v.id, NULL::uuid, a.city, v.name_en
      FROM public.venues v
      JOIN public.areas a ON a.id = v.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND v.is_active = true
       AND (v.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, v.owner_user_id))
    UNION ALL
    -- game_created
    SELECT 'game_created'::text, g.created_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
      FROM public.games g
      JOIN public.areas a ON a.id = g.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, g.start_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
      FROM public.games g
      JOIN public.areas a ON a.id = g.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false
       AND g.start_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
    UNION ALL
    -- game_ended
    SELECT 'game_ended'::text, g.end_at, 'game'::text, g.id, g.creator_profile_id, a.city, g.title
      FROM public.games g
      JOIN public.areas a ON a.id = g.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false
       AND g.end_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
    UNION ALL
    -- meetup_created
    SELECT 'meetup_created'::text, m.created_at, 'meetup'::text, m.id, m.creator_profile_id, a.city, m.title
      FROM public.meetups m
      LEFT JOIN public.areas a ON a.id = m.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, m.start_at, 'meetup'::text, m.id, m.creator_profile_id, a.city, m.title
      FROM public.meetups m
      LEFT JOIN public.areas a ON a.id = m.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false
       AND m.start_at <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
    UNION ALL
    -- meetup_completed
    SELECT 'meetup_completed'::text, COALESCE(m.end_at, m.start_at), 'meetup'::text, m.id, m.creator_profile_id,
           a.city, m.title
      FROM public.meetups m
      LEFT JOIN public.areas a ON a.id = m.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false
       AND COALESCE(m.end_at, m.start_at) <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
  ),
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
     ORDER BY ev.event_type, ev.entity_id, ev.event_at DESC
  )
  SELECT f.event_type, f.event_at, f.entity_kind, f.entity_id, f.actor_profile_id, f.city, f.title
    FROM filtered f
   ORDER BY f.event_at DESC, f.event_type DESC, f.entity_id DESC
   LIMIT (SELECT lim FROM prm);
$$;

REVOKE ALL ON FUNCTION public.active_stream(text[], text, int, timestamptz, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_stream(text[], text, int, timestamptz, text, uuid) TO authenticated;

COMMENT ON FUNCTION public.active_stream(text[], text, int, timestamptz, text, uuid) IS
  'KAN-595 Active stream: player_joined, venue_added, game_created/started/ended, meetup_created/started/completed; newest first; viewer-visible, block-filtered; selected-city text filter, no location.';

-- 4. md5 pins (must equal the migration's P5 pins) ------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT x.sig, x.pin, md5(p.prosrc) AS got
             FROM (VALUES ('public.rpc_get_activity_feed(text,integer,timestamptz)', '73036a69dbec39c5bd44209b80147f1e'),
                          ('public.trg_meetup_rsvps_notify()', '55efefd5cf5b5556d11f6ac093fd64b8'),
                          ('public.trg_meetups_cancel_notify()', '48990a6a71e751614d5fbd6f29c2fdde'),
                          ('public.active_stream(text[],text,integer,timestamptz,text,uuid)', '0e7b7eddfce6dee2746734fb47fbf332')) x(sig, pin)
             LEFT JOIN pg_proc p ON p.oid = to_regprocedure(x.sig)
  LOOP
    IF r.got IS DISTINCT FROM r.pin THEN
      RAISE EXCEPTION 'KAN-731 harness: % md5 % <> pin %', r.sig, r.got, r.pin;
    END IF;
  END LOOP;
END $$;

COMMIT;
