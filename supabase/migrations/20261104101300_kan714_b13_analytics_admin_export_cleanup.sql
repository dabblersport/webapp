-- KAN-732 (Events P2, KAN-714 piece B13): the analytics / admin / data-export / cleanup consumers that read
-- SHARED game facts read them from public.events.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (backend-N).
-- Local proof: supabase/tests/events_p2/kan714_b13_analytics_export.sql.
--
-- Shared columns (mirrored on events; KAN-710 20261101140000:22-46, mapping KAN-711 20261102110000:49-84):
--   id, creator_profile_id, creator_user_id, title, start_at, end_at, capacity, listing_visibility,
--   join_policy (meetups.rsvp_policy), is_cancelled, cancelled_at, cancelled_reason, sport_id, area_id,
--   geo_location_id, venue_id, min_skill, max_skill, joining_rule, cost_cover, request_id, created_at, updated_at.
--
-- CANDIDATES (latest TRACKED definition in supabase/migrations/; live catalogue NOT consulted: the read-only
-- execute_sql call was refused by the workspace ops guard, D-042). Sweep: every function/view name in tracked
-- migrations matching admin|export|gdpr|clean|purge|maint|metric|stat|report|archiv|expir|prune|retent|delete|
-- anonym|dashboard|kpi|audit|sweep|funnel|overview|summary|leader|reconcil|digest, plus every function/view
-- whose latest body names games/meetups (113 names) classified by family.
--   admin_cleanup_user_data(uuid,boolean)  baseline 20260829080500:2223-2300  CONVERTED (cleanup; DELETE games
--                                           predicate creator_profile_id -> events.creator_profile_id)
--   admin_overview_row()                   baseline 20260829080500:2515-2580  CONVERTED (admin analytics;
--                                           games.created_at -> events.created_at)
--   v_admin_overview                       baseline :25113-25125  not shared-column (reads admin_overview_row()
--                                           only; keeps working through the unchanged signature)
--   rpc_sport_overview, v_host_weekly_metrics  20261104100700 (B07)  already done by another B-ticket
--   rpc_admin_launch_funnel                20261030120000:6-35  not shared-column (public.analytics_events only)
--   v_data_export_sla_status               20260901180000:31-40  not shared-column (data_export_requests only)
--   delete_my_account                      20260910090000:314   not shared-column (no games/meetups reference)
--   admin_force_delete_auth_user           baseline :2353       not shared-column (auth schema only)
--   game_rating_rebuild_all                baseline :6828       not shared-column (iterates games.id = identity key)
--   recompute_sport_user_counts, v_moderation_metrics, v_safety_overview, v_wallet_admin_overview,
--   v_rewards_*, v_reputation_leaderboard, v_user_badges_summary, v_bench_status, admin_take_action,
--   admin_resolve_report, admin_scrub_posts_body*, admin_*payout*, admin_wallet_adjust, rpc_admin_* (venue
--   submission / freeze / hide), rpc_expire_freezes, rpc_draft_archive, auto_expire_kickins, audit_*
--                                           not shared-column (no games/meetups reference in latest body)
--   get_open_games_for_seeding, get_games_needing_players (baseline :7617, :7164)  out of family (seed-bot
--                                           matchmaking, not analytics/admin/export/cleanup); reads shared columns,
--                                           left for the owning B-ticket
--   kan711_events_parity / kan711_events_validate_links  out of family (P1 migration machinery)
--   supabase/functions/send-export-email   out of family (edge function; no games/meetups reference)
--
-- KAN-712: neither converted function is wrapped. KAN-712 wraps only the 11 UPDATE-path RPCs
-- (20261103110000_kan712_cutover.sql:102-112). admin_cleanup_user_data is on the INSERT/DELETE ALLOWLIST
-- (cutover :233, contract row 19), routed by the after-delete trigger, and its DELETE still matches that
-- allowlisted pattern. The guard refuses if kan712_wrapped_rpcs lists either name or an *_kan712_inner exists,
-- because a bare CREATE OR REPLACE would then clobber the wrapper.
--
-- Changes (everything else byte for byte the baseline bodies):
--   admin_cleanup_user_data:  DELETE FROM public.games WHERE creator_profile_id = v_profile_id
--                       ->    DELETE FROM public.games g USING public.events e
--                              WHERE e.id = g.event_id AND e.event_type = 'game' AND e.creator_profile_id = v_profile_id
--   admin_overview_row (games_week CTE):  from public.games g where g.created_at in week
--                       ->    from public.games g join public.events e on e.id = g.event_id and e.event_type = 'game'
--                              where e.created_at in week
--   INNER join / USING: games.event_id is NOT NULL + FK-validated since KAN-712 (asserted below), events.id is the
--   PK, so every game has exactly one parent: no row lost, none doubled. Meetups are not read by either function
--   (pre-existing: cleanup fails with 23503 on a meetup owner, KAN712_CONTRACT L-2; unchanged).
--   Output shape, signatures, return types, error texts/codes, the dry-run ROW_COUNT behaviour, owner postgres,
--   SECURITY DEFINER, search_path, ACL and the dependent view v_admin_overview are unchanged; all asserted.
--   No GRANT, REVOKE, policy, DROP or data mutation. SECURITY DEFINER (owner postgres, BYPASSRLS) means no API
--   role needs a grant on public.events and none is added.
--
-- md5(prosrc): admin_cleanup_user_data 978ae882109662a5e229bb87aebad01b -> 09baee67932be2618af9043c89155db2
--              admin_overview_row      f5a9160e240140ed7c5a373a3d494e79 -> 42573e04bc2aae0af755ded1f8eceb5a
-- Repo-expected ACLs (baseline :34601-34604, :34645-34647; KAN-189 changed defaults only):
--   admin_cleanup_user_data {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
--   admin_overview_row      {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
-- The migration asserts ACL pre = post rather than these literals (the live catalogue could not be read).

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard + per-object drift guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  r record;
  p record;
  v_drift bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-732: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;

  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-732: public.events missing (KAN-710 not applied)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.events'::regclass AND relrowsecurity AND relforcerowsecurity) THEN
    RAISE EXCEPTION 'KAN-732: public.events is not RLS-enabled + FORCE (KAN-710 security model changed; stop)';
  END IF;

  -- KAN-712 stage B (cutover) markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.games',   'trg_zz_kan712_games_after_delete'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard')) AS t(tbl, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.tbl::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      RAISE EXCEPTION 'KAN-732: KAN-712 cutover not live (% on % missing or disabled)', r.tg, r.tbl;
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    RAISE EXCEPTION 'KAN-732: KAN-712 write contract not applied (public.kan712_wrapped_rpcs missing)';
  END IF;
  IF (SELECT count(*) FROM pg_constraint
       WHERE conrelid = 'public.games'::regclass
         AND conname IN ('games_event_id_not_null', 'games_event_id_fkey') AND convalidated) <> 2 THEN
    RAISE EXCEPTION 'KAN-732: games.event_id NOT NULL / FK not validated (KAN-711 validate_links)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.games WHERE event_id IS NULL) THEN
    RAISE EXCEPTION 'KAN-732: games rows with NULL event_id; the INNER join would drop them';
  END IF;

  -- KAN-713 live: access helpers (20261104100000), the dependency marker B01/B02/B07/B10 use.
  IF to_regprocedure('public._can_view_game(uuid)') IS NULL
     OR to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN-732: KAN-713 access helpers not live (20261104100000 not applied)';
  END IF;

  -- Per object: present, unwrapped, expected attributes, expected body (pre-image or this file).
  FOR r IN SELECT * FROM (VALUES
      ('admin_cleanup_user_data', 'public.admin_cleanup_user_data(uuid,boolean)',
       '978ae882109662a5e229bb87aebad01b', '09baee67932be2618af9043c89155db2', 'search_path=public, pg_temp'),
      ('admin_overview_row', 'public.admin_overview_row()',
       'f5a9160e240140ed7c5a373a3d494e79', '42573e04bc2aae0af755ded1f8eceb5a', 'search_path=public')
    ) AS t(name, sig, md5_pre, md5_new, cfg)
  LOOP
    IF to_regprocedure(r.sig) IS NULL THEN
      RAISE EXCEPTION 'KAN-732: % missing (baseline 20260829080500 not applied)', r.sig;
    END IF;
    IF EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = r.name)
       OR EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = r.name || '_kan712_inner') THEN
      RAISE EXCEPTION 'KAN-732: % is KAN-712-wrapped; change it via kan712_unwrap_rpc/kan712_wrap_rpc — decision_required, stop', r.name;
    END IF;
    IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = r.name) <> 1 THEN
      RAISE EXCEPTION 'KAN-732: % has overloads; stop', r.name;
    END IF;
    SELECT pr.prosecdef, pr.provolatile, pr.proconfig, l.lanname, pg_get_userbyid(pr.proowner) AS owner, md5(pr.prosrc) AS h
      INTO p FROM pg_proc pr JOIN pg_language l ON l.oid = pr.prolang WHERE pr.oid = to_regprocedure(r.sig);
    IF NOT p.prosecdef OR p.provolatile <> 'v' OR p.lanname <> 'plpgsql' OR p.owner <> 'postgres'
       OR p.proconfig IS DISTINCT FROM ARRAY[r.cfg] THEN
      RAISE EXCEPTION 'KAN-732: % attributes drifted from baseline (secdef %, volatility %, language %, owner %, config %); stop',
        r.sig, p.prosecdef, p.provolatile, p.lanname, p.owner, p.proconfig;
    END IF;
    IF p.h NOT IN (r.md5_pre, r.md5_new) THEN
      RAISE EXCEPTION 'KAN-732: % body (md5 %) is neither baseline nor this file; it was redefined elsewhere — stop', r.sig, p.h;
    END IF;
  END LOOP;

  -- Value equivalence on the two columns this file moves to events.
  SELECT count(*) INTO v_drift
    FROM public.games g
    LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE e.id IS NULL
      OR (g.creator_profile_id, g.created_at) IS DISTINCT FROM (e.creator_profile_id, e.created_at);
  IF v_drift <> 0 THEN
    RAISE EXCEPTION 'KAN-732: % games rows disagree with (or lack) their events parent on creator_profile_id/created_at; reconcile first', v_drift;
  END IF;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE kan732_fpre ON COMMIT DROP AS
