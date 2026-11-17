-- KAN-976 [W0-3] Event change signal (Epic KAN-973, plan Dabbler/dabbler-docs/briefs/NOTIFICATIONS_PLAN_2026-11-16.md).
--
-- One signal for "an event changed", so the change notifications (W1-B3), the reminder scheduler (W1-B5 / KAN-983) and
-- the producers (KAN-981) read one outbox instead of adding their own triggers on public.events.
--
--   1. public.events.schedule_revision integer NOT NULL DEFAULT 0
--        Goes up by 1 on an UPDATE that changes the time (start_at, end_at) or the place (venue_id, area_id,
--        geo_location_id). Nothing else moves it. A direct write of the column is ignored (the trigger resets it).
--   2. public.event_changes (outbox, server only)
--        One row per changed field per UPDATE, for start_at, end_at, venue_id, area_id, geo_location_id, capacity,
--        the join rule fields (join_policy, joining_rule, cost_cover, min_skill, max_skill) and is_cancelled.
--        Rows of one UPDATE share change_group and occurred_at. revision = the event's schedule_revision after it.
--        Consumers keep their own cursor on id, or stamp consumed_by ({"<consumer>": "<timestamptz>"}).
--   3. trigger trg_kan976_events_change_signal: BEFORE UPDATE FOR EACH ROW on public.events, function
--        public.kan976_events_change_signal(). BEFORE so it can set NEW.schedule_revision; named so it sorts after
--        every other BEFORE trigger on events (trg_events_*, trg_kan711_*, trg_kan713_*), so it sees the area_id and
--        geo_location_id that kan713_events_location derives from a venue change.
--        It does not touch games/meetups and schedule_revision is not in the WHEN of trg_kan949_events_nudge_subtype,
--        so it causes no extra kan949 / kan950 nudge. It sends no notification. trg_kan947_events_game_updated_notify,
--        msg_kan947_events_game_cancelled and events_meetup_cancel_null are unchanged (KAN-982 / W1-B3 own them).
--   4. public.event_timezone(p_event_id uuid) RETURNS text, STABLE, SECURITY DEFINER
--        venues.timezone (if it is a valid zone) -> country map for the area's country_code (event area_id, else the
--        area of its geo_location) -> 'Asia/Dubai'. NULL when the event does not exist.
--        Map: AE Asia/Dubai, SA Asia/Riyadh, QA Asia/Qatar, KW Asia/Kuwait, BH Asia/Bahrain, OM Asia/Muscat.
--
-- Grants: event_changes has RLS on, no policy, nothing for PUBLIC/anon/authenticated; SELECT, UPDATE for service_role
--   (consumers). Both functions: EXECUTE revoked from PUBLIC, anon, authenticated; event_timezone granted to
--   service_role. SECURITY DEFINER callers owned by postgres can call it regardless.
-- Pre-image guard: aborts unless events still has exactly the 12 user triggers read on 2026-11-17 and none of the new
--   objects exist. Post asserts: column, default, every row at 0, trigger present, RLS, no policy, ACLs.
-- Live test: supabase/tests/notifications_v2/kan976_event_change_signal.sql.
-- Rollback: supabase/schema/rollback/kan976_ROLLBACK_event_change_signal.sql.

-- 1. pre-image guard ---------------------------------------------------------------------------------------------------
DO $pre$
DECLARE
  v_triggers text[];
BEGIN
  SELECT array_agg(t.tgname::text ORDER BY t.tgname) INTO v_triggers
    FROM pg_trigger t WHERE t.tgrelid = 'public.events'::regclass AND NOT t.tgisinternal;
  IF v_triggers IS DISTINCT FROM ARRAY[
       'msg_kan947_events_game_cancelled', 'tr_kan947_events_game_activity_sync', 'trg_events_exclusive_check',
       'trg_events_search_tsv', 'trg_events_series_start_check', 'trg_events_touch', 'trg_events_type_immutable',
       'trg_kan711_events_keep_updated_at', 'trg_kan713_events_location', 'trg_kan718_events_series_occurrence',
       'trg_kan947_events_game_updated_notify', 'trg_kan949_events_nudge_subtype']::text[] THEN
    RAISE EXCEPTION 'kan976 pre: events triggers changed since the claim: %', v_triggers;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'events' AND column_name = 'schedule_revision') THEN
    RAISE EXCEPTION 'kan976 pre: events.schedule_revision already exists';
  END IF;
  IF to_regclass('public.event_changes') IS NOT NULL THEN
    RAISE EXCEPTION 'kan976 pre: public.event_changes already exists';
  END IF;
  IF to_regprocedure('public.event_timezone(uuid)') IS NOT NULL
     OR to_regprocedure('public.kan976_events_change_signal()') IS NOT NULL THEN
    RAISE EXCEPTION 'kan976 pre: a kan976 function already exists';
  END IF;
END $pre$;

