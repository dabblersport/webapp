-- KAN-727 (KAN-714 B08, Epic KAN-708) CAPACITY / JOIN / RATING-ELIGIBILITY READ-CONVERSION PROOF.
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE (either mode).
--
-- Two modes, one file:
--   -v mode=harness   COMMITS local stand-ins the chain harness does not carry: profiles.profile_type, the six
--                     rating tables (dimensions seeded with one active key each) and three no-op recompute stubs;
--                     the dependencies rpc_join_game, _user_played_in_game, _user_hosted_game,
--                     _game_belongs_to_venue VERBATIM from the baseline (unchanged by B08); and the PRE-IMAGES of
--                     meetup_slots_left, rpc_rate_game, rpc_rate_user, rpc_rate_venue VERBATIM from the repo with their
--                     repo attributes and grants (game_slots_left is already in the chain harness). It then records
--                     pg_get_functiondef of all five in public.k727_harness_preimage (the reference k727_ref_* and the
--                     ROLLBACK SQL) and refuses unless md5(prosrc) equals the pin the migration checks.
--   (default) test    One transaction, ROLLBACK at the end; nothing is committed.
--
-- Build:
--   OLD  = build775.sh <db> ; psql -v mode=harness -f this
--   NEW  = OLD + 20261104100800_kan714_b08_capacity_join_rating_checks.sql
-- Run this file (test mode) on both:
--   NEW: every probe PASSes.  OLD (control): every [K] probe FAILs, every [=] probe PASSes.
-- Each probe: id | PASS/FAIL | expected (LIKE pattern) | actual | name.  Last line: #TOTAL|pass=N|fail=M|...
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
\if :{?mode}
\else
\set mode test
\endif
SELECT :'mode' = 'harness' AS k727_is_harness \gset

\if :k727_is_harness
-- =========================================================================================================
-- HARNESS (commits; local only)
-- =========================================================================================================
BEGIN;
DO $g$
BEGIN
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL OR to_regprocedure('public.game_slots_left(uuid)') IS NULL THEN
    RAISE EXCEPTION 'B08 harness: build the events chain first (build775.sh)';
  END IF;
  IF to_regclass('public.k727_harness_preimage') IS NOT NULL THEN
    RAISE EXCEPTION 'B08 harness: already applied';
  END IF;
  IF to_regclass('public.game_rating_events') IS NOT NULL OR to_regprocedure('public.rpc_rate_game(uuid,uuid,jsonb,text)') IS NOT NULL THEN
    RAISE EXCEPTION 'B08 harness: real rating objects exist here; this harness is for the local chain only';
  END IF;
END $g$;

-- Stand-ins (shape only what the five bodies and their dependencies read or write).
ALTER TABLE public.profiles ADD COLUMN profile_type text NOT NULL DEFAULT 'player';
CREATE TABLE public.game_rating_dimensions (key text PRIMARY KEY, weight numeric NOT NULL DEFAULT 1, is_active boolean NOT NULL DEFAULT true);
INSERT INTO public.game_rating_dimensions (key) VALUES ('skill');
CREATE TABLE public.game_rating_events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), game_id uuid, rater_user_id uuid,
  rater_profile_id uuid, scores jsonb, comment text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.reputation_dimensions (key text PRIMARY KEY, weight numeric NOT NULL DEFAULT 1, is_active boolean NOT NULL DEFAULT true,
  applicable_to text[] NOT NULL);
INSERT INTO public.reputation_dimensions (key, applicable_to) VALUES ('fair', '{rate_player,rate_organiser}');
CREATE TABLE public.user_reputation_events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), game_id uuid, rater_user_id uuid,
  rater_profile_id uuid, ratee_user_id uuid, scores jsonb, comment text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.venue_rating_dimensions (key text PRIMARY KEY, weight numeric NOT NULL DEFAULT 1, is_active boolean NOT NULL DEFAULT true);
INSERT INTO public.venue_rating_dimensions (key) VALUES ('quality');
CREATE TABLE public.venue_rating_events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), game_id uuid, venue_id uuid, rater_user_id uuid,
  rater_profile_id uuid, scores jsonb, comment text, created_at timestamptz NOT NULL DEFAULT now());
REVOKE ALL ON public.game_rating_dimensions, public.game_rating_events, public.reputation_dimensions, public.user_reputation_events,
              public.venue_rating_dimensions, public.venue_rating_events FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.game_rating_recompute(uuid) RETURNS void LANGUAGE plpgsql AS $$ BEGIN END $$;
CREATE FUNCTION public.reputation_recompute(uuid) RETURNS void LANGUAGE plpgsql AS $$ BEGIN END $$;
CREATE FUNCTION public.venue_rating_recompute(uuid) RETURNS void LANGUAGE plpgsql AS $$ BEGIN END $$;

