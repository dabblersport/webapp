-- KAN-728 LOCAL HARNESS. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
--
-- Load position: AFTER the tracked events chain (KAN-711 .. KAN-713, KAN-718 and
-- supabase/tests/events_p2_kan714/local_harness_kan714.sql) and BEFORE
-- 20261104100900_kan714_b09_booking_conflicts_hold.sql and supabase/tests/events_p2/kan714_b09_booking_conflicts.sql.
-- Full ordered chain: supabase/tests/events_p2/build_kan728.sh, which runs it end to end on a fresh cluster.
--
-- Why it exists: no earlier tracked harness creates the three baseline functions B09 reads or pins, so without this
-- file the test aborts at its first _slot_conflicts_game reference and the migration refuses. It COMMITS, VERBATIM from
-- supabase/migrations/20260829080500_baseline_schema.sql (extracted by line range with sed, not retyped):
--   1. public._game_belongs_to_venue(uuid,uuid)            :1074-1087   grants :34245-34247
--   2. public._slot_conflicts_game(uuid,timestamptz,timestamptz)  :1597-1610   grants :34445-34447  (the B09 PRE-IMAGE)
--   3. public.rpc_booking_cancel(uuid)                     :11111-11145 grants :36116-36118
-- md5(pg_get_functiondef) of each must equal the KAN-713 stage catalogue (T-058) the B09 pins were authored from;
-- asserted at the end. venue_spaces, venue_bookings, is_venue_admin and is_admin already come from the chain.

\set ON_ERROR_STOP 1
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-728 harness: this looks like a Supabase database; local throwaway cluster only';
  END IF;
  IF to_regprocedure('public._slot_conflicts_game(uuid,timestamptz,timestamptz)') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-728 harness: _slot_conflicts_game already exists; load this once, on a fresh chain';
  END IF;
END $$;

BEGIN;

CREATE OR REPLACE FUNCTION "public"."_game_belongs_to_venue"("p_game_id" "uuid", "p_venue_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select exists(
    select 1
    from public.games g
    join public.venue_spaces s on s.id = g.venue_space_id
    where g.id = p_game_id and s.venue_id = p_venue_id
  )
$$;


ALTER FUNCTION "public"."_game_belongs_to_venue"("p_game_id" "uuid", "p_venue_id" "uuid") OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."_game_belongs_to_venue"("p_game_id" "uuid", "p_venue_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."_game_belongs_to_venue"("p_game_id" "uuid", "p_venue_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_game_belongs_to_venue"("p_game_id" "uuid", "p_venue_id" "uuid") TO "service_role";

CREATE OR REPLACE FUNCTION "public"."_slot_conflicts_game"("p_space" "uuid", "p_start" timestamp with time zone, "p_end" timestamp with time zone) RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select exists(
    select 1 from public.games g
    where g.venue_space_id = p_space
      and g.is_cancelled = false
      and tstzrange(g.start_at, g.end_at, '[)') && tstzrange(p_start, p_end, '[)')
  );
$$;


ALTER FUNCTION "public"."_slot_conflicts_game"("p_space" "uuid", "p_start" timestamp with time zone, "p_end" timestamp with time zone) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."_slot_conflicts_game"("p_space" "uuid", "p_start" timestamp with time zone, "p_end" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."_slot_conflicts_game"("p_space" "uuid", "p_start" timestamp with time zone, "p_end" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_slot_conflicts_game"("p_space" "uuid", "p_start" timestamp with time zone, "p_end" timestamp with time zone) TO "service_role";

CREATE OR REPLACE FUNCTION "public"."rpc_booking_cancel"("p_booking_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  b          record;
  vid        uuid;
  owner_user uuid;
BEGIN
  SELECT * INTO b FROM public.venue_bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='booking_not_found'; END IF;

  SELECT s.venue_id INTO vid FROM public.venue_spaces s WHERE s.id = b.venue_space_id;

  owner_user := CASE
    WHEN b.source_type = 'game'   THEN (SELECT creator_user_id FROM public.games   WHERE id = b.source_id)
    WHEN b.source_type = 'meetup' THEN (SELECT creator_user_id FROM public.meetups WHERE id = b.source_id)
    ELSE NULL
  END;

  IF NOT (public.is_venue_admin(auth.uid(), vid)
          OR public.is_admin(auth.uid())
          OR owner_user = auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_authorized';
  END IF;

  UPDATE public.venue_bookings SET status = 'cancelled'
  WHERE id = p_booking_id AND status <> 'cancelled';

  RETURN 'ok';
END;
$$;


ALTER FUNCTION "public"."rpc_booking_cancel"("p_booking_id" "uuid") OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."rpc_booking_cancel"("p_booking_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_booking_cancel"("p_booking_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_booking_cancel"("p_booking_id" "uuid") TO "service_role";

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public._game_belongs_to_venue(uuid,uuid)',                  '6e5901ff6904c44012897b99d5b0c830'),
      ('public._slot_conflicts_game(uuid,timestamptz,timestamptz)', '42729f5c67c2b2fa453addf51fec26c6'),
      ('public.rpc_booking_cancel(uuid)',                           '97e9c289b9d768ff7212529876ecff08')) AS t(sig, want)
  LOOP
    IF md5(pg_get_functiondef(r.sig::regprocedure)) <> r.want THEN
      RAISE EXCEPTION 'KAN-728 harness: % does not match the stage catalogue pre-image', r.sig;
    END IF;
  END LOOP;
END $$;

COMMIT;
