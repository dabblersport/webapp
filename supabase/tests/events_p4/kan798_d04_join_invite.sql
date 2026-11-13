-- KAN-798 (KAN-718 D04 blockers 16, 17, 26): local proof for
-- supabase/migrations/20261104110600_kan798_d04_blockers_join_invite.sql.
--
-- LOCAL DISPOSABLE DATABASE ONLY. The guard refuses any database whose name does not start with 'k798', anything
-- that looks like Supabase, and a non-superuser. Never point this at a hosted project.
--
-- The three functions are absent from the KAN-711..714 local chain (KAN718_D04_DISPOSITION.md rows 16, 17, 26), so
-- this file installs them itself. Two phases, run in this order by the caller (the migration in between):
--
--   psql ... -d k798<x> -v ON_ERROR_STOP=1 -v phase=setup -f supabase/tests/events_p4/kan798_d04_join_invite.sql
--   psql ... -d k798<x> -v ON_ERROR_STOP=1 -f supabase/migrations/20261104110600_kan798_d04_blockers_join_invite.sql
--   [optionally KAN-719 Z01 here]
--   psql ... -d k798<x> -v ON_ERROR_STOP=1 -v phase=check -f supabase/tests/events_p4/kan798_d04_join_invite.sql
--
-- phase=setup (ONE transaction, committed, so the migration can run against it):
--   S0 local stand-ins, created ONLY IF ABSENT (marked STAND-IN): game_join_requests, game_invites, game_link_tokens,
--      game_waitlist, game_roster, harness_admins, auth.uid(), is_admin(uuid), process_notification_event(...),
--      game_slots_left(uuid). On the KAN-711..714 chain all of them already exist and nothing is created.
--   S1 the three PRE-IMAGES, VERBATIM from baseline 20260829080500 (:12064-12147, :13367-13391, :14053-14074), with
--      the baseline owner (postgres) and grants (:36235-36237, :36433-36435, :36541-36543); md5(prosrc) asserted
--      equal to the migration's pins.
--   S2 fixture (ids 79800000-*): two games through the legacy INSERT path (KAN-712 guard writes events first),
--      join requests, a full game, an admin, an organiser profile.
--   S3 BEFORE: every case below run against the pre-image, each inside a rolled-back sub-transaction, so every
--      case starts from the same rows. Result + resulting-row digest stored in kan798_t.result. Catalogue row and
--      has_function_privilege for PUBLIC/anon/authenticated/service_role stored in kan798_t.cat.
--      F-probe BEFORE (needs games.creator_user_id): events host of game 1 is diverged from the legacy column
--      (session_replication_role=replica, rolled back) and the probe records whom each function follows. On the
--      pre-image it must follow LEGACY; that is the probe seen failing.
-- phase=check (ONE transaction, ROLLED BACK; read-only in effect):
--   C1 every case runs with no 42703 (undefined_column) and no unexpected error.
--   C2 every case: AFTER result and row digest = BEFORE.
--   C3 pg_get_functiondef of the three: no Z01-removed games column read through games (g.<col> / games.<col>),
--      and the host read is the events join.
--   C4 catalogue row (oid, proargtypes, prorettype, prosecdef, proconfig, proacl, proowner, provolatile,
--      arguments, result) and has_function_privilege for PUBLIC/anon/authenticated/service_role = BEFORE.
--   F  AFTER: the functions follow EVENTS (only while games.creator_user_id still exists; skipped and said so after Z01).
-- Exit: 0 and 'KAN-798 TOTAL pass=N fail=0'; any failed check raises 'KAN-798 test FAILED'.
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF current_database() NOT LIKE 'k798%' THEN
    RAISE EXCEPTION 'KAN-798: refusing database %: local disposable k798* databases only', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-798: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-798: run as a superuser (session_replication_role and RLS-free reads need it)';
  END IF;
END $g$;

SELECT coalesce(:'phase', '') = 'setup' AS k798_setup, coalesce(:'phase', '') = 'check' AS k798_check \gset
\if :k798_setup
\elif :k798_check
\else
  \echo 'KAN-798: pass -v phase=setup or -v phase=check'
  SELECT 1/0;
\endif

\if :k798_setup
BEGIN;