-- 2. column ------------------------------------------------------------------------------------------------------------
ALTER TABLE public.events
  ADD COLUMN schedule_revision integer NOT NULL DEFAULT 0
  CONSTRAINT events_schedule_revision_nonneg CHECK (schedule_revision >= 0);

COMMENT ON COLUMN public.events.schedule_revision IS
  'KAN-976: +1 on every UPDATE that changes start_at, end_at, venue_id, area_id or geo_location_id. Set only by '
  'trg_kan976_events_change_signal; a direct write is ignored. Reminder jobs re-plan when it moves.';

-- 3. outbox ------------------------------------------------------------------------------------------------------------
CREATE TABLE public.event_changes (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id        uuid        NOT NULL REFERENCES public.events (id) ON DELETE CASCADE,
  event_type      text        NOT NULL CHECK (event_type IN ('game', 'meetup')),
  revision        integer     NOT NULL,
  field           text        NOT NULL CHECK (field IN (
                    'start_at', 'end_at', 'venue_id', 'area_id', 'geo_location_id', 'capacity',
                    'join_policy', 'joining_rule', 'cost_cover', 'min_skill', 'max_skill', 'is_cancelled')),
  old_value       jsonb,
  new_value       jsonb,
  schedule_change boolean     NOT NULL,
  actor_user_id   uuid,
  change_group    uuid        NOT NULL,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  consumed_by     jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(consumed_by) = 'object')
);

CREATE INDEX event_changes_event_id_id_idx ON public.event_changes (event_id, id);
CREATE INDEX event_changes_occurred_at_idx ON public.event_changes (occurred_at);

COMMENT ON TABLE public.event_changes IS
  'KAN-976 outbox: one row per changed field per UPDATE of public.events (time, place, capacity, join rules, '
  'is_cancelled). Written only by trg_kan976_events_change_signal. Server only: RLS on, no policy, no client grant. '
  'Consumers read by id cursor or stamp consumed_by ->> <consumer>.';
COMMENT ON COLUMN public.event_changes.revision IS 'events.schedule_revision after this UPDATE.';
COMMENT ON COLUMN public.event_changes.schedule_change IS 'true for start_at, end_at, venue_id, area_id, geo_location_id.';
COMMENT ON COLUMN public.event_changes.actor_user_id IS 'auth.uid() of the writer; NULL for service/system writes.';
COMMENT ON COLUMN public.event_changes.change_group IS 'Same value for every row written by one UPDATE of one event.';
COMMENT ON COLUMN public.event_changes.consumed_by IS 'Per-consumer marker, e.g. {"w1_b3": "2026-11-17T10:00:00Z"}.';

ALTER TABLE public.event_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.event_changes FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE ON TABLE public.event_changes TO service_role;

-- 4. trigger function --------------------------------------------------------------------------------------------------
CREATE FUNCTION public.kan976_events_change_signal()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_schedule boolean;
BEGIN
  v_schedule := OLD.start_at        IS DISTINCT FROM NEW.start_at
             OR OLD.end_at          IS DISTINCT FROM NEW.end_at
             OR OLD.venue_id        IS DISTINCT FROM NEW.venue_id
             OR OLD.area_id         IS DISTINCT FROM NEW.area_id
             OR OLD.geo_location_id IS DISTINCT FROM NEW.geo_location_id;

  -- The trigger owns the column: a direct write is replaced by the computed value.
  NEW.schedule_revision := OLD.schedule_revision + CASE WHEN v_schedule THEN 1 ELSE 0 END;

  INSERT INTO public.event_changes
         (event_id, event_type, revision, field, old_value, new_value, schedule_change, actor_user_id, change_group)
  SELECT NEW.id, NEW.event_type, NEW.schedule_revision, c.field, c.o, c.n, c.sched, auth.uid(), g.grp
    FROM (VALUES
           ('start_at',        to_jsonb(OLD.start_at),        to_jsonb(NEW.start_at),        true),
           ('end_at',          to_jsonb(OLD.end_at),          to_jsonb(NEW.end_at),          true),
           ('venue_id',        to_jsonb(OLD.venue_id),        to_jsonb(NEW.venue_id),        true),
           ('area_id',         to_jsonb(OLD.area_id),         to_jsonb(NEW.area_id),         true),
           ('geo_location_id', to_jsonb(OLD.geo_location_id), to_jsonb(NEW.geo_location_id), true),
           ('capacity',        to_jsonb(OLD.capacity),        to_jsonb(NEW.capacity),        false),
           ('join_policy',     to_jsonb(OLD.join_policy),     to_jsonb(NEW.join_policy),     false),
           ('joining_rule',    to_jsonb(OLD.joining_rule),    to_jsonb(NEW.joining_rule),    false),
           ('cost_cover',      to_jsonb(OLD.cost_cover),      to_jsonb(NEW.cost_cover),      false),
           ('min_skill',       to_jsonb(OLD.min_skill),       to_jsonb(NEW.min_skill),       false),
           ('max_skill',       to_jsonb(OLD.max_skill),       to_jsonb(NEW.max_skill),       false),
           ('is_cancelled',    to_jsonb(OLD.is_cancelled),    to_jsonb(NEW.is_cancelled),    false)
         ) AS c(field, o, n, sched)
   CROSS JOIN (SELECT gen_random_uuid() AS grp) g
   WHERE c.o IS DISTINCT FROM c.n;

  RETURN NEW;