SELECT p.oid::regprocedure::text AS sig, pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_arguments(p.oid) AS full_args, pg_get_function_result(p.oid) AS result, p.prolang, p.prosecdef,
       p.provolatile, p.proparallel, p.proleakproof, p.proisstrict, p.procost, p.prorows, p.proconfig,
       pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl, obj_description(p.oid, 'pg_proc') AS comment
  FROM pg_proc p
 WHERE p.oid IN ('public.admin_cleanup_user_data(uuid,boolean)'::regprocedure, 'public.admin_overview_row()'::regprocedure);

CREATE TEMP TABLE kan732_vpre ON COMMIT DROP AS
SELECT pg_get_viewdef('public.v_admin_overview'::regclass) AS def, c.relacl::text AS acl, c.reloptions,
       pg_get_userbyid(c.relowner) AS owner
  FROM pg_class c WHERE c.oid = to_regclass('public.v_admin_overview');

-- ---------------------------------------------------------------------------------------------------------
-- 2a. admin_cleanup_user_data (identical to baseline :2223-2300 except the games DELETE and its comment)
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."admin_cleanup_user_data"("p_user_id" "uuid", "p_dry_run" boolean DEFAULT true) RETURNS TABLE("affected_table" "text", "affected_column" "text", "rows_affected" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $_$
DECLARE
  r           record;
  v_profile_id uuid;
  v_sql       text;
  v_count     bigint;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin privileges required';
  END IF;

  PERFORM set_config('app.admin_cleanup', 'on', true);

  SELECT id INTO v_profile_id FROM public.profiles WHERE user_id = p_user_id;

  IF v_profile_id IS NULL THEN
    affected_table := 'profiles'; affected_column := 'user_id'; rows_affected := 0;
    RETURN NEXT; RETURN;
  END IF;

  -- Games. KAN-732 (KAN-714 B13): ownership is a SHARED fact and is read from the game's events
  -- parent (games.event_id is NOT NULL + FK-validated since the KAN-712 cutover; events.id is the PK,
  -- so each game matches exactly one parent and ROW_COUNT counts games rows, never doubled).
  IF NOT p_dry_run THEN
    DELETE FROM public.games g
     USING public.events e
     WHERE e.id = g.event_id AND e.event_type = 'game'
       AND e.creator_profile_id = v_profile_id;
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count > 0 THEN
    affected_table := 'games'; affected_column := 'creator_profile_id'; rows_affected := v_count;
    RETURN NEXT;
  END IF;

  -- Posts
  IF NOT p_dry_run THEN
    DELETE FROM public.posts WHERE author_profile_id = v_profile_id;
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count > 0 THEN
    affected_table := 'posts'; affected_column := 'author_profile_id'; rows_affected := v_count;
    RETURN NEXT;
  END IF;

  FOR r IN
    SELECT c.table_schema, c.table_name, c.column_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name
    WHERE c.table_schema = 'public'
      AND c.column_name IN ('user_id', 'profile_id')
      AND t.table_type = 'BASE TABLE'
      AND c.table_name NOT IN ('profiles', 'games', 'posts')
  LOOP
    v_sql := format('SELECT count(*) FROM %I.%I WHERE %I = $1',
      r.table_schema, r.table_name, r.column_name);

    EXECUTE v_sql INTO v_count
      USING CASE WHEN r.column_name = 'user_id' THEN p_user_id ELSE v_profile_id END;

    IF v_count > 0 THEN
      IF NOT p_dry_run THEN
        v_sql := format('DELETE FROM %I.%I WHERE %I = $1',
          r.table_schema, r.table_name, r.column_name);
        EXECUTE v_sql
          USING CASE WHEN r.column_name = 'user_id' THEN p_user_id ELSE v_profile_id END;
      END IF;
      affected_table := r.table_name; affected_column := r.column_name; rows_affected := v_count;
      RETURN NEXT;
    END IF;
  END LOOP;

  IF NOT p_dry_run THEN
    DELETE FROM public.profiles WHERE id = v_profile_id;
  END IF;
  affected_table := 'profiles'; affected_column := 'id'; rows_affected := 1;
  RETURN NEXT;
END;
$_$;

-- ---------------------------------------------------------------------------------------------------------
-- 2b. admin_overview_row (identical to baseline :2515-2580 except the games_week CTE and its comment)
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."admin_overview_row"() RETURNS TABLE("snapshot_at" timestamp with time zone, "total_users" bigint, "frozen_users" bigint, "active_users" bigint, "games_created_this_week" bigint, "reports_open" bigint, "reports_resolved" bigint, "verified_profiles_total" bigint, "verified_players" bigint, "verified_organisers" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  wk_start timestamptz;
  wk_end   timestamptz;
begin
  -- Gate: admin only
  if not public.is_admin(auth.uid()) then
    raise exception using errcode = 'P0001', message = 'not_admin';
  end if;

  select week_start, week_end into wk_start, wk_end
  from public._week_bounds(now());

  -- Return single-row snapshot
  return query
  with
  -- Distinct humans inferred from profiles; avoids needing auth.users privileges
  users_distinct as (
    select count(distinct p.user_id)::bigint as c
    from public.profiles p
    where p.is_active = true
  ),
  frozen as (
    select count(distinct f.user_id)::bigint as c
    from public.user_freezes f
    where f.is_frozen = true
      and (f.until is null or now() < f.until)
      and f.lifted_at is null
  ),
  -- KAN-732 (KAN-714 B13): created_at is a SHARED fact, read from the game's events parent.
  games_week as (
    select count(*)::bigint as c
    from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'
    where e.created_at >= wk_start
      and e.created_at <  wk_end
  ),
  reports as (
    select
      count(*) filter (where status in ('open','reviewing'))::bigint as open_c,
      count(*) filter (where status = 'resolved')::bigint          as resolved_c
    from public.content_reports
  ),
  verif as (
    select
      count(*)::bigint                                                     as total_c,
      count(*) filter (where p.profile_type = 'player')::bigint            as players_c,
      count(*) filter (where p.profile_type = 'organiser')::bigint         as organisers_c
    from public.profile_verifications v
    join public.profiles p on p.id = v.profile_id
    where v.verified = true
  )
  select
    now()                                              as snapshot_at,
    (select c from users_distinct)                     as total_users,
    (select c from frozen)                             as frozen_users,
    (select c from users_distinct) - (select c from frozen)  as active_users,
    (select c from games_week)                         as games_created_this_week,
    (select open_c from reports)                       as reports_open,
    (select resolved_c from reports)                   as reports_resolved,
    (select total_c from verif)                        as verified_profiles_total,
    (select players_c from verif)                      as verified_players,
    (select organisers_c from verif)                   as verified_organisers;
end;
$$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  pre record;
  now_f record;
  v record;
  vp record;
BEGIN
  IF (SELECT count(*) FROM kan732_fpre) <> 2 THEN RAISE EXCEPTION 'KAN-732 post: pre-image missing'; END IF;
  FOR pre IN SELECT * FROM kan732_fpre LOOP
    SELECT pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_arguments(p.oid) AS full_args,
           pg_get_function_result(p.oid) AS result, p.prolang, p.prosecdef, p.provolatile, p.proparallel, p.proleakproof,
           p.proisstrict, p.procost, p.prorows, p.proconfig, pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl,
           obj_description(p.oid, 'pg_proc') AS comment, p.prosrc
      INTO now_f FROM pg_proc p WHERE p.oid = pre.sig::regprocedure;
    IF (now_f.args, now_f.full_args, now_f.result, now_f.prolang, now_f.prosecdef, now_f.provolatile, now_f.proparallel,
        now_f.proleakproof, now_f.proisstrict, now_f.procost, now_f.prorows, now_f.proconfig, now_f.owner, now_f.acl, now_f.comment)
       IS DISTINCT FROM
       (pre.args, pre.full_args, pre.result, pre.prolang, pre.prosecdef, pre.provolatile, pre.proparallel,
        pre.proleakproof, pre.proisstrict, pre.procost, pre.prorows, pre.proconfig, pre.owner, pre.acl, pre.comment) THEN
      RAISE EXCEPTION 'KAN-732 post: % signature/result/attributes/owner/ACL/comment changed', pre.sig;
    END IF;
    IF NOT now_f.prosecdef OR now_f.owner <> 'postgres' THEN
      RAISE EXCEPTION 'KAN-732 post: % is not SECURITY DEFINER owned by postgres', pre.sig;
    END IF;
    -- Dependency on events (plpgsql records no pg_depend on tables; the body text is the dependency).
    IF pre.sig = 'admin_cleanup_user_data(uuid,boolean)' THEN
      IF md5(now_f.prosrc) <> '09baee67932be2618af9043c89155db2'
         OR now_f.result <> 'TABLE(affected_table text, affected_column text, rows_affected bigint)'
         OR now_f.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
         OR position('USING public.events e' IN now_f.prosrc) = 0
         OR position('WHERE e.id = g.event_id AND e.event_type = ''game''' IN now_f.prosrc) = 0
         OR position('AND e.creator_profile_id = v_profile_id' IN now_f.prosrc) = 0
         OR now_f.prosrc ~ 'WHERE creator_profile_id = v_profile_id' THEN
        RAISE EXCEPTION 'KAN-732 post: admin_cleanup_user_data does not read ownership from public.events (md5 %)', md5(now_f.prosrc);
      END IF;
    ELSE
      IF md5(now_f.prosrc) <> '42573e04bc2aae0af755ded1f8eceb5a'
         OR now_f.proconfig IS DISTINCT FROM ARRAY['search_path=public']
         OR position('join public.events e on e.id = g.event_id and e.event_type = ''game''' IN now_f.prosrc) = 0
         OR position('where e.created_at >= wk_start' IN now_f.prosrc) = 0
         OR now_f.prosrc ~ '\mg\.created_at\M' THEN
        RAISE EXCEPTION 'KAN-732 post: admin_overview_row does not read created_at from public.events (md5 %)', md5(now_f.prosrc);
      END IF;
    END IF;
  END LOOP;

  -- Dependent view: definition, owner, ACL, reloptions unchanged, and it still resolves.
  SELECT * INTO vp FROM kan732_vpre;
  IF FOUND THEN
    SELECT pg_get_viewdef('public.v_admin_overview'::regclass) AS def, c.relacl::text AS acl, c.reloptions,
           pg_get_userbyid(c.relowner) AS owner
      INTO v FROM pg_class c WHERE c.oid = 'public.v_admin_overview'::regclass;
    IF (v.def, v.acl, v.reloptions, v.owner) IS DISTINCT FROM (vp.def, vp.acl, vp.reloptions, vp.owner) THEN
      RAISE EXCEPTION 'KAN-732 post: v_admin_overview definition/ACL/reloptions/owner changed';
    END IF;
  END IF;
  RAISE NOTICE 'KAN-732: admin_cleanup_user_data reads creator_profile_id and admin_overview_row reads created_at from public.events; shapes and attributes unchanged';
END
$post$;

COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- ROLLBACK (manual; NOT executed by this migration). Restores baseline 20260829080500:2223-2300 and :2515-2580
-- verbatim (md5(prosrc) 978ae882109662a5e229bb87aebad01b and f5a9160e240140ed7c5a373a3d494e79). Same signatures,
-- so CREATE OR REPLACE keeps owner, ACL and comment; v_admin_overview is untouched. No data is touched.
-- Run as postgres: strip the leading "-- " (or "--" on blank lines) from the lines between the markers.
-- KAN732-ROLLBACK-BEGIN
-- BEGIN;
-- CREATE OR REPLACE FUNCTION "public"."admin_cleanup_user_data"("p_user_id" "uuid", "p_dry_run" boolean DEFAULT true) RETURNS TABLE("affected_table" "text", "affected_column" "text", "rows_affected" bigint)
--     LANGUAGE "plpgsql" SECURITY DEFINER
--     SET "search_path" TO 'public', 'pg_temp'
--     AS $_$
-- DECLARE
--   r           record;
--   v_profile_id uuid;
--   v_sql       text;
--   v_count     bigint;
-- BEGIN
--   IF NOT public.is_admin() THEN
--     RAISE EXCEPTION 'Access denied: admin privileges required';
--   END IF;
--
--   PERFORM set_config('app.admin_cleanup', 'on', true);
--
--   SELECT id INTO v_profile_id FROM public.profiles WHERE user_id = p_user_id;
--
--   IF v_profile_id IS NULL THEN
--     affected_table := 'profiles'; affected_column := 'user_id'; rows_affected := 0;
--     RETURN NEXT; RETURN;
--   END IF;
--
--   -- Games
--   IF NOT p_dry_run THEN
--     DELETE FROM public.games WHERE creator_profile_id = v_profile_id;
--   END IF;
--   GET DIAGNOSTICS v_count = ROW_COUNT;
--   IF v_count > 0 THEN
--     affected_table := 'games'; affected_column := 'creator_profile_id'; rows_affected := v_count;
--     RETURN NEXT;
--   END IF;
--
--   -- Posts
--   IF NOT p_dry_run THEN
--     DELETE FROM public.posts WHERE author_profile_id = v_profile_id;
--   END IF;
--   GET DIAGNOSTICS v_count = ROW_COUNT;
--   IF v_count > 0 THEN
--     affected_table := 'posts'; affected_column := 'author_profile_id'; rows_affected := v_count;
--     RETURN NEXT;
--   END IF;
--
--   FOR r IN
--     SELECT c.table_schema, c.table_name, c.column_name
--     FROM information_schema.columns c
--     JOIN information_schema.tables t
--       ON t.table_schema = c.table_schema AND t.table_name = c.table_name
--     WHERE c.table_schema = 'public'
--       AND c.column_name IN ('user_id', 'profile_id')
--       AND t.table_type = 'BASE TABLE'
--       AND c.table_name NOT IN ('profiles', 'games', 'posts')
--   LOOP
--     v_sql := format('SELECT count(*) FROM %I.%I WHERE %I = $1',
--       r.table_schema, r.table_name, r.column_name);
--
--     EXECUTE v_sql INTO v_count
--       USING CASE WHEN r.column_name = 'user_id' THEN p_user_id ELSE v_profile_id END;
--
--     IF v_count > 0 THEN
--       IF NOT p_dry_run THEN
--         v_sql := format('DELETE FROM %I.%I WHERE %I = $1',
--           r.table_schema, r.table_name, r.column_name);
--         EXECUTE v_sql
--           USING CASE WHEN r.column_name = 'user_id' THEN p_user_id ELSE v_profile_id END;
--       END IF;
--       affected_table := r.table_name; affected_column := r.column_name; rows_affected := v_count;
--       RETURN NEXT;
--     END IF;
--   END LOOP;
--
--   IF NOT p_dry_run THEN
--     DELETE FROM public.profiles WHERE id = v_profile_id;
--   END IF;
--   affected_table := 'profiles'; affected_column := 'id'; rows_affected := 1;
--   RETURN NEXT;
-- END;
-- $_$;
-- CREATE OR REPLACE FUNCTION "public"."admin_overview_row"() RETURNS TABLE("snapshot_at" timestamp with time zone, "total_users" bigint, "frozen_users" bigint, "active_users" bigint, "games_created_this_week" bigint, "reports_open" bigint, "reports_resolved" bigint, "verified_profiles_total" bigint, "verified_players" bigint, "verified_organisers" bigint)
--     LANGUAGE "plpgsql" SECURITY DEFINER
--     SET "search_path" TO 'public'
--     AS $$
-- declare
--   wk_start timestamptz;
--   wk_end   timestamptz;
-- begin
--   -- Gate: admin only
--   if not public.is_admin(auth.uid()) then
--     raise exception using errcode = 'P0001', message = 'not_admin';
--   end if;
--
--   select week_start, week_end into wk_start, wk_end
--   from public._week_bounds(now());
--
--   -- Return single-row snapshot
--   return query
--   with
--   -- Distinct humans inferred from profiles; avoids needing auth.users privileges
--   users_distinct as (
--     select count(distinct p.user_id)::bigint as c
--     from public.profiles p
--     where p.is_active = true
--   ),
--   frozen as (
--     select count(distinct f.user_id)::bigint as c
--     from public.user_freezes f
--     where f.is_frozen = true
--       and (f.until is null or now() < f.until)
--       and f.lifted_at is null
--   ),
--   games_week as (
--     select count(*)::bigint as c
--     from public.games g
--     where g.created_at >= wk_start
--       and g.created_at <  wk_end
--   ),
--   reports as (
--     select
--       count(*) filter (where status in ('open','reviewing'))::bigint as open_c,
--       count(*) filter (where status = 'resolved')::bigint          as resolved_c
--     from public.content_reports
--   ),
--   verif as (
--     select
--       count(*)::bigint                                                     as total_c,
--       count(*) filter (where p.profile_type = 'player')::bigint            as players_c,
--       count(*) filter (where p.profile_type = 'organiser')::bigint         as organisers_c
--     from public.profile_verifications v
--     join public.profiles p on p.id = v.profile_id
--     where v.verified = true
--   )
--   select
--     now()                                              as snapshot_at,
--     (select c from users_distinct)                     as total_users,
--     (select c from frozen)                             as frozen_users,
--     (select c from users_distinct) - (select c from frozen)  as active_users,
--     (select c from games_week)                         as games_created_this_week,
--     (select open_c from reports)                       as reports_open,
--     (select resolved_c from reports)                   as reports_resolved,
--     (select total_c from verif)                        as verified_profiles_total,
--     (select players_c from verif)                      as verified_players,
--     (select organisers_c from verif)                   as verified_organisers;
-- end;
-- $$;
-- COMMIT;
-- KAN732-ROLLBACK-END