-- ===================================================================================== S0 stand-ins (if absent)
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA kan798_t;  -- fails on a second setup run: one setup per disposable database
DO $s0$
BEGIN
  IF to_regprocedure('auth.uid()') IS NULL THEN  -- STAND-IN
    EXECUTE $f$CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
               AS $b$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $b$$f$;
    RAISE NOTICE 'KAN-798 S0 STAND-IN created: auth.uid()';
  END IF;
  IF to_regclass('public.harness_admins') IS NULL AND to_regprocedure('public.is_admin(uuid)') IS NULL THEN  -- STAND-IN
    EXECUTE 'CREATE TABLE public.harness_admins (admin_uid uuid PRIMARY KEY)';
    RAISE NOTICE 'KAN-798 S0 STAND-IN created: public.harness_admins';
  END IF;
  IF to_regprocedure('public.is_admin(uuid)') IS NULL THEN  -- STAND-IN
    EXECUTE $f$CREATE FUNCTION public.is_admin(p_uid uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
               SET search_path TO 'public'
               AS $b$ SELECT EXISTS (SELECT 1 FROM public.harness_admins WHERE admin_uid = p_uid) $b$$f$;
    RAISE NOTICE 'KAN-798 S0 STAND-IN created: public.is_admin(uuid)';
  END IF;
  IF to_regclass('public.game_join_requests') IS NULL THEN  -- STAND-IN (baseline shape)
    EXECUTE $f$CREATE TABLE public.game_join_requests (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), game_id uuid NOT NULL,
               from_profile_id uuid NOT NULL, from_user_id uuid NOT NULL, status text NOT NULL DEFAULT 'pending',
               created_at timestamptz NOT NULL DEFAULT now(), decided_at timestamptz)$f$;
    RAISE NOTICE 'KAN-798 S0 STAND-IN created: public.game_join_requests';
  END IF;
  IF to_regclass('public.game_invites') IS NULL THEN  -- STAND-IN (baseline shape)
    EXECUTE $f$CREATE TABLE public.game_invites (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), game_id uuid NOT NULL,
               to_user_id uuid NOT NULL, invited_by_profile_id uuid, status text NOT NULL DEFAULT 'pending',
               created_at timestamptz NOT NULL DEFAULT now(), responded_at timestamptz)$f$;
    RAISE NOTICE 'KAN-798 S0 STAND-IN created: public.game_invites';
  END IF;
  IF to_regclass('public.game_link_tokens') IS NULL THEN  -- STAND-IN (baseline shape)
    EXECUTE $f$CREATE TABLE public.game_link_tokens (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), game_id uuid NOT NULL,
               token uuid NOT NULL, created_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
               expires_at timestamptz, max_uses integer, used_count integer NOT NULL DEFAULT 0,
               active boolean NOT NULL DEFAULT true)$f$;
    RAISE NOTICE 'KAN-798 S0 STAND-IN created: public.game_link_tokens';
  END IF;
  IF to_regclass('public.game_waitlist') IS NULL THEN  -- STAND-IN (baseline shape)
    EXECUTE $f$CREATE TABLE public.game_waitlist (game_id uuid NOT NULL, profile_id uuid NOT NULL, user_id uuid NOT NULL,
               position integer NOT NULL, joined_at timestamptz NOT NULL DEFAULT now())$f$;
    RAISE NOTICE 'KAN-798 S0 STAND-IN created: public.game_waitlist';
  END IF;
  IF to_regclass('public.game_roster') IS NULL THEN  -- STAND-IN (baseline shape)
    EXECUTE $f$CREATE TABLE public.game_roster (game_id uuid, user_id uuid, profile_id uuid, role text DEFAULT 'player',
               status text DEFAULT 'active', left_at timestamptz, joined_at timestamptz DEFAULT now(),
               CONSTRAINT game_roster_game_profile_key UNIQUE (game_id, profile_id))$f$;
    RAISE NOTICE 'KAN-798 S0 STAND-IN created: public.game_roster';
  END IF;
  IF to_regprocedure('public.process_notification_event(uuid,text,text,uuid,uuid,text,text)') IS NULL THEN  -- STAND-IN
    EXECUTE $f$CREATE FUNCTION public.process_notification_event(p_user uuid, p_kind text, p_entity_type text, p_entity uuid,
               p_actor uuid, p_title text DEFAULT NULL, p_body text DEFAULT NULL) RETURNS void LANGUAGE sql
               AS $b$ SELECT NULL::void $b$$f$;
    RAISE NOTICE 'KAN-798 S0 STAND-IN created: public.process_notification_event (no-op)';
  END IF;
  IF to_regprocedure('public.game_slots_left(uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN-798 S0: public.game_slots_left(uuid) missing; this chain is too thin (not stubbed: not this ticket''s function)';
  END IF;
END
$s0$;

-- ===================================================================================== S1 pre-images, VERBATIM
-- baseline 20260829080500_baseline_schema.sql:12064-12147
CREATE OR REPLACE FUNCTION "public"."rpc_decide_join_request"("p_request_id" "uuid", "p_approve" boolean) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  req   record;
  slots int;
BEGIN
  SELECT jr.*, g.creator_user_id
  INTO req
  FROM public.game_join_requests jr
  JOIN public.games g ON g.id = jr.game_id
  WHERE jr.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='request_not_found';
  END IF;

  IF req.creator_user_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host';
  END IF;

  IF req.status <> 'pending' THEN RETURN 'already_decided'; END IF;

  IF p_approve THEN
    slots := public.game_slots_left(req.game_id);

    UPDATE public.game_join_requests
       SET status = 'approved', decided_at = now()
     WHERE id = p_request_id;

    IF slots > 0 THEN
      INSERT INTO public.game_roster(game_id, profile_id, role, status)
      VALUES (req.game_id, req.from_profile_id, 'player', 'active')
      ON CONFLICT (game_id, profile_id) DO UPDATE
        SET status = 'active', left_at = null;

      -- Notify the requester (entity_type 'game' also yields the
      -- /sports/games/<id> deep link). Never let notification failure
      -- roll back the approval itself.
      BEGIN
        PERFORM public.process_notification_event(
          req.from_user_id,
          'game.join_accepted',
          'game',
          req.game_id,
          auth.uid(),
          'You''re in! Your request to join was accepted'
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'join_accepted notification failed: %', SQLERRM;
      END;

      RETURN 'approved_joined';
    ELSE
      INSERT INTO public.game_waitlist(game_id, profile_id, user_id, position)
      SELECT req.game_id, req.from_profile_id, req.from_user_id,
             COALESCE((SELECT MAX(position)+1 FROM public.game_waitlist WHERE game_id = req.game_id), 1)
      ON CONFLICT DO NOTHING;

      BEGIN
        PERFORM public.process_notification_event(
          req.from_user_id,
          'game.join_accepted',
          'game',
          req.game_id,
          auth.uid(),
          'Request approved — the game is full, you''re on the waitlist'
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'join_accepted (waitlist) notification failed: %', SQLERRM;
      END;

      RETURN 'approved_waitlisted';
    END IF;
  ELSE
    UPDATE public.game_join_requests
       SET status = 'denied', decided_at = now()
     WHERE id = p_request_id;
    RETURN 'denied';
  END IF;
END;
$$;
ALTER FUNCTION "public"."rpc_decide_join_request"("p_request_id" "uuid", "p_approve" boolean) OWNER TO "postgres";

-- baseline 20260829080500_baseline_schema.sql:13367-13391
CREATE OR REPLACE FUNCTION "public"."rpc_invite_user"("p_game_id" "uuid", "p_to_user_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE gid uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.games g
    WHERE g.id = p_game_id
      AND (g.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host';
  END IF;

  INSERT INTO public.game_invites(game_id, to_user_id, invited_by_profile_id, status)
  VALUES (
    p_game_id,
    p_to_user_id,
    (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND profile_type = 'organiser' LIMIT 1),
    'pending'
  )
  RETURNING id INTO gid;

  RETURN gid;
END$$;
ALTER FUNCTION "public"."rpc_invite_user"("p_game_id" "uuid", "p_to_user_id" "uuid") OWNER TO "postgres";

-- baseline 20260829080500_baseline_schema.sql:14053-14074
CREATE OR REPLACE FUNCTION "public"."rpc_mint_join_link"("p_game_id" "uuid", "p_expires_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_max_uses" integer DEFAULT NULL::integer) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE t uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.games g
    WHERE g.id = p_game_id
      AND (g.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host';
  END IF;

  t := gen_random_uuid();

  INSERT INTO public.game_link_tokens(game_id, token, created_by, expires_at, max_uses)
  VALUES (p_game_id, t, auth.uid(), p_expires_at, p_max_uses);

  RETURN t;
END;
$$;
ALTER FUNCTION "public"."rpc_mint_join_link"("p_game_id" "uuid", "p_expires_at" timestamp with time zone, "p_max_uses" integer) OWNER TO "postgres";

-- baseline grants :36235-36237, :36433-36435, :36541-36543
DO $gr$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END $gr$;
GRANT ALL ON FUNCTION "public"."rpc_decide_join_request"("p_request_id" "uuid", "p_approve" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_decide_join_request"("p_request_id" "uuid", "p_approve" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_decide_join_request"("p_request_id" "uuid", "p_approve" boolean) TO "service_role";
GRANT ALL ON FUNCTION "public"."rpc_invite_user"("p_game_id" "uuid", "p_to_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_invite_user"("p_game_id" "uuid", "p_to_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_invite_user"("p_game_id" "uuid", "p_to_user_id" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."rpc_mint_join_link"("p_game_id" "uuid", "p_expires_at" timestamp with time zone, "p_max_uses" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."rpc_mint_join_link"("p_game_id" "uuid", "p_expires_at" timestamp with time zone, "p_max_uses" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."rpc_mint_join_link"("p_game_id" "uuid", "p_expires_at" timestamp with time zone, "p_max_uses" integer) TO "service_role";

DO $pin$
DECLARE v text;
BEGIN
  SELECT string_agg(t.f || '=' || coalesce(md5(p.prosrc), 'absent'), '; ') INTO v
    FROM (VALUES ('public.rpc_decide_join_request(uuid,boolean)', '7c03f9298eb4754f9a281e3620af7f93'),
                 ('public.rpc_invite_user(uuid,uuid)', 'f090ca17e10a837091f19c1e0597f164'),
                 ('public.rpc_mint_join_link(uuid,timestamp with time zone,integer)', '6ffbb7cdf8421eef95f4060659084bbe')) t(f, pin)
    LEFT JOIN pg_proc p ON p.oid = to_regprocedure(t.f)
   WHERE p.oid IS NULL OR md5(p.prosrc) <> t.pin;
  IF v IS NOT NULL THEN RAISE EXCEPTION 'KAN-798 S1: installed pre-image md5 differs from the migration pin: %', v; END IF;
  RAISE NOTICE 'KAN-798 S1 pre-images installed verbatim; md5(prosrc) = migration pins';
END $pin$;

-- ===================================================================================== S2 fixture
-- users: H host a1 (profile b1 player + organiser profile 79800000-...-0b1), S stranger a2, A admin a3,
--        R1 requester a4/b4, R2 requester a5/b5. Games G1 (capacity 10), G2 (capacity 2, full).
CREATE TABLE kan798_t.k (name text PRIMARY KEY, v uuid NOT NULL);
INSERT INTO kan798_t.k VALUES
  ('H',  '00000000-0000-0000-0000-0000000000a1'), ('S',  '00000000-0000-0000-0000-0000000000a2'),
  ('A',  '00000000-0000-0000-0000-0000000000a3'), ('R1', '00000000-0000-0000-0000-0000000000a4'),
  ('R2', '00000000-0000-0000-0000-0000000000a5'), ('PH', '00000000-0000-0000-0000-0000000000b1'),
  ('PR1','00000000-0000-0000-0000-0000000000b4'), ('PR2','00000000-0000-0000-0000-0000000000b5'),
  ('PHO','79800000-0000-0000-0000-0000000000b1'),
  ('G1', '79800000-0000-0000-0000-000000000001'), ('G2', '79800000-0000-0000-0000-000000000002'),
  ('GX', '79800000-0000-0000-0000-0000000000ff'),
  ('J1', '79800000-0000-0000-0000-000000000011'), ('J2', '79800000-0000-0000-0000-000000000012'),
  ('J3', '79800000-0000-0000-0000-000000000013'), ('J4', '79800000-0000-0000-0000-000000000014'),
  ('JX', '79800000-0000-0000-0000-0000000000fe'),
  ('X1', '79800000-0000-0000-0000-0000000000c1'), ('X2', '79800000-0000-0000-0000-0000000000c2');
CREATE FUNCTION kan798_t.k(p text) RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT v FROM kan798_t.k WHERE name = p $$;

DO $s2$
BEGIN
  INSERT INTO public.profiles (id, user_id, profile_type, display_name)
  VALUES (kan798_t.k('PHO'), kan798_t.k('H'), 'organiser', 'K798 host organiser');
  INSERT INTO public.harness_admins (admin_uid) VALUES (kan798_t.k('A')) ON CONFLICT DO NOTHING;
  INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility,
                            join_policy, sport_id, geo_location_id, area_id)
  VALUES (kan798_t.k('G1'), 'K798 game 1', kan798_t.k('PH'), kan798_t.k('H'), '2031-03-01 18:00+00', '2031-03-01 19:00+00',
          10, 'public', 'request', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1',
          '00000000-0000-0000-0000-0000000000c1'),
         (kan798_t.k('G2'), 'K798 game 2 full', kan798_t.k('PH'), kan798_t.k('H'), '2031-03-02 18:00+00', '2031-03-02 19:00+00',
          2, 'public', 'request', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1',
          '00000000-0000-0000-0000-0000000000c1');
  DELETE FROM public.game_roster WHERE game_id IN (kan798_t.k('G1'), kan798_t.k('G2'));  -- host roster rows, if a trigger made any
  INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
  VALUES (kan798_t.k('G2'), kan798_t.k('X1'), kan798_t.k('X1'), 'player', 'active'),
         (kan798_t.k('G2'), kan798_t.k('X2'), kan798_t.k('X2'), 'player', 'active');
  INSERT INTO public.game_join_requests (id, game_id, from_profile_id, from_user_id, status) VALUES
    (kan798_t.k('J1'), kan798_t.k('G1'), kan798_t.k('PR1'), kan798_t.k('R1'), 'pending'),
    (kan798_t.k('J2'), kan798_t.k('G1'), kan798_t.k('PR2'), kan798_t.k('R2'), 'pending'),
    (kan798_t.k('J3'), kan798_t.k('G1'), kan798_t.k('X1'),  kan798_t.k('X1'), 'approved'),
    (kan798_t.k('J4'), kan798_t.k('G2'), kan798_t.k('PR1'), kan798_t.k('R1'), 'pending');
  IF (SELECT count(*) FROM public.events e JOIN public.games g ON g.event_id = e.id AND e.event_type = 'game'
       WHERE g.id IN (kan798_t.k('G1'), kan798_t.k('G2')) AND e.creator_user_id = kan798_t.k('H')) <> 2 THEN
    RAISE EXCEPTION 'KAN-798 S2: fixture games have no events parent with the host (KAN-712 guard not live?)';
  END IF;
  IF public.game_slots_left(kan798_t.k('G1')) <= 0 OR public.game_slots_left(kan798_t.k('G2')) <> 0 THEN
    RAISE EXCEPTION 'KAN-798 S2: fixture capacity wrong: G1 slots %, G2 slots %',
      public.game_slots_left(kan798_t.k('G1')), public.game_slots_left(kan798_t.k('G2'));
  END IF;
END
$s2$;

-- ===================================================================================== cases and runner
CREATE TABLE kan798_t.cases (id text PRIMARY KEY, fn text NOT NULL, actor text, a1 text, a2 text, want text NOT NULL);
INSERT INTO kan798_t.cases VALUES
  ('D1 decide: host approves, slots left',      'decide', 'H',  'J1', 'true',  'approved_joined'),
  ('D2 decide: stranger -> not_host',            'decide', 'S',  'J1', 'true',  'P0001:not_host'),
  ('D3 decide: unknown request',                 'decide', 'H',  'JX', 'true',  'P0001:request_not_found'),
  ('D4 decide: host denies',                     'decide', 'H',  'J2', 'false', 'denied'),
  ('D5 decide: already decided',                 'decide', 'H',  'J3', 'true',  'already_decided'),
  ('D6 decide: admin (not host) approves',       'decide', 'A',  'J1', 'true',  'approved_joined'),
  ('D7 decide: host approves, game full',        'decide', 'H',  'J4', 'true',  'approved_waitlisted'),
  ('D8 decide: no JWT (auth.uid() null)',        'decide', NULL, 'J2', 'false', 'denied'),
  ('I1 invite: host',                            'invite', 'H',  'G1', 'R1',    'uuid'),
  ('I2 invite: stranger -> not_host',            'invite', 'S',  'G1', 'R1',    'P0001:not_host'),
  ('I3 invite: unknown game -> not_host',        'invite', 'H',  'GX', 'R1',    'P0001:not_host'),
  ('I4 invite: admin',                           'invite', 'A',  'G1', 'R2',    'uuid'),
  ('I5 invite: no JWT -> not_host',              'invite', NULL, 'G1', 'R1',    'P0001:not_host'),
  ('M1 mint: host, expiry + max uses',           'mint',   'H',  'G1', '5',     'uuid'),
  ('M2 mint: stranger -> not_host',              'mint',   'S',  'G1', NULL,    'P0001:not_host'),
  ('M3 mint: unknown game -> not_host',          'mint',   'H',  'GX', NULL,    'P0001:not_host'),
  ('M4 mint: admin, defaults',                   'mint',   'A',  'G2', NULL,    'uuid'),
  ('M5 mint: no JWT -> not_host',                'mint',   NULL, 'G1', NULL,    'P0001:not_host');

-- Runs one case in a sub-transaction that is always rolled back (sentinel SQLSTATE KN798), and returns
-- '<result> || <digest of the rows the call wrote>'. Generated ids/tokens/timestamps are reduced to facts.
CREATE FUNCTION kan798_t.run(p_case text, p_diverge boolean DEFAULT false) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  c kan798_t.cases;
  res text;
  dig text;
  u uuid;
BEGIN
  SELECT * INTO c FROM kan798_t.cases WHERE id = p_case;
  IF NOT FOUND THEN RAISE EXCEPTION 'KAN-798: no case %', p_case; END IF;
  BEGIN
    IF p_diverge THEN  -- F-probe: events host of G1 becomes S; the legacy column keeps H
      PERFORM set_config('session_replication_role', 'replica', true);
      UPDATE public.events SET creator_user_id = kan798_t.k('S')
       WHERE id = (SELECT event_id FROM public.games WHERE id = kan798_t.k('G1'));
      PERFORM set_config('session_replication_role', 'origin', true);
    END IF;
    PERFORM set_config('request.jwt.claim.sub', coalesce(kan798_t.k(c.actor)::text, ''), true);
    IF c.fn = 'decide' THEN
      res := public.rpc_decide_join_request(kan798_t.k(c.a1), c.a2::boolean);
    ELSIF c.fn = 'invite' THEN
      u := public.rpc_invite_user(kan798_t.k(c.a1), kan798_t.k(c.a2));
      res := CASE WHEN u IS NULL THEN 'null' ELSE 'uuid' END;
      dig := (SELECT string_agg(format('invite(%s,%s,%s,%s,ret=%s)', i.game_id = kan798_t.k(c.a1), i.to_user_id,
                                       i.invited_by_profile_id, i.status, i.id = u), ';')
                FROM public.game_invites i WHERE i.game_id IN (kan798_t.k('G1'), kan798_t.k('G2'), kan798_t.k('GX')));
    ELSIF c.fn = 'mint' THEN
      IF c.a2 IS NULL THEN
        u := public.rpc_mint_join_link(kan798_t.k(c.a1));
      ELSE
        u := public.rpc_mint_join_link(kan798_t.k(c.a1), '2031-04-01 00:00+00'::timestamptz, c.a2::int);
      END IF;
      res := CASE WHEN u IS NULL THEN 'null' ELSE 'uuid' END;
      dig := (SELECT string_agg(format('link(%s,%s,%s,%s,%s,%s,ret=%s)', l.game_id = kan798_t.k(c.a1), l.created_by,
                                       l.expires_at, l.max_uses, l.used_count, l.active, l.token = u), ';')
                FROM public.game_link_tokens l WHERE l.game_id IN (kan798_t.k('G1'), kan798_t.k('G2'), kan798_t.k('GX')));
    END IF;
    IF c.fn = 'decide' THEN
      dig := concat_ws(' ',
        (SELECT string_agg(format('jr(%s,%s,%s)', right(j.id::text, 2), j.status, j.decided_at IS NOT NULL), ',' ORDER BY j.id)
           FROM public.game_join_requests j WHERE j.game_id IN (kan798_t.k('G1'), kan798_t.k('G2'))),
        (SELECT string_agg(format('ro(%s,%s,%s,%s,%s)', right(r.game_id::text, 1), r.profile_id, r.role, r.status, r.left_at IS NULL), ','
                           ORDER BY r.game_id, r.profile_id)
           FROM public.game_roster r WHERE r.game_id IN (kan798_t.k('G1'), kan798_t.k('G2'))),
        (SELECT string_agg(format('wl(%s,%s,%s,%s)', right(w.game_id::text, 1), w.profile_id, w.user_id, w.position), ','
                           ORDER BY w.game_id, w.position)
           FROM public.game_waitlist w WHERE w.game_id IN (kan798_t.k('G1'), kan798_t.k('G2'))),
        (SELECT string_agg(format('nt(%s,%s,%s,%s,%s)', n.user_id, n.kind, n.entity_type, n.actor_user_id, n.title), ','
                           ORDER BY n.id)
           FROM public.notifications n WHERE n.entity_id IN (kan798_t.k('G1'), kan798_t.k('G2'))));
    END IF;
    RAISE EXCEPTION USING errcode = 'KN798', message = coalesce(res, 'null') || ' || ' || coalesce(dig, '-');
  EXCEPTION
    WHEN SQLSTATE 'KN798' THEN RETURN SQLERRM;
    WHEN OTHERS THEN RETURN SQLSTATE || ':' || SQLERRM;
  END;
END
$$;

CREATE TABLE kan798_t.result (phase text, case_id text, got text, PRIMARY KEY (phase, case_id));
CREATE TABLE kan798_t.cat (phase text, fn text, row text, privs text, PRIMARY KEY (phase, fn));

CREATE FUNCTION kan798_t.capture(p_phase text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE c record;
BEGIN
  FOR c IN SELECT id FROM kan798_t.cases ORDER BY id LOOP
    INSERT INTO kan798_t.result VALUES (p_phase, c.id, kan798_t.run(c.id));
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'creator_user_id'
              AND attnum > 0 AND NOT attisdropped) THEN
    INSERT INTO kan798_t.result VALUES
      (p_phase, 'F1 diverged: S decides J1',  kan798_t.run('D2 decide: stranger -> not_host', true)),
      (p_phase, 'F2 diverged: H decides J1',  kan798_t.run('D1 decide: host approves, slots left', true)),
      (p_phase, 'F3 diverged: S invites G1',  kan798_t.run('I2 invite: stranger -> not_host', true)),
      (p_phase, 'F4 diverged: H invites G1',  kan798_t.run('I1 invite: host', true)),
      (p_phase, 'F5 diverged: S mints G1',    kan798_t.run('M2 mint: stranger -> not_host', true)),
      (p_phase, 'F6 diverged: H mints G1',    kan798_t.run('M1 mint: host, expiry + max uses', true));
  END IF;
  INSERT INTO kan798_t.cat
  SELECT p_phase, p.oid::regprocedure::text,
         format('oid=%s argtypes=%s rettype=%s secdef=%s config=%s acl=%s owner=%s vol=%s args=[%s] res=%s',
                p.oid, p.proargtypes, p.prorettype::regtype, p.prosecdef, p.proconfig, p.proacl, pg_get_userbyid(p.proowner),
                p.provolatile, pg_get_function_arguments(p.oid), pg_get_function_result(p.oid)),
         format('PUBLIC=%s anon=%s authenticated=%s service_role=%s',
                coalesce((SELECT bool_or(a.grantee = 0) FROM aclexplode(p.proacl) a WHERE a.privilege_type = 'EXECUTE'), false),
                has_function_privilege('anon', p.oid, 'EXECUTE'), has_function_privilege('authenticated', p.oid, 'EXECUTE'),
                has_function_privilege('service_role', p.oid, 'EXECUTE'))
    FROM pg_proc p
   WHERE p.oid IN ('public.rpc_decide_join_request(uuid,boolean)'::regprocedure, 'public.rpc_invite_user(uuid,uuid)'::regprocedure,
                   'public.rpc_mint_join_link(uuid,timestamp with time zone,integer)'::regprocedure);
END
$$;

-- ===================================================================================== S3 BEFORE
SELECT kan798_t.capture('before');
DO $s3$
DECLARE r record; bad int := 0;
BEGIN
  FOR r IN SELECT c.id, c.want, x.got FROM kan798_t.cases c JOIN kan798_t.result x ON x.case_id = c.id AND x.phase = 'before' ORDER BY c.id LOOP
    IF split_part(r.got, ' || ', 1) <> r.want THEN
      bad := bad + 1;
      RAISE NOTICE 'KAN-798 S3 FIXTURE FAIL: % want % got %', r.id, r.want, r.got;
    END IF;
  END LOOP;
  -- the F-probe seen failing: on the pre-image the functions follow the LEGACY column
  FOR r IN SELECT case_id, got FROM kan798_t.result WHERE phase = 'before' AND case_id LIKE 'F%' ORDER BY case_id LOOP
    RAISE NOTICE 'KAN-798 S3 F-probe before (pre-image follows LEGACY): % -> %', r.case_id, split_part(r.got, ' || ', 1);
  END LOOP;
  IF bad > 0 THEN RAISE EXCEPTION 'KAN-798 S3: % fixture case(s) do not behave as the pre-image must', bad; END IF;
  RAISE NOTICE 'KAN-798 S3 BEFORE captured: % cases, % catalogue rows',
    (SELECT count(*) FROM kan798_t.result WHERE phase = 'before'), (SELECT count(*) FROM kan798_t.cat WHERE phase = 'before');
END
$s3$;
COMMIT;
\endif

\if :k798_check
BEGIN;
DELETE FROM kan798_t.result WHERE phase = 'after';
DELETE FROM kan798_t.cat WHERE phase = 'after';
SELECT kan798_t.capture('after');

DO $chk$
DECLARE
  r record;
  pass int := 0;
  fail int := 0;
  v text;
  has_col boolean := EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'creator_user_id'
                              AND attnum > 0 AND NOT attisdropped);
  z01_cols text[] := '{title,creator_profile_id,creator_user_id,start_at,end_at,capacity,listing_visibility,join_policy,min_skill,max_skill,is_cancelled,cancelled_at,cancelled_reason,created_at,updated_at,search_tsv,sport_id,geo_location_id,area_id,venue_id,joining_rule,cost_cover,request_id}';
BEGIN
  RAISE NOTICE 'KAN-798 check: games.creator_user_id present = %', has_col;
  -- C1 + C2
  FOR r IN SELECT c.id, b.got AS before, a.got AS after
             FROM kan798_t.cases c
             JOIN kan798_t.result b ON b.case_id = c.id AND b.phase = 'before'
             LEFT JOIN kan798_t.result a ON a.case_id = c.id AND a.phase = 'after'
            ORDER BY c.id LOOP
    IF r.after IS NULL OR r.after LIKE '42703:%' OR (r.after !~ '^(P0001:|approved|denied|already|uuid)') THEN
      fail := fail + 1; RAISE NOTICE 'KAN-798 C1 FAIL: % -> %', r.id, r.after;
    ELSE
      pass := pass + 1; RAISE NOTICE 'KAN-798 C1 PASS: % runs (%)', r.id, split_part(r.after, ' || ', 1);
    END IF;
    IF r.after IS DISTINCT FROM r.before THEN
      fail := fail + 1; RAISE NOTICE 'KAN-798 C2 FAIL: %  before: %  after: %', r.id, r.before, r.after;
    ELSE
      pass := pass + 1; RAISE NOTICE 'KAN-798 C2 PASS: % before = after: %', r.id, r.after;
    END IF;
  END LOOP;

  -- C3
  FOR r IN SELECT p.oid::regprocedure::text AS fn, pg_get_functiondef(p.oid) AS def
             FROM pg_proc p
            WHERE p.oid IN ('public.rpc_decide_join_request(uuid,boolean)'::regprocedure, 'public.rpc_invite_user(uuid,uuid)'::regprocedure,
                            'public.rpc_mint_join_link(uuid,timestamp with time zone,integer)'::regprocedure) ORDER BY 1 LOOP
    SELECT string_agg(col, ',') INTO v FROM unnest(z01_cols) col
     WHERE r.def ~ ('\m(g|games)\.' || col || '\M');
    IF v IS NOT NULL OR r.def !~ 'JOIN public\.events e ON e\.id = g\.event_id AND e\.event_type = ''game''' THEN
      fail := fail + 1; RAISE NOTICE 'KAN-798 C3 FAIL: % reads Z01-removed games column(s) [%] or lacks the events join', r.fn, v;
    ELSE
      pass := pass + 1; RAISE NOTICE 'KAN-798 C3 PASS: % reads none of the 23 Z01-removed games columns through games; host via events join', r.fn;
    END IF;
  END LOOP;

  -- C4
  FOR r IN SELECT b.fn, b.row AS brow, a.row AS arow, b.privs AS bp, a.privs AS ap
             FROM kan798_t.cat b LEFT JOIN kan798_t.cat a ON a.fn = b.fn AND a.phase = 'after'
            WHERE b.phase = 'before' ORDER BY b.fn LOOP
    IF r.arow IS DISTINCT FROM r.brow OR r.ap IS DISTINCT FROM r.bp THEN
      fail := fail + 1; RAISE NOTICE 'KAN-798 C4 FAIL: %  before: % %  after: % %', r.fn, r.brow, r.bp, r.arow, r.ap;
    ELSE
      pass := pass + 1; RAISE NOTICE 'KAN-798 C4 PASS: % unchanged: % | %', r.fn, r.arow, r.ap;
    END IF;
  END LOOP;

  -- F: follows events (only while the legacy column exists to diverge from)
  IF has_col THEN
    FOR r IN SELECT case_id, split_part(got, ' || ', 1) AS res,
                    CASE WHEN case_id LIKE '% S %' THEN 'ok' ELSE 'P0001:not_host' END AS want
               FROM kan798_t.result WHERE phase = 'after' AND case_id LIKE 'F%' ORDER BY case_id LOOP
      IF (r.want = 'ok' AND r.res !~ '^(approved_joined|uuid)$') OR (r.want <> 'ok' AND r.res <> r.want) THEN
        fail := fail + 1; RAISE NOTICE 'KAN-798 F FAIL: % -> % (want %: follow EVENTS)', r.case_id, r.res, r.want;
      ELSE
        pass := pass + 1; RAISE NOTICE 'KAN-798 F PASS: % -> % (follows EVENTS; pre-image gave %)', r.case_id, r.res,
          (SELECT split_part(got, ' || ', 1) FROM kan798_t.result WHERE phase = 'before' AND case_id = r.case_id);
      END IF;
    END LOOP;
  ELSE
    RAISE NOTICE 'KAN-798 F SKIPPED: games.creator_user_id is gone (post-Z01); events is the only host source, nothing to diverge from';
  END IF;

  RAISE NOTICE 'KAN-798 TOTAL pass=% fail=%', pass, fail;
  IF fail > 0 THEN RAISE EXCEPTION 'KAN-798 test FAILED: % check(s)', fail; END IF;
END
$chk$;
ROLLBACK;
\endif