END
$function$;

REVOKE ALL ON FUNCTION public.kan976_events_change_signal() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_kan976_events_change_signal
  BEFORE UPDATE ON public.events
  FOR EACH ROW
  WHEN (   OLD.start_at          IS DISTINCT FROM NEW.start_at
        OR OLD.end_at            IS DISTINCT FROM NEW.end_at
        OR OLD.venue_id          IS DISTINCT FROM NEW.venue_id
        OR OLD.area_id           IS DISTINCT FROM NEW.area_id
        OR OLD.geo_location_id   IS DISTINCT FROM NEW.geo_location_id
        OR OLD.capacity          IS DISTINCT FROM NEW.capacity
        OR OLD.join_policy       IS DISTINCT FROM NEW.join_policy
        OR OLD.joining_rule      IS DISTINCT FROM NEW.joining_rule
        OR OLD.cost_cover        IS DISTINCT FROM NEW.cost_cover
        OR OLD.min_skill         IS DISTINCT FROM NEW.min_skill
        OR OLD.max_skill         IS DISTINCT FROM NEW.max_skill
        OR OLD.is_cancelled      IS DISTINCT FROM NEW.is_cancelled
        OR OLD.schedule_revision IS DISTINCT FROM NEW.schedule_revision)
  EXECUTE FUNCTION public.kan976_events_change_signal();

-- 5. event_timezone ----------------------------------------------------------------------------------------------------
CREATE FUNCTION public.event_timezone(p_event_id uuid)
  RETURNS text
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_found   boolean;
  v_venue   text;
  v_country text;
  v_tz      text;
BEGIN
  SELECT true, v.timezone, upper(btrim(a.country_code))
    INTO v_found, v_venue, v_country
    FROM public.events e
    LEFT JOIN public.venues        v  ON v.id  = e.venue_id
    LEFT JOIN public.geo_locations gl ON gl.id = e.geo_location_id
    LEFT JOIN public.areas         a  ON a.id  = coalesce(e.area_id, gl.area_id)
   WHERE e.id = p_event_id;

  IF v_found IS NULL THEN
    RETURN NULL;
  END IF;

  IF nullif(btrim(v_venue), '') IS NOT NULL THEN
    BEGIN
      PERFORM now() AT TIME ZONE btrim(v_venue);
      RETURN btrim(v_venue);
    EXCEPTION WHEN invalid_parameter_value THEN
      NULL;  -- not a zone Postgres knows: fall through to the area
    END;
  END IF;

  v_tz := CASE v_country
            WHEN 'AE' THEN 'Asia/Dubai'
            WHEN 'SA' THEN 'Asia/Riyadh'
            WHEN 'QA' THEN 'Asia/Qatar'
            WHEN 'KW' THEN 'Asia/Kuwait'
            WHEN 'BH' THEN 'Asia/Bahrain'
            WHEN 'OM' THEN 'Asia/Muscat'
          END;

  RETURN coalesce(v_tz, 'Asia/Dubai');
END
$function$;

COMMENT ON FUNCTION public.event_timezone(uuid) IS
  'KAN-976: IANA zone of an event. venues.timezone -> area country_code map (GCC) -> Asia/Dubai. NULL if no such event. '
  'Readers: reminder scheduler (KAN-983), producers (KAN-981).';

REVOKE ALL ON FUNCTION public.event_timezone(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.event_timezone(uuid) TO service_role;

-- 6. post asserts ------------------------------------------------------------------------------------------------------
DO $post$
BEGIN
  IF (SELECT count(*) FROM public.events WHERE schedule_revision <> 0) <> 0 THEN
    RAISE EXCEPTION 'kan976 post: schedule_revision not 0 on every row';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND NOT tgisinternal) <> 13
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass
                     AND tgname = 'trg_kan976_events_change_signal' AND tgenabled = 'O') THEN
    RAISE EXCEPTION 'kan976 post: trigger set on events is not the expected 13';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.event_changes'::regclass)
     OR EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.event_changes'::regclass) THEN
    RAISE EXCEPTION 'kan976 post: event_changes RLS not on, or a policy exists';
  END IF;
  IF has_table_privilege('anon', 'public.event_changes', 'SELECT, INSERT, UPDATE, DELETE')
     OR has_table_privilege('authenticated', 'public.event_changes', 'SELECT, INSERT, UPDATE, DELETE') THEN
    RAISE EXCEPTION 'kan976 post: a client role has a privilege on event_changes';
  END IF;
  IF has_function_privilege('anon', 'public.event_timezone(uuid)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.event_timezone(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.kan976_events_change_signal()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.kan976_events_change_signal()', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.event_timezone(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan976 post: function ACLs are not as intended';
  END IF;
END $post$;