-- ---- generated: verbatim repo DDL (dependencies + pre-images) and the pins -----------------------------
-- verbatim 20260829080500_baseline_schema.sql:13417-13467 (unchanged by B08; dependency)
CREATE OR REPLACE FUNCTION "public"."rpc_join_game"("p_actor_type" "text", "p_game_id" "uuid", "p_link_token" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("result" "text", "roster_status" "text", "waitlist_position" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  decision jsonb;
  pid uuid;
  uid uuid := auth.uid();
  g record;
  slots int;
BEGIN
  decision := public.can_current_user_join_game(p_game_id, p_actor_type, p_link_token);

  IF COALESCE((decision->>'allowed')::boolean, false) = false THEN
    RAISE EXCEPTION USING
      errcode = 'P0001',
      message = COALESCE(decision->>'cta', 'not_allowed'),
      detail  = COALESCE(decision->>'reason', '');
  END IF;

  pid := public.choose_actor(p_actor_type);

  IF (decision->>'cta') = 'join_with_link' THEN
    PERFORM public._consume_link_token(p_game_id, p_link_token);
  END IF;

  IF (decision->>'cta') = 'request' THEN
    INSERT INTO public.game_join_requests(game_id, from_profile_id, status)
    VALUES (p_game_id, pid, 'pending')
    ON CONFLICT DO NOTHING;
    result := 'request_submitted'; roster_status := NULL; waitlist_position := NULL; RETURN NEXT; RETURN;
  END IF;

  SELECT * INTO g FROM public.games WHERE id = p_game_id FOR UPDATE;
  slots := public.game_slots_left(p_game_id);

  IF slots > 0 THEN
    INSERT INTO public.game_roster(game_id, profile_id, role, status)
    VALUES (p_game_id, pid, 'player', 'active')
    ON CONFLICT (game_id, profile_id) DO UPDATE SET status='active', left_at=NULL;
    result := 'joined'; roster_status := 'active'; waitlist_position := NULL; RETURN NEXT; RETURN;
  ELSE
    INSERT INTO public.game_waitlist(game_id, profile_id, user_id, position)
    SELECT p_game_id, pid, uid,
           COALESCE((SELECT max(position)+1 FROM public.game_waitlist WHERE game_id = p_game_id), 1)
    ON CONFLICT DO NOTHING;
    waitlist_position := (SELECT position FROM public.game_waitlist WHERE game_id=p_game_id AND profile_id=pid);
    result := 'waitlisted'; roster_status := NULL; RETURN NEXT; RETURN;
  END IF;
END;
$$;
GRANT ALL ON FUNCTION public.rpc_join_game(text,uuid,uuid) TO anon, authenticated, service_role;

-- verbatim 20260829080500_baseline_schema.sql:1730-1738 (unchanged by B08; dependency)
CREATE OR REPLACE FUNCTION "public"."_user_played_in_game"("p_user_id" "uuid", "p_game_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select exists(
    select 1 from public.game_roster r
    where r.game_id = p_game_id and r.user_id = p_user_id and r.status='active'
  )
$$;
GRANT ALL ON FUNCTION public._user_played_in_game(uuid,uuid) TO anon, authenticated, service_role;

-- verbatim 20260829080500_baseline_schema.sql:1715-1724 (unchanged by B08; dependency)
CREATE OR REPLACE FUNCTION "public"."_user_hosted_game"("p_user_id" "uuid", "p_game_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.games g
    WHERE g.id = p_game_id
      AND g.creator_user_id = p_user_id
  )
$$;
GRANT ALL ON FUNCTION public._user_hosted_game(uuid,uuid) TO anon, authenticated, service_role;

-- verbatim 20260829080500_baseline_schema.sql:1074-1084 (unchanged by B08; dependency)
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
GRANT ALL ON FUNCTION public._game_belongs_to_venue(uuid,uuid) TO anon, authenticated, service_role;

CREATE TABLE public.k727_harness_preimage (sig text PRIMARY KEY, ref_name text NOT NULL, source text NOT NULL,
  repo_md5 text NOT NULL, ddl text, acl aclitem[], prosrc_md5 text, prolang text);
INSERT INTO public.k727_harness_preimage (sig, ref_name, source, repo_md5) VALUES ('public.game_slots_left(uuid)', 'k727_ref_game_slots_left', '20260829080500_baseline_schema.sql:6904-6917', '1f6418851fd9c18d36165f111a4b1f5f');

-- public.meetup_slots_left(uuid) : verbatim 20260829080500_baseline_schema.sql:8974-8983 + 20260915120000_meetups_hardening.sql:80-87
CREATE OR REPLACE FUNCTION "public"."meetup_slots_left"("p_meetup" "uuid") RETURNS integer
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select
    case when m.capacity is null then 999999
         else greatest(m.capacity - coalesce((select count(*) from public.meetup_rsvps r where r.meetup_id=m.id and r.status='going'),0), 0)
    end as slots_left
  from public.meetups m where m.id = p_meetup
$$;
ALTER FUNCTION public.meetup_slots_left(uuid) SECURITY DEFINER;
ALTER FUNCTION public.meetup_slots_left(uuid) SET search_path = public;
REVOKE ALL ON FUNCTION public.meetup_slots_left(uuid) FROM PUBLIC, anon, authenticated; GRANT EXECUTE ON FUNCTION public.meetup_slots_left(uuid) TO service_role;
INSERT INTO public.k727_harness_preimage (sig, ref_name, source, repo_md5) VALUES ('public.meetup_slots_left(uuid)', 'k727_ref_meetup_slots_left', '20260829080500_baseline_schema.sql:8974-8983 + 20260915120000_meetups_hardening.sql:80-87', 'e80d0677a9a6fee5fb507efe93c2d158');

-- public.rpc_rate_game(uuid,uuid,jsonb,text) : verbatim 20260829080500_baseline_schema.sql:14585-14633
CREATE OR REPLACE FUNCTION "public"."rpc_rate_game"("p_game_id" "uuid", "p_rater_profile_id" "uuid", "p_scores" "jsonb", "p_comment" "text" DEFAULT NULL::"text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  g record;
  prof record;
  r_user uuid;
  d record; v numeric;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;

  select id, end_at, is_cancelled into g from public.games where id=p_game_id;
  if not found or g.is_cancelled then raise exception using errcode='P0001', message='game_not_ratable'; end if;
  if now() > g.end_at + interval '7 days' then raise exception using errcode='P0001', message='rating_window_closed'; end if;

  select id, user_id, profile_type into prof from public.profiles where id=p_rater_profile_id;
  if not found or prof.user_id <> auth.uid() then raise exception using errcode='P0001', message='not_profile_owner'; end if;
  if prof.profile_type <> 'player' then raise exception using errcode='P0001', message='organiser_cannot_rate_game'; end if;
  r_user := prof.user_id;

  if not public._user_played_in_game(r_user, p_game_id) then
    raise exception using errcode='P0001', message='rater_not_in_game';
  end if;

  if exists (select 1 from public.game_rating_events where game_id=p_game_id and rater_user_id=r_user) then
    raise exception using errcode='P0001', message='already_rated';
  end if;

  if p_scores is null or jsonb_typeof(p_scores) <> 'object' then
    raise exception using errcode='P0001', message='invalid_scores';
  end if;

  for d in select key from public.game_rating_dimensions where is_active loop
    if p_scores ? d.key then
      v := (p_scores ->> d.key)::numeric;
      if v is null then raise exception using errcode='P0001', message='score_not_numeric'; end if;
      if v < 0 or v > 5 then raise exception using errcode='P0001', message='score_out_of_range'; end if;
    end if;
  end loop;

  insert into public.game_rating_events(game_id, rater_user_id, rater_profile_id, scores, comment)
  values (p_game_id, r_user, p_rater_profile_id, p_scores, left(p_comment, 280));

  perform public.game_rating_recompute(p_game_id);

  return 'ok';
end;
$$;
GRANT ALL ON FUNCTION public.rpc_rate_game(uuid,uuid,jsonb,text) TO anon, authenticated, service_role;
INSERT INTO public.k727_harness_preimage (sig, ref_name, source, repo_md5) VALUES ('public.rpc_rate_game(uuid,uuid,jsonb,text)', 'k727_ref_rate_game', '20260829080500_baseline_schema.sql:14585-14633', '195bf3e5b9bc14165fe0feba89635b3b');

-- public.rpc_rate_user(uuid,uuid,uuid,jsonb,text) : verbatim 20260829080500_baseline_schema.sql:14639-14713 + 20261027130000_kan672:18
CREATE OR REPLACE FUNCTION "public"."rpc_rate_user"("p_game_id" "uuid", "p_rater_profile_id" "uuid", "p_ratee_user_id" "uuid", "p_scores" "jsonb", "p_comment" "text" DEFAULT NULL::"text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  g              record;
  rater_user     uuid;
  rprof          record;
  ratee_is_host  boolean;
  window_ok      boolean;
  d              record;
  k text; v numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  SELECT id, creator_user_id, start_at, end_at, is_cancelled INTO g FROM public.games WHERE id = p_game_id;
  IF NOT FOUND OR g.is_cancelled THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_ratable'; END IF;

  window_ok := (now() <= g.end_at + interval '7 days');
  IF NOT window_ok THEN RAISE EXCEPTION USING errcode='P0001', message='rating_window_closed'; END IF;

  SELECT id, user_id, profile_type INTO rprof FROM public.profiles WHERE id = p_rater_profile_id;
  IF NOT FOUND OR rprof.user_id <> auth.uid() THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_profile_owner';
  END IF;
  IF rprof.profile_type <> 'player' THEN
    RAISE EXCEPTION USING errcode='P0001', message='organiser_cannot_rate_user';
  END IF;

  rater_user := rprof.user_id;

  IF NOT EXISTS (SELECT 1 FROM public.game_roster WHERE game_id = p_game_id AND user_id = rater_user AND status = 'active') THEN
    RAISE EXCEPTION USING errcode='P0001', message='rater_not_in_game';
  END IF;

  ratee_is_host := (p_ratee_user_id = g.creator_user_id);
  IF NOT ratee_is_host AND NOT EXISTS (
    SELECT 1 FROM public.game_roster WHERE game_id = p_game_id AND user_id = p_ratee_user_id AND status = 'active'
  ) THEN RAISE EXCEPTION USING errcode='P0001', message='ratee_not_in_game'; END IF;

  IF p_ratee_user_id = rater_user THEN
    RAISE EXCEPTION USING errcode='P0001', message='cannot_rate_self';
  END IF;

  IF EXISTS (SELECT 1 FROM public.user_reputation_events WHERE game_id = p_game_id AND rater_user_id = rater_user AND ratee_user_id = p_ratee_user_id) THEN
    RAISE EXCEPTION USING errcode='P0001', message='already_rated';
  END IF;

  IF p_scores IS NULL OR jsonb_typeof(p_scores) <> 'object' THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_scores';
  END IF;

  FOR d IN
    SELECT key FROM public.reputation_dimensions
    WHERE is_active = true
      AND (
        (ratee_is_host     AND 'rate_organiser' = ANY(applicable_to)) OR
        (NOT ratee_is_host AND 'rate_player'    = ANY(applicable_to))
      )
  LOOP
    k := d.key;
    IF p_scores ? k THEN
      v := (p_scores ->> k)::numeric;
      IF v IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='score_not_numeric'; END IF;
      IF v < 0 OR v > 5 THEN RAISE EXCEPTION USING errcode='P0001', message='score_out_of_range'; END IF;
    END IF;
  END LOOP;

  INSERT INTO public.user_reputation_events(game_id, rater_user_id, rater_profile_id, ratee_user_id, scores, comment)
  VALUES (p_game_id, rater_user, p_rater_profile_id, p_ratee_user_id, p_scores, LEFT(p_comment, 280));

  PERFORM public.reputation_recompute(p_ratee_user_id);
  RETURN 'ok';
END;
$$;
GRANT ALL ON FUNCTION public.rpc_rate_user(uuid,uuid,uuid,jsonb,text) TO anon, authenticated, service_role; REVOKE ALL ON FUNCTION public.rpc_rate_user(uuid,uuid,uuid,jsonb,text) FROM PUBLIC, anon;
INSERT INTO public.k727_harness_preimage (sig, ref_name, source, repo_md5) VALUES ('public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)', 'k727_ref_rate_user', '20260829080500_baseline_schema.sql:14639-14713 + 20261027130000_kan672:18', '12cb3bf4c0fa33a6a8f11aec94da1e96');

-- public.rpc_rate_venue(uuid,uuid,uuid,jsonb,text) : verbatim 20260829080500_baseline_schema.sql:14719-14777
CREATE OR REPLACE FUNCTION "public"."rpc_rate_venue"("p_game_id" "uuid", "p_venue_id" "uuid", "p_rater_profile_id" "uuid", "p_scores" "jsonb", "p_comment" "text" DEFAULT NULL::"text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  g      record;
  prof   record;
  r_user uuid;
  d record; v numeric;
  tied boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  SELECT id, creator_user_id, end_at, is_cancelled INTO g FROM public.games WHERE id = p_game_id;
  IF NOT FOUND OR g.is_cancelled THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_ratable'; END IF;

  IF NOT public._game_belongs_to_venue(p_game_id, p_venue_id) THEN
    RAISE EXCEPTION USING errcode='P0001', message='venue_mismatch';
  END IF;
  IF now() > g.end_at + interval '7 days' THEN
    RAISE EXCEPTION USING errcode='P0001', message='rating_window_closed';
  END IF;

  SELECT id, user_id, profile_type INTO prof FROM public.profiles WHERE id = p_rater_profile_id;
  IF NOT FOUND OR prof.user_id <> auth.uid() THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_profile_owner';
  END IF;
  r_user := prof.user_id;

  IF prof.profile_type = 'player' THEN
    tied := public._user_played_in_game(r_user, p_game_id);
  ELSE
    tied := public._user_hosted_game(r_user, p_game_id);
  END IF;
  IF NOT tied THEN RAISE EXCEPTION USING errcode='P0001', message='rater_not_tied_to_game'; END IF;

  IF EXISTS (SELECT 1 FROM public.venue_rating_events WHERE game_id = p_game_id AND venue_id = p_venue_id AND rater_user_id = r_user) THEN
    RAISE EXCEPTION USING errcode='P0001', message='already_rated';
  END IF;

  IF p_scores IS NULL OR jsonb_typeof(p_scores) <> 'object' THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_scores';
  END IF;

  FOR d IN SELECT key FROM public.venue_rating_dimensions WHERE is_active LOOP
    IF p_scores ? d.key THEN
      v := (p_scores ->> d.key)::numeric;
      IF v IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='score_not_numeric'; END IF;
      IF v < 0 OR v > 5 THEN RAISE EXCEPTION USING errcode='P0001', message='score_out_of_range'; END IF;
    END IF;
  END LOOP;

  INSERT INTO public.venue_rating_events(game_id, venue_id, rater_user_id, rater_profile_id, scores, comment)
  VALUES (p_game_id, p_venue_id, r_user, p_rater_profile_id, p_scores, LEFT(p_comment, 280));

  PERFORM public.venue_rating_recompute(p_venue_id);
  RETURN 'ok';
END;
$$;
GRANT ALL ON FUNCTION public.rpc_rate_venue(uuid,uuid,uuid,jsonb,text) TO anon, authenticated, service_role;
INSERT INTO public.k727_harness_preimage (sig, ref_name, source, repo_md5) VALUES ('public.rpc_rate_venue(uuid,uuid,uuid,jsonb,text)', 'k727_ref_rate_venue', '20260829080500_baseline_schema.sql:14719-14777', '2bce0cd675ee5865731d05adb90883e9');

-- ---- end generated -------------------------------------------------------------------------------------

DO $h$
DECLARE r record; v_name text; v_ddl text;
BEGIN
  FOR r IN SELECT * FROM public.k727_harness_preimage ORDER BY sig LOOP
    SELECT p.proname, pg_get_functiondef(p.oid) INTO v_name, v_ddl FROM pg_proc p WHERE p.oid = to_regprocedure(r.sig);
    IF v_ddl IS NULL THEN RAISE EXCEPTION 'B08 harness: % missing', r.sig; END IF;
    UPDATE public.k727_harness_preimage h SET ddl = v_ddl, acl = p.proacl, prosrc_md5 = md5(p.prosrc), prolang = l.lanname
      FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
     WHERE p.oid = to_regprocedure(r.sig) AND h.sig = r.sig;
    -- the reference twin: same text, other name, never granted to an API role
    EXECUTE replace(v_ddl, 'public.' || v_name || '(', 'public.' || r.ref_name || '(');
    EXECUTE format('REVOKE ALL ON FUNCTION public.%I FROM PUBLIC, anon, authenticated, service_role', r.ref_name);
  END LOOP;
  IF EXISTS (SELECT 1 FROM public.k727_harness_preimage WHERE prosrc_md5 IS DISTINCT FROM repo_md5) THEN
    RAISE EXCEPTION 'B08 harness: a pre-image body differs from its repo pin: %',
      (SELECT string_agg(sig || ' ' || prosrc_md5 || '<>' || repo_md5, '; ') FROM public.k727_harness_preimage WHERE prosrc_md5 IS DISTINCT FROM repo_md5);
  END IF;
END $h$;
REVOKE ALL ON public.k727_harness_preimage FROM PUBLIC, anon, authenticated, service_role;
SELECT 'harness|' || sig || '|' || prolang || '|md5=' || prosrc_md5 FROM public.k727_harness_preimage ORDER BY sig;
COMMIT;
\quit
\endif

-- =========================================================================================================
-- TEST (one transaction, rolled back)
-- =========================================================================================================
BEGIN;
SET LOCAL lock_timeout = '3s';
DO $g$ BEGIN
  IF to_regclass('public.k727_harness_preimage') IS NULL THEN RAISE EXCEPTION 'run -v mode=harness first'; END IF;
END $g$;
SELECT 'mode|' || CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'game_slots_left' AND prosrc LIKE '%KAN-727%')
                       THEN 'NEW (B08 applied)' ELSE 'OLD (control, no B08)' END;

CREATE TEMP SEQUENCE t_pass; CREATE TEMP SEQUENCE t_fail; CREATE TEMP SEQUENCE t_kfail; CREATE TEMP SEQUENCE t_eqfail;
CREATE FUNCTION pg_temp.chk(p_id text, p_name text, p_expected text, p_actual text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v_ok boolean := coalesce(p_actual, '<null>') LIKE p_expected;
BEGIN
  IF v_ok THEN PERFORM nextval('t_pass'); ELSE
    PERFORM nextval('t_fail');
    IF p_id LIKE '%[K]%' THEN PERFORM nextval('t_kfail'); ELSE PERFORM nextval('t_eqfail'); END IF;
  END IF;
  RETURN p_id || '|' || CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END || '|' || p_expected || '|' || coalesce(p_actual, '<null>') || '|' || p_name;
END $$;
CREATE FUNCTION pg_temp.tally(p text) RETURNS bigint LANGUAGE sql AS $$
  SELECT CASE p WHEN 'pass' THEN (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_pass)
                WHEN 'fail' THEN (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_fail)
                WHEN 'kfail' THEN (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_kfail)
                ELSE (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_eqfail) END $$;
-- Run p_sql (one text value) as database role p_role with auth.uid() = p_uid (NULL = no JWT subject).
-- p_keep = false: the call and everything it wrote is rolled back (subtransaction); true: its writes stay.
-- Returns 'ret:<value>' or '<SQLSTATE>:<message>' -- the error code and message the client would see.
CREATE FUNCTION pg_temp.call(p_uid uuid, p_role text, p_sql text, p_keep boolean DEFAULT false) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    IF NOT p_keep THEN RAISE EXCEPTION USING errcode = 'KR001', message = coalesce(v, '<null>'); END IF;
    RESET ROLE;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    RETURN 'ret:' || coalesce(v, '<null>');
  EXCEPTION
    WHEN sqlstate 'KR001' THEN RETURN 'ret:' || SQLERRM;
    WHEN OTHERS THEN RETURN SQLSTATE || ':' || SQLERRM;
  END;
END $$;
-- rpc_join_game as a signed-in client (authenticated): 'result|roster_status|waitlist_position'
CREATE FUNCTION pg_temp.join(p_uid uuid, p_game uuid, p_keep boolean DEFAULT false) RETURNS text LANGUAGE sql AS $$
  SELECT pg_temp.call(p_uid, 'authenticated', format(
    'SELECT r.result || ''|'' || coalesce(r.roster_status, ''-'') || ''|'' || coalesce(r.waitlist_position::text, ''-'') FROM public.rpc_join_game(''player'', %L::uuid) r', p_game), p_keep) $$;
-- can_current_user_join_game as rpc_join_game reaches it (inside a DEFINER: events readable): 'allowed|cta|reason'
CREATE FUNCTION pg_temp.can(p_uid uuid, p_game uuid) RETURNS text LANGUAGE sql AS $$
  SELECT pg_temp.call(p_uid, 'postgres', format(
    'SELECT (d->>''allowed'') || ''|'' || (d->>''cta'') || ''|'' || coalesce(d->>''reason'', ''-'') FROM public.can_current_user_join_game(%L::uuid, ''player'') d', p_game)) $$;
-- a rating RPC as authenticated vs its pre-image twin with the same auth.uid(): '<new> ~ same' or '<new> ~ ref=<ref>'
CREATE FUNCTION pg_temp.rate(p_fn text, p_uid uuid, p_args text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE a text; b text;
BEGIN
  a := pg_temp.call(p_uid, 'authenticated', 'SELECT public.' || p_fn || '(' || p_args || ')');
  b := pg_temp.call(p_uid, 'postgres', 'SELECT public.' || (SELECT ref_name FROM public.k727_harness_preimage WHERE sig LIKE 'public.' || p_fn || '(%') || '(' || p_args || ')');
  RETURN a || ' ~ ' || CASE WHEN a = b THEN 'same' ELSE 'ref=' || b END;
END $$;
-- only the new side (for divergence probes, where the pre-image is expected to answer differently)
CREATE FUNCTION pg_temp.rate1(p_fn text, p_uid uuid, p_args text) RETURNS text LANGUAGE sql AS $$
  SELECT pg_temp.call(p_uid, 'authenticated', 'SELECT public.' || p_fn || '(' || p_args || ')') $$;
-- events scans so far in this transaction (seq + index)
CREATE FUNCTION pg_temp.ev_scans() RETURNS bigint LANGUAGE sql AS $$
  SELECT coalesce(seq_scan, 0) + coalesce(idx_scan, 0) FROM pg_stat_xact_user_tables WHERE relid = 'public.events'::regclass $$;
-- data fingerprint the rollback must preserve
CREATE FUNCTION pg_temp.data_md5() RETURNS text LANGUAGE sql AS $$
  SELECT md5((SELECT string_agg(g::text, '|' ORDER BY g.id) FROM public.games g) || '#'
          || (SELECT string_agg(m::text, '|' ORDER BY m.id) FROM public.meetups m) || '#'
          || (SELECT string_agg(e::text, '|' ORDER BY e.id) FROM public.events e) || '#'
          || (SELECT coalesce(string_agg(r::text, '|' ORDER BY r::text), '') FROM public.game_roster r) || '#'
          || (SELECT coalesce(string_agg(w::text, '|' ORDER BY w::text), '') FROM public.game_waitlist w) || '#'
          || (SELECT coalesce(string_agg(x::text, '|' ORDER BY x::text), '') FROM public.meetup_rsvps x) || '#'
          || (SELECT coalesce(string_agg(x::text, '|' ORDER BY x::text), '') FROM public.game_rating_events x) || '#'
          || (SELECT coalesce(string_agg(x::text, '|' ORDER BY x::text), '') FROM public.user_reputation_events x) || '#'
          || (SELECT coalesce(string_agg(x::text, '|' ORDER BY x::text), '') FROM public.venue_rating_events x)) $$;
-- plan walk: one boolean per events scan node, true when it sits under a SubPlan / InitPlan (per-row re-read)
CREATE FUNCTION pg_temp.ev_nodes(n jsonb, sub boolean) RETURNS SETOF boolean LANGUAGE plpgsql AS $$
DECLARE c jsonb; s boolean;
BEGIN
  s := sub OR coalesce(n->>'Parent Relationship', '') IN ('SubPlan', 'InitPlan');
  IF n->>'Relation Name' = 'events' THEN RETURN NEXT s; END IF;
  FOR c IN SELECT * FROM jsonb_array_elements(coalesce(n->'Plans', '[]'::jsonb)) LOOP
    RETURN QUERY SELECT * FROM pg_temp.ev_nodes(c, s);
  END LOOP;
END $$;
-- EXPLAIN a SQL function's own body: prosrc with named parameters rewritten to $n, PREPAREd, EXPLAINed.
CREATE FUNCTION pg_temp.plan_shape(p_sig text, p_types text, p_names text[], p_args text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE src text; i int; plan jsonb; v text;
BEGIN
  SELECT prosrc INTO src FROM pg_proc WHERE oid = to_regprocedure(p_sig);
  FOR i IN 1 .. array_length(p_names, 1) LOOP
    src := regexp_replace(src, '\m' || p_names[i] || '\M', '$' || i, 'g');
  END LOOP;
  src := regexp_replace(src, '--[^\n]*', '', 'g');
  src := regexp_replace(src, ';\s*$', '');
  EXECUTE 'PREPARE k727q(' || p_types || ') AS ' || src;
  EXECUTE 'EXPLAIN (FORMAT JSON, COSTS OFF) EXECUTE k727q(' || p_args || ')' INTO plan;
  DEALLOCATE k727q;
  SELECT 'events_nodes=' || count(*) || '|under_subplan=' || count(*) FILTER (WHERE s)
    INTO v FROM pg_temp.ev_nodes(plan->0->'Plan', false) s;
  RETURN v;
END $$;
-- the five targets with their reference twins
CREATE TEMP VIEW tgt AS
  SELECT h.*, p.oid AS new_oid, r.oid AS ref_oid
    FROM public.k727_harness_preimage h
    JOIN pg_proc p ON p.oid = to_regprocedure(h.sig)
    JOIN pg_proc r ON r.proname = h.ref_name AND r.pronamespace = 'public'::regnamespace;

-- ---------------------------------------------------------------------------------------------------------
-- Seed (rolled back).
-- Chain seed used: a1's future open public game 71300..01 (capacity 10, roster a4 active); a1 has blocked a6;
-- a1's open public game 10000..06 (ended 2026-01). Meetup 71300..101 (capacity NULL = unlimited).
-- Rating fixture on 10000..06: start/end set to now()-3h / now()-1h on BOTH games and events (kept in sync),
-- venue space ee11 (venue ee01), roster a3 + a4 active; profile b5 is an organiser.
-- ---------------------------------------------------------------------------------------------------------
\set G1 '''71300000-0000-0000-0000-000000000001'''
\set G6 '''10000000-0000-0000-0000-000000000006'''
\set GOLD '''10000000-0000-0000-0000-000000000001'''
\set M1 '''71300000-0000-0000-0000-000000000101'''
\set a1 '''00000000-0000-0000-0000-0000000000a1'''
\set a2 '''00000000-0000-0000-0000-0000000000a2'''
\set a3 '''00000000-0000-0000-0000-0000000000a3'''
\set a4 '''00000000-0000-0000-0000-0000000000a4'''
\set a5 '''00000000-0000-0000-0000-0000000000a5'''
\set a6 '''00000000-0000-0000-0000-0000000000a6'''
\set a7 '''00000000-0000-0000-0000-0000000000a7'''
\set b1 '''00000000-0000-0000-0000-0000000000b1'''
\set b3 '''00000000-0000-0000-0000-0000000000b3'''
\set b4 '''00000000-0000-0000-0000-0000000000b4'''
\set b5 '''00000000-0000-0000-0000-0000000000b5'''
\set b7 '''00000000-0000-0000-0000-0000000000b7'''
\set V1 '''00000000-0000-0000-0000-00000000ee01'''
\set V2 '''00000000-0000-0000-0000-00000000ee02'''

SET LOCAL session_replication_role = replica;
UPDATE public.games  SET start_at = now() - interval '3 hours', end_at = now() - interval '1 hour',
                         venue_space_id = '00000000-0000-0000-0000-00000000ee11' WHERE id = :G6;
UPDATE public.events SET start_at = now() - interval '3 hours', end_at = now() - interval '1 hour'
 WHERE id = (SELECT event_id FROM public.games WHERE id = :G6);
SET LOCAL session_replication_role = origin;
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
VALUES (:G6, :a3, :b3, 'player', 'active'), (:G6, :a4, :b4, 'player', 'active');
UPDATE public.profiles SET profile_type = 'organiser' WHERE id = :b5;
-- The local harness enables RLS on games with no policy, so a client sees no game at all and every client-side
-- game_slots_left would be a vacuous 0. Production lets clients read open games; stand that in (rolled back) so
-- E2/K4 compare real numbers on the client (legacy) branch.
CREATE POLICY k727_client_read ON public.games FOR SELECT TO authenticated USING (true);
GRANT EXECUTE ON FUNCTION public.k727_ref_game_slots_left(uuid) TO authenticated;   -- rolled back; lets E2 compare as a client
CREATE TEMP TABLE fx AS SELECT pg_temp.data_md5() AS data0;

-- Rating argument lists (uuid literals already quoted by the \set above)
\set RG_OK  :G6 '::uuid, ' :b3 '::uuid, ''{"skill":4}''::jsonb'
\set RU_OK  :G6 '::uuid, ' :b3 '::uuid, ' :a4 '::uuid, ''{"fair":4}''::jsonb'
\set RV_OK  :G6 '::uuid, ' :V1 '::uuid, ' :b3 '::uuid, ''{"quality":4}''::jsonb'

-- ---------------------------------------------------------------------------------------------------------
-- S. Signatures, attributes, grants
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('S1 [=]', 'result type + arguments identical to the pre-image, all 5', '5|0',
  (SELECT count(*) || '|' || count(*) FILTER (WHERE pg_get_function_result(new_oid) <> pg_get_function_result(ref_oid)
                                               OR pg_get_function_arguments(new_oid) <> pg_get_function_arguments(ref_oid)) FROM tgt));
SELECT pg_temp.chk('S2 [=]', 'owner postgres, ACL, SECURITY DEFINER, search_path, STABLE/VOLATILE unchanged vs the recorded pre-image', '5|0',
  (SELECT count(*) || '|' || count(*) FILTER (WHERE p.proacl IS DISTINCT FROM t.acl OR p.proowner <> 'postgres'::regrole
                                               OR p.prosecdef <> r.prosecdef OR p.proconfig IS DISTINCT FROM r.proconfig
                                               OR p.provolatile <> r.provolatile)
     FROM tgt t JOIN pg_proc p ON p.oid = t.new_oid JOIN pg_proc r ON r.oid = t.ref_oid));
SELECT pg_temp.chk('S3 [=]', 'grants: slots_left game anon|auth, meetup anon|auth|service, rate_game anon, rate_user anon|auth, rate_venue auth',
  'true|true|false|false|true|true|false|true|true',
  has_function_privilege('anon', 'public.game_slots_left(uuid)', 'EXECUTE') || '|' ||
  has_function_privilege('authenticated', 'public.game_slots_left(uuid)', 'EXECUTE') || '|' ||
  has_function_privilege('anon', 'public.meetup_slots_left(uuid)', 'EXECUTE') || '|' ||
  has_function_privilege('authenticated', 'public.meetup_slots_left(uuid)', 'EXECUTE') || '|' ||
  has_function_privilege('service_role', 'public.meetup_slots_left(uuid)', 'EXECUTE') || '|' ||
  has_function_privilege('anon', 'public.rpc_rate_game(uuid,uuid,jsonb,text)', 'EXECUTE') || '|' ||
  has_function_privilege('anon', 'public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)', 'EXECUTE') || '|' ||
  has_function_privilege('authenticated', 'public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)', 'EXECUTE') || '|' ||
  has_function_privilege('authenticated', 'public.rpc_rate_venue(uuid,uuid,uuid,jsonb,text)', 'EXECUTE'));
SELECT pg_temp.chk('S4 [K]', 'every converted body reads its parent through events on the FK with event_type pinned', '5',
  (SELECT count(*)::text FROM tgt t JOIN pg_proc p ON p.oid = t.new_oid
    WHERE p.prosrc ~* 'join public\.events e on e\.id = (g|g0|m)\.event_id and e\.event_type = ''(game|meetup)'''));
SELECT pg_temp.chk('S5 [=]', 'none of the five is on the KAN-712 wrap list, no *_kan712_inner twin', '0|0',
  (SELECT count(*) FROM public.kan712_wrapped_rpcs w
    WHERE w::text ~ '(game_slots_left|meetup_slots_left|rpc_rate_game|rpc_rate_user|rpc_rate_venue)') || '|' ||
  (SELECT count(*) FROM pg_proc WHERE proname ~ '^(game_slots_left|meetup_slots_left|rpc_rate_game|rpc_rate_user|rpc_rate_venue)_kan712_inner$'));

-- ---------------------------------------------------------------------------------------------------------
-- E. Equivalence with the pre-image while events and the legacy rows agree
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('E1 [=]', 'game_slots_left = pre-image for every game (as postgres: events branch)', '10|0',
  (SELECT count(*) || '|' || count(*) FILTER (WHERE public.game_slots_left(id) IS DISTINCT FROM public.k727_ref_game_slots_left(id)) FROM public.games));
SELECT pg_temp.chk('E2 [=]', 'game_slots_left as a signed-in client: no 42501 (events not readable), same values as the pre-image', 'same|ret:%',
  (WITH ids AS (SELECT quote_literal(array_agg(id ORDER BY id)::text) AS lit FROM public.games),
        a AS (SELECT pg_temp.call(:a3, 'authenticated', 'SELECT string_agg(public.game_slots_left(x)::text, '','' ORDER BY x) FROM unnest(' || lit || '::uuid[]) x') v FROM ids),
        b AS (SELECT pg_temp.call(:a3, 'authenticated', 'SELECT string_agg(public.k727_ref_game_slots_left(x)::text, '','' ORDER BY x) FROM unnest(' || lit || '::uuid[]) x') v FROM ids)
   SELECT CASE WHEN a.v = b.v THEN 'same' ELSE 'DIFF' END || '|' || a.v FROM a, b));
SELECT pg_temp.chk('E3 [=]', 'unknown game: 0 slots (pre-image GREATEST(NULL,0) = 0), as postgres and as anon', '0|0|ret:0',
  public.game_slots_left(gen_random_uuid()) || '|' || public.k727_ref_game_slots_left(gen_random_uuid()) || '|' ||
  pg_temp.call(NULL, 'anon', 'SELECT public.game_slots_left(gen_random_uuid())::text'));
SELECT pg_temp.chk('E4 [=]', 'meetup_slots_left = pre-image for every meetup (NULL capacity -> 999999 kept)', '11|0|999999',
  (SELECT count(*) || '|' || count(*) FILTER (WHERE public.meetup_slots_left(id) IS DISTINCT FROM public.k727_ref_meetup_slots_left(id)) FROM public.meetups)
  || '|' || public.meetup_slots_left(:M1));
SELECT pg_temp.chk('E5 [=]', 'unknown meetup: NULL (no row), not 0 and not 999999', '<null>|<null>',
  coalesce(public.meetup_slots_left(gen_random_uuid())::text, '<null>') || '|' || coalesce(public.k727_ref_meetup_slots_left(gen_random_uuid())::text, '<null>'));
SAVEPOINT e6;
SET LOCAL session_replication_role = replica;
UPDATE public.games SET game_type = 'hosted' WHERE id = :G1;                  -- subtype-only field
SET LOCAL session_replication_role = origin;
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status) VALUES (:G1, :a1, :b1, 'host', 'active');
SELECT pg_temp.chk('E6 [=]', 'hosted game: the host seat counts (games.game_type kept on the subtype): 10 - (a4 + host) = 8, = pre-image', '8|8',
  public.game_slots_left(:G1) || '|' || public.k727_ref_game_slots_left(:G1));
ROLLBACK TO SAVEPOINT e6;

-- ---------------------------------------------------------------------------------------------------------
-- J. The last slot and a full game, through the real client path (rpc_join_game as authenticated).
--    Events capacity set to 3 by a normal write (KAN-712 mirrors it to games); roster a4 + a2 -> 1 slot left.
-- ---------------------------------------------------------------------------------------------------------
SAVEPOINT j;
UPDATE public.events SET capacity = 3 WHERE id = (SELECT event_id FROM public.games WHERE id = :G1);
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status) VALUES (:G1, :a2, '00000000-0000-0000-0000-0000000000b2', 'player', 'active');
SELECT pg_temp.chk('J0 [=]', 'fixture: events and games capacity both 3 (mirrored), 1 slot left', '3|3|1',
  (SELECT e.capacity || '|' || g.capacity FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = :G1) || '|' || public.game_slots_left(:G1));
SELECT pg_temp.chk('J1 [=]', 'last slot: a3 may join (cta join)', 'ret:true|join|-', pg_temp.can(:a3, :G1));
SELECT pg_temp.chk('J2 [=]', 'last slot: a3 rpc_join_game -> joined, active (result shape unchanged)', 'ret:joined|active|-', pg_temp.join(:a3, :G1, true));
SELECT pg_temp.chk('J3 [=]', 'now full: 0 slots', '0', public.game_slots_left(:G1)::text);
SELECT pg_temp.chk('J4 [=]', 'full: a5 is not admitted -- allowed, cta waitlist, reason full (unchanged contract)', 'ret:true|waitlist|full', pg_temp.can(:a5, :G1));
SELECT pg_temp.chk('J5 [=]', 'full: a5 rpc_join_game -> waitlisted at position 1, never on the roster', 'ret:waitlisted|-|1', pg_temp.join(:a5, :G1, true));
SELECT pg_temp.chk('J6 [=]', 'roster: 3 active rows = 3 distinct profiles (a4, a2, a3), a5 absent; waitlist 1 row', '3|3|0|1',
  (SELECT count(*) || '|' || count(DISTINCT profile_id) || '|' || count(*) FILTER (WHERE profile_id = '00000000-0000-0000-0000-0000000000b5')
     FROM public.game_roster WHERE game_id = :G1 AND status = 'active') || '|' ||
  (SELECT count(*) FROM public.game_waitlist WHERE game_id = :G1));
SELECT pg_temp.chk('J7 [=]', 'a3 joining again: refused P0001 joined (no second row)', 'P0001:joined|1',
  pg_temp.join(:a3, :G1) || '|' || (SELECT count(*) FROM public.game_roster WHERE game_id = :G1 AND profile_id = :b3));
SELECT pg_temp.chk('J8 [=]', 'blocked a6 (a1 blocks a6) gains nothing: P0001 not_visible', 'P0001:not_visible', pg_temp.join(:a6, :G1));
SELECT pg_temp.chk('J9 [=]', 'anon: P0001 not_allowed', 'P0001:not_allowed', pg_temp.call(NULL, 'anon',
  'SELECT r.result FROM public.rpc_join_game(''player'', ''71300000-0000-0000-0000-000000000001''::uuid) r'));
UPDATE public.events SET is_cancelled = true, cancelled_at = now() WHERE id = (SELECT event_id FROM public.games WHERE id = :G1);
SELECT pg_temp.chk('J10 [=]', 'cancelled on events (mirrored): a7 refused P0001 cancelled', 'P0001:cancelled', pg_temp.join(:a7, :G1));
ROLLBACK TO SAVEPOINT j;

-- ---------------------------------------------------------------------------------------------------------
-- K. Source of truth = events. Each divergence is made with the mirror/guard triggers off
--    (session_replication_role = replica) inside a SAVEPOINT, so events and the legacy row disagree, then undone.
--    Roster on 71300..01 is a4 + a2 (2 active).
-- ---------------------------------------------------------------------------------------------------------
SAVEPOINT k1;
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status) VALUES (:G1, :a2, '00000000-0000-0000-0000-0000000000b2', 'player', 'active');
SET LOCAL session_replication_role = replica;
UPDATE public.events SET capacity = 2 WHERE id = (SELECT event_id FROM public.games WHERE id = :G1);   -- events: full; legacy: 10
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('K0 [=]', 'divergence established: events capacity 2, games capacity 10', '2|10',
  (SELECT e.capacity || '|' || g.capacity FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = :G1));
SELECT pg_temp.chk('K1 [K]', 'full on events, room on legacy: slots = 0 (events)', '0', public.game_slots_left(:G1)::text);
SELECT pg_temp.chk('K2 [K]', 'full on events: a3 not admitted -- cta waitlist, reason full', 'ret:true|waitlist|full', pg_temp.can(:a3, :G1));
SELECT pg_temp.chk('K3 [K]', 'full on events: a3 rpc_join_game -> waitlisted (pre-image: joined)', 'ret:waitlisted|-|1', pg_temp.join(:a3, :G1));
SELECT pg_temp.chk('K4 [=]', 'a client calling game_slots_left directly keeps the pre-image read (no events grant, no new exposure)', 'ret:8',
  pg_temp.call(:a3, 'authenticated', 'SELECT public.game_slots_left(''71300000-0000-0000-0000-000000000001'')::text'));
ROLLBACK TO SAVEPOINT k1;

SAVEPOINT k2;
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status) VALUES (:G1, :a2, '00000000-0000-0000-0000-0000000000b2', 'player', 'active');
SET LOCAL session_replication_role = replica;
UPDATE public.games  SET capacity = 2 WHERE id = :G1;                                                  -- legacy: full
UPDATE public.events SET capacity = 5 WHERE id = (SELECT event_id FROM public.games WHERE id = :G1);   -- events: 3 left
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('K5 [K]', 'room on events, full on legacy: slots = 3 (events)', '3', public.game_slots_left(:G1)::text);
SELECT pg_temp.chk('K6 [K]', 'room on events: a3 rpc_join_game -> joined (pre-image: waitlisted)', 'ret:joined|active|-', pg_temp.join(:a3, :G1));
ROLLBACK TO SAVEPOINT k2;

SAVEPOINT k3;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET is_cancelled = true, cancelled_at = now() WHERE id = (SELECT event_id FROM public.games WHERE id = :G1);
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('K7 [=]', 'cancelled on events only: a3 refused P0001 cancelled (KAN-713 check; B08 keeps it)', 'P0001:cancelled|0',
  pg_temp.join(:a3, :G1) || '|' || (SELECT count(*) FROM public.game_roster WHERE game_id = :G1 AND profile_id = :b3));
ROLLBACK TO SAVEPOINT k3;

SAVEPOINT k4;
SET LOCAL session_replication_role = replica;
UPDATE public.games SET is_cancelled = true WHERE id = :G1;
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('K8 [=]', 'cancelled on legacy only: still refused P0001 cancelled (never widened)', 'P0001:cancelled', pg_temp.join(:a3, :G1));
ROLLBACK TO SAVEPOINT k4;

SAVEPOINT k5;
INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status)
VALUES (:M1, :a2, '00000000-0000-0000-0000-0000000000b2', 'going'), (:M1, :a3, :b3, 'going'), (:M1, :a4, :b4, 'maybe');
UPDATE public.events SET capacity = 2 WHERE id = (SELECT event_id FROM public.meetups WHERE id = :M1);   -- normal write, mirrored
SELECT pg_temp.chk('K9 [=]', 'meetup synced at capacity 2 with 2 going (maybe not counted): full, = pre-image', '2|2|0|0',
  (SELECT e.capacity || '|' || m.capacity FROM public.meetups m JOIN public.events e ON e.id = m.event_id WHERE m.id = :M1) || '|'
  || public.meetup_slots_left(:M1) || '|' || public.k727_ref_meetup_slots_left(:M1));
SET LOCAL session_replication_role = replica;
UPDATE public.events SET capacity = 5 WHERE id = (SELECT event_id FROM public.meetups WHERE id = :M1);
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('K10 [K]', 'meetup events capacity 5 vs legacy 2: slots 3 from events', '3', public.meetup_slots_left(:M1)::text);
SET LOCAL session_replication_role = replica;
UPDATE public.events SET capacity = NULL WHERE id = (SELECT event_id FROM public.meetups WHERE id = :M1);
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('K11 [K]', 'meetup unlimited on events (NULL) vs legacy 2: 999999 from events', '999999', public.meetup_slots_left(:M1)::text);
ROLLBACK TO SAVEPOINT k5;

-- ---------------------------------------------------------------------------------------------------------
-- T. Rating eligibility. Synced fixture: every error code and 'ok' identical to the pre-image (new ~ same).
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('T1 [=]', 'rate_game: a3 played, ended 1h ago -> ok', 'ret:ok ~ same', pg_temp.rate('rpc_rate_game', :a3, :'RG_OK'));
SELECT pg_temp.chk('T2 [=]', 'rate_game: no JWT subject -> auth_required', 'P0001:auth_required ~ same', pg_temp.rate('rpc_rate_game', NULL, :'RG_OK'));
SELECT pg_temp.chk('T3 [=]', 'rate_game: a3 using b4''s profile -> not_profile_owner (non-owner gains nothing)', 'P0001:not_profile_owner ~ same',
  pg_temp.rate('rpc_rate_game', :a3, quote_literal(:G6) || '::uuid, ' || quote_literal(:b4) || '::uuid, ''{"skill":4}''::jsonb'));
SELECT pg_temp.chk('T4 [=]', 'rate_game: organiser profile -> organiser_cannot_rate_game', 'P0001:organiser_cannot_rate_game ~ same',
  pg_temp.rate('rpc_rate_game', :a5, quote_literal(:G6) || '::uuid, ' || quote_literal(:b5) || '::uuid, ''{"skill":4}''::jsonb'));
SELECT pg_temp.chk('T5 [=]', 'rate_game: a7 not on the roster -> rater_not_in_game', 'P0001:rater_not_in_game ~ same',
  pg_temp.rate('rpc_rate_game', :a7, quote_literal(:G6) || '::uuid, ' || quote_literal(:b7) || '::uuid, ''{"skill":4}''::jsonb'));
SELECT pg_temp.chk('T6 [=]', 'rate_game: scores not an object -> invalid_scores', 'P0001:invalid_scores ~ same',
  pg_temp.rate('rpc_rate_game', :a3, quote_literal(:G6) || '::uuid, ' || quote_literal(:b3) || '::uuid, ''"x"''::jsonb'));
SELECT pg_temp.chk('T7 [=]', 'rate_game: score 9 -> score_out_of_range', 'P0001:score_out_of_range ~ same',
  pg_temp.rate('rpc_rate_game', :a3, quote_literal(:G6) || '::uuid, ' || quote_literal(:b3) || '::uuid, ''{"skill":9}''::jsonb'));
SELECT pg_temp.chk('T8 [=]', 'rate_game: null score -> score_not_numeric', 'P0001:score_not_numeric ~ same',
  pg_temp.rate('rpc_rate_game', :a3, quote_literal(:G6) || '::uuid, ' || quote_literal(:b3) || '::uuid, ''{"skill":null}''::jsonb'));
SELECT pg_temp.chk('T9 [=]', 'rate_game: unknown game -> game_not_ratable', 'P0001:game_not_ratable ~ same',
  pg_temp.rate('rpc_rate_game', :a3, 'gen_random_uuid(), ' || quote_literal(:b3) || '::uuid, ''{"skill":4}''::jsonb'));
SELECT pg_temp.chk('T10 [=]', 'rate_game: game ended 2026-01 (> 7 days) -> rating_window_closed', 'P0001:rating_window_closed ~ same',
  pg_temp.rate('rpc_rate_game', :a3, quote_literal(:GOLD) || '::uuid, ' || quote_literal(:b3) || '::uuid, ''{"skill":4}''::jsonb'));
SAVEPOINT t11;
SELECT pg_temp.chk('T11a [=]', 'rate_game kept once', 'ret:ok', pg_temp.call(:a3, 'authenticated', 'SELECT public.rpc_rate_game(' || :'RG_OK' || ')', true));
SELECT pg_temp.chk('T11 [=]', 'rate_game twice -> already_rated (one row)', 'P0001:already_rated ~ same|1',
  pg_temp.rate('rpc_rate_game', :a3, :'RG_OK') || '|' || (SELECT count(*) FROM public.game_rating_events WHERE game_id = :G6));
ROLLBACK TO SAVEPOINT t11;
SELECT pg_temp.chk('T12 [=]', 'rate_user: a3 rates a4 -> ok', 'ret:ok ~ same', pg_temp.rate('rpc_rate_user', :a3, :'RU_OK'));
SELECT pg_temp.chk('T13 [=]', 'rate_user: a3 rates the host a1 (games.creator_user_id) -> ok', 'ret:ok ~ same',
  pg_temp.rate('rpc_rate_user', :a3, quote_literal(:G6) || '::uuid, ' || quote_literal(:b3) || '::uuid, ' || quote_literal(:a1) || '::uuid, ''{"fair":4}''::jsonb'));
SELECT pg_temp.chk('T14 [=]', 'rate_user: ratee a7 not in game -> ratee_not_in_game', 'P0001:ratee_not_in_game ~ same',
  pg_temp.rate('rpc_rate_user', :a3, quote_literal(:G6) || '::uuid, ' || quote_literal(:b3) || '::uuid, ' || quote_literal(:a7) || '::uuid, ''{"fair":4}''::jsonb'));
SELECT pg_temp.chk('T15 [=]', 'rate_user: self -> cannot_rate_self', 'P0001:cannot_rate_self ~ same',
  pg_temp.rate('rpc_rate_user', :a3, quote_literal(:G6) || '::uuid, ' || quote_literal(:b3) || '::uuid, ' || quote_literal(:a3) || '::uuid, ''{"fair":4}''::jsonb'));
SELECT pg_temp.chk('T16 [=]', 'rate_user: organiser -> organiser_cannot_rate_user', 'P0001:organiser_cannot_rate_user ~ same',
  pg_temp.rate('rpc_rate_user', :a5, quote_literal(:G6) || '::uuid, ' || quote_literal(:b5) || '::uuid, ' || quote_literal(:a4) || '::uuid, ''{"fair":4}''::jsonb'));
SELECT pg_temp.chk('T17 [=]', 'rate_user: a7 not in game -> rater_not_in_game', 'P0001:rater_not_in_game ~ same',
  pg_temp.rate('rpc_rate_user', :a7, quote_literal(:G6) || '::uuid, ' || quote_literal(:b7) || '::uuid, ' || quote_literal(:a4) || '::uuid, ''{"fair":4}''::jsonb'));
SELECT pg_temp.chk('T18 [=]', 'rate_user: anon has no EXECUTE (KAN-672 kept): 42501', '42501:%',
  pg_temp.call(NULL, 'anon', 'SELECT public.rpc_rate_user(' || :'RU_OK' || ')'));
SELECT pg_temp.chk('T19 [=]', 'rate_venue: a3 rates venue ee01 -> ok', 'ret:ok ~ same', pg_temp.rate('rpc_rate_venue', :a3, :'RV_OK'));
SELECT pg_temp.chk('T20 [=]', 'rate_venue: other venue -> venue_mismatch', 'P0001:venue_mismatch ~ same',
  pg_temp.rate('rpc_rate_venue', :a3, quote_literal(:G6) || '::uuid, ' || quote_literal(:V2) || '::uuid, ' || quote_literal(:b3) || '::uuid, ''{"quality":4}''::jsonb'));
SELECT pg_temp.chk('T21 [=]', 'rate_venue: a7 not tied -> rater_not_tied_to_game', 'P0001:rater_not_tied_to_game ~ same',
  pg_temp.rate('rpc_rate_venue', :a7, quote_literal(:G6) || '::uuid, ' || quote_literal(:V1) || '::uuid, ' || quote_literal(:b7) || '::uuid, ''{"quality":4}''::jsonb'));
SELECT pg_temp.chk('T22 [=]', 'rate_venue: a3 using b4 -> not_profile_owner', 'P0001:not_profile_owner ~ same',
  pg_temp.rate('rpc_rate_venue', :a3, quote_literal(:G6) || '::uuid, ' || quote_literal(:V1) || '::uuid, ' || quote_literal(:b4) || '::uuid, ''{"quality":4}''::jsonb'));

-- TK. Rating eligibility follows events.end_at and the cancel state (divergence via replica, undone each time).
SAVEPOINT tk1;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET start_at = now() - interval '10 days 2 hours', end_at = now() - interval '10 days'
 WHERE id = (SELECT event_id FROM public.games WHERE id = :G6);
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('TK1 [K]', 'events ended 10 days ago (legacy: 1h ago): game|user|venue all rating_window_closed',
  'P0001:rating_window_closed|P0001:rating_window_closed|P0001:rating_window_closed',
  pg_temp.rate1('rpc_rate_game', :a3, :'RG_OK') || '|' || pg_temp.rate1('rpc_rate_user', :a3, :'RU_OK') || '|' || pg_temp.rate1('rpc_rate_venue', :a3, :'RV_OK'));
ROLLBACK TO SAVEPOINT tk1;

SAVEPOINT tk2;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET is_cancelled = true, cancelled_at = now() WHERE id = (SELECT event_id FROM public.games WHERE id = :G6);
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('TK2 [K]', 'cancelled on events only: game|user|venue all game_not_ratable',
  'P0001:game_not_ratable|P0001:game_not_ratable|P0001:game_not_ratable',
  pg_temp.rate1('rpc_rate_game', :a3, :'RG_OK') || '|' || pg_temp.rate1('rpc_rate_user', :a3, :'RU_OK') || '|' || pg_temp.rate1('rpc_rate_venue', :a3, :'RV_OK'));
ROLLBACK TO SAVEPOINT tk2;

SAVEPOINT tk3;
SET LOCAL session_replication_role = replica;
UPDATE public.games SET start_at = now() - interval '10 days 2 hours', end_at = now() - interval '10 days' WHERE id = :G6;
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('TK3 [K]', 'legacy ended 10 days ago, events 1h ago: game|user|venue all ok (window from events)', 'ret:ok|ret:ok|ret:ok',
  pg_temp.rate1('rpc_rate_game', :a3, :'RG_OK') || '|' || pg_temp.rate1('rpc_rate_user', :a3, :'RU_OK') || '|' || pg_temp.rate1('rpc_rate_venue', :a3, :'RV_OK'));
ROLLBACK TO SAVEPOINT tk3;

SAVEPOINT tk4;
SET LOCAL session_replication_role = replica;
UPDATE public.games SET is_cancelled = true WHERE id = :G6;
SET LOCAL session_replication_role = origin;
SELECT pg_temp.chk('TK4 [=]', 'cancelled on legacy only: still game_not_ratable x3 (union, never widened)',
  'P0001:game_not_ratable|P0001:game_not_ratable|P0001:game_not_ratable',
  pg_temp.rate1('rpc_rate_game', :a3, :'RG_OK') || '|' || pg_temp.rate1('rpc_rate_user', :a3, :'RU_OK') || '|' || pg_temp.rate1('rpc_rate_venue', :a3, :'RV_OK'));
ROLLBACK TO SAVEPOINT tk4;

-- ---------------------------------------------------------------------------------------------------------
-- N. No N+1: each call reads events a fixed number of times (one keyed lookup), never once per row.
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE n_obs (k text PRIMARY KEY, v bigint);
INSERT INTO n_obs VALUES ('s0', pg_temp.ev_scans());
SELECT public.game_slots_left(:G1) IS NOT NULL AS n_dummy \gset
INSERT INTO n_obs VALUES ('s1', pg_temp.ev_scans());
SELECT pg_temp.call(:a3, 'authenticated', 'SELECT public.rpc_rate_game(' || :'RG_OK' || ')') IS NOT NULL AS n_dummy \gset
INSERT INTO n_obs VALUES ('s2', pg_temp.ev_scans());
SELECT pg_temp.call(:a3, 'authenticated', 'SELECT public.rpc_rate_user(' || :'RU_OK' || ')') IS NOT NULL AS n_dummy \gset
INSERT INTO n_obs VALUES ('s3', pg_temp.ev_scans());
SELECT pg_temp.call(:a3, 'authenticated', 'SELECT public.rpc_rate_venue(' || :'RV_OK' || ')') IS NOT NULL AS n_dummy \gset
INSERT INTO n_obs VALUES ('s4', pg_temp.ev_scans());
SELECT pg_temp.join(:a3, :G1) IS NOT NULL AS n_dummy \gset
INSERT INTO n_obs VALUES ('s5', pg_temp.ev_scans());
SELECT pg_temp.join(:a7, :G1) IS NOT NULL AS n_dummy \gset
INSERT INTO n_obs VALUES ('s6', pg_temp.ev_scans());
SELECT pg_temp.chk('N1 [K]', 'events reads per call: game_slots_left|rate_game|rate_user|rate_venue = 1 each', '1|1|1|1',
  (SELECT string_agg(d::text, '|' ORDER BY k) FROM (SELECT k, v - lag(v) OVER (ORDER BY k) AS d FROM n_obs) x WHERE k IN ('s1', 's2', 's3', 's4')));
-- rpc_join_game reads events 3 times per call: KAN-713's check itself (1, unchanged), game_slots_left called inside
-- that check (1, new) and game_slots_left called by rpc_join_game (1, new). Same count on a second game = constant.
SELECT pg_temp.chk('N2 [K]', 'rpc_join_game: 3 events reads per call (check + slots in check + slots), same for a second joiner', '3|3',
  (SELECT (v - (SELECT v FROM n_obs WHERE k = 's4'))::text FROM n_obs WHERE k = 's5') || '|' ||
  (SELECT (v - (SELECT v FROM n_obs WHERE k = 's5'))::text FROM n_obs WHERE k = 's6'));
SELECT pg_temp.chk('N3 [K]', 'meetup_slots_left plan: one events node, a join, not under a SubPlan', 'events_nodes=1|under_subplan=0',
  pg_temp.plan_shape('public.meetup_slots_left(uuid)', 'uuid', ARRAY['p_meetup'], quote_literal('71300000-0000-0000-0000-000000000101') || '::uuid'));

-- ---------------------------------------------------------------------------------------------------------
-- R. Rollback: re-run the recorded pre-image DDL (the rollback SQL), in a SAVEPOINT
-- ---------------------------------------------------------------------------------------------------------
SAVEPOINT r;
CREATE TEMP TABLE fx_r AS SELECT pg_temp.data_md5() AS before_rb;
DO $rb$ DECLARE r record; BEGIN
  FOR r IN SELECT * FROM public.k727_harness_preimage ORDER BY sig LOOP EXECUTE r.ddl; END LOOP;
END $rb$;
SELECT pg_temp.chk('R1 [=]', 'after rollback every body md5 equals the repo pin', '5',
  (SELECT count(*)::text FROM tgt t JOIN pg_proc p ON p.oid = t.new_oid WHERE md5(p.prosrc) = t.repo_md5));
SELECT pg_temp.chk('R2 [=]', 'after rollback owner, ACL, language, SECURITY DEFINER, search_path unchanged', '0',
  (SELECT count(*)::text FROM tgt t JOIN pg_proc p ON p.oid = t.new_oid JOIN pg_language l ON l.oid = p.prolang JOIN pg_proc r ON r.oid = t.ref_oid
    WHERE p.proacl IS DISTINCT FROM t.acl OR p.proowner <> 'postgres'::regrole OR l.lanname <> t.prolang
       OR p.prosecdef <> r.prosecdef OR p.proconfig IS DISTINCT FROM r.proconfig));
SELECT pg_temp.chk('R3 [=]', 'rollback is data-neutral (games, meetups, events, roster, waitlist, rsvps, rating rows)', 'true',
  (SELECT (pg_temp.data_md5() = before_rb)::text FROM fx_r));
SELECT pg_temp.chk('R4 [=]', 'after rollback output equals the pre-image (all games, all meetups, rate_game ok)', '0|0|ret:ok ~ same',
  (SELECT count(*) FILTER (WHERE public.game_slots_left(id) IS DISTINCT FROM public.k727_ref_game_slots_left(id)) FROM public.games) || '|' ||
  (SELECT count(*) FILTER (WHERE public.meetup_slots_left(id) IS DISTINCT FROM public.k727_ref_meetup_slots_left(id)) FROM public.meetups) || '|' ||
  pg_temp.rate('rpc_rate_game', :a3, :'RG_OK'));
ROLLBACK TO SAVEPOINT r;

SELECT pg_temp.chk('Z1 [=]', 'data fingerprint at the end equals the one after seeding (probes changed nothing)', 'true',
  (SELECT (pg_temp.data_md5() = data0)::text FROM fx));

SELECT '#TOTAL|pass=' || pg_temp.tally('pass') || '|fail=' || pg_temp.tally('fail')
       || '|K_fail=' || pg_temp.tally('kfail') || '|eq_fail=' || pg_temp.tally('eqfail');
ROLLBACK;
