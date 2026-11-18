-- KAN-986 [W1-B8] Housekeeping + KAN-1011 Grants hygiene (Epic KAN-973; plan W1-B8; decision F-13 "Retention is 90 days").
--
-- 1. Inbox retention (F-13). notifications_retention_candidates(days, now) lists the rows older than `days` that are not
--    tied to an open action; notifications_retention_run(...) deletes them in batches (1000 x up to 50 per run) and
--    refuses a period under 90 days. Kept, whatever their age:
--      - an UNREAD security notice (notification_kinds.category = 'security');
--      - game.join_request while that game_join_requests row is 'pending';
--      - game.invited / meetup.invited / squad.invited while the matching invite is 'pending';
--      - meetup.request_received while the requester's meetup_rsvps row is 'pending'.
--    Friend-request kinds have no backing table any more (followers replaced friends, F-17), so they are never open.
--    Deleting a notification cascades to notification_deliveries (FK ON DELETE CASCADE, KAN-979) and sets
--    notification_aggregates.notification_id / security_sign_ins.notification_id to NULL (FK ON DELETE SET NULL).
--    Cron job kan986_notifications_retention_daily (02:41 UTC) is created INACTIVE: it is switched on only after the
--    first-run count is posted on KAN-986 and approved (counted 2026-11-17: 608 rows, 0 open-action rows kept,
--    8 delivery rows cascade).
-- 2. cron.job_run_details: cron_job_run_details_prune(keep) deletes finished runs older than `keep` (7 days) in batches
--    (100 000 x up to 10 per run); job kan986_prune_cron_run_details_hourly at :23. 2 251 910 rows were older than
--    7 days on 2026-11-17, so the backlog clears in about three runs.
-- 3. KAN-1011 grants:
--    a. every public sequence: no grant to PUBLIC, anon or authenticated (6 had rwU; none of their tables is inserted
--       by a client role). Default privileges of role postgres in public: new sequences get nothing for anon /
--       authenticated, new tables no MAINTAIN. (supabase_admin's defaults cannot be changed by postgres; reported.)
--    b. EXECUTE revoked from PUBLIC and anon, and granted explicitly to authenticated and service_role (so no signed-in
--       path loses it), on every VOLATILE public rpc_* function anon could run, except 15 read-only ones kept for
--       anon (the list below; rpc_username_availability is called before sign-in). Includes rpc_cancel_game and
--       rpc_leave_game.
--    c. MAINTAIN revoked from anon and authenticated on every public relation (no client or invoker function needs
--       VACUUM / ANALYZE / REFRESH / LOCK / CLUSTER / REINDEX), except notification_deliveries and notification_jobs
--       (out of bounds for W1-B8; KAN-979 / KAN-983 own them).
-- 4. Notification objects for anon: no grant on notifications, notification_kinds, notification_scores,
--    notification_user_preferences, notification_hourly_caps; no EXECUTE on mark_notification_read,
--    render_notification, calculate_notification_rank, calculate_notification_score, can_send_notification_now,
--    should_bypass_quiet_hours, allow_social_notifications. Kept for anon: next_quiet_exit and
--    is_in_quiet_hours(timestamptz,text,integer,integer) (pure arithmetic, no user data).
-- Out of bounds and untouched: flush_notification_aggregates and its cron (W1-B2), notification_deliveries (W1-B1),
-- notification_jobs and its cron (W1-B5).
-- Live test: supabase/tests/notifications_v2/kan986_housekeeping.sql.

-- 1. pre-image guard ---------------------------------------------------------------------------------------------------
DO $pre$
DECLARE v_bad text := '';
BEGIN
  IF (SELECT count(*) FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'S'
        AND (has_sequence_privilege('anon', c.oid, 'USAGE,SELECT,UPDATE')
             OR has_sequence_privilege('authenticated', c.oid, 'USAGE,SELECT,UPDATE'))) <> 6 THEN
    v_bad := v_bad || ' sequences';
  END IF;
  IF (SELECT count(*) FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'
        AND p.provolatile = 'v' AND p.proname LIKE 'rpc\_%' AND has_function_privilege('anon', p.oid, 'EXECUTE')) <> 96 THEN
    v_bad := v_bad || ' rpc-count';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname IN ('kan986_notifications_retention_daily', 'kan986_prune_cron_run_details_hourly'))
     OR to_regprocedure('public.notifications_retention_run(integer,integer,integer,timestamptz)') IS NOT NULL THEN
    v_bad := v_bad || ' already-applied';
  END IF;
  IF pg_has_role('postgres', 'supabase_admin', 'MEMBER') THEN
    v_bad := v_bad || ' postgres-is-supabase_admin-member(unexpected)';
  END IF;
  IF v_bad <> '' THEN
    RAISE EXCEPTION 'KAN-986 pre-image guard failed:%', v_bad;
  END IF;
END
$pre$;

-- 2. retention ---------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.notifications_retention_candidates(p_days integer DEFAULT 90, p_now timestamptz DEFAULT now())
 RETURNS TABLE (id uuid, to_user_id uuid, kind_key text, created_at timestamptz, is_read boolean)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT n.id, n.to_user_id, n.kind_key, n.created_at, n.is_read
    FROM public.notifications n
    LEFT JOIN public.notification_kinds k ON k.key = n.kind_key
   WHERE n.created_at < p_now - make_interval(days => p_days)
     -- an unread security notice stays
     AND NOT (k.category = 'security' AND n.is_read IS NOT TRUE)
     -- open requests and invites stay
     AND NOT (n.kind_key = 'game.join_request' AND EXISTS (
           SELECT 1 FROM public.game_join_requests j
            WHERE j.status = 'pending'
              AND j.game_id::text = coalesce(n.context ->> 'entity_id', n.context ->> 'game_id')
              AND j.from_user_id::text = n.context ->> 'actor_user_id'))
     AND NOT (n.kind_key = 'game.invited' AND EXISTS (
           SELECT 1 FROM public.game_invites i
            WHERE i.status = 'pending' AND i.to_user_id = n.to_user_id
              AND i.game_id::text = coalesce(n.context ->> 'entity_id', n.context ->> 'game_id')))
     AND NOT (n.kind_key = 'meetup.invited' AND EXISTS (
           SELECT 1 FROM public.meetup_invites i
            WHERE i.status = 'pending' AND i.to_user_id = n.to_user_id
              AND i.meetup_id::text = n.context ->> 'entity_id'))
     AND NOT (n.kind_key = 'meetup.request_received' AND EXISTS (
           SELECT 1 FROM public.meetup_rsvps s
            WHERE s.status = 'pending' AND s.meetup_id::text = n.context ->> 'entity_id'
              AND s.user_id::text = n.context ->> 'actor_user_id'))
     AND NOT (n.kind_key = 'squad.invited' AND EXISTS (
           SELECT 1 FROM public.squad_invites i
            WHERE i.status = 'pending' AND i.to_user_id = n.to_user_id
              AND (n.context ->> 'entity_id' IS NULL OR i.squad_id::text = n.context ->> 'entity_id')))
$function$;

CREATE FUNCTION public.notifications_retention_run(
  p_days integer DEFAULT 90, p_batch integer DEFAULT 1000, p_max_batches integer DEFAULT 50, p_now timestamptz DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_total bigint := 0;
  v_n     bigint;
  v_i     integer := 0;
BEGIN
  IF p_days IS NULL OR p_days < 90 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'notifications_retention_run: the retention period is 90 days or more (F-13)';
  END IF;
  LOOP
    EXIT WHEN v_i >= p_max_batches;
    DELETE FROM public.notifications n
     WHERE n.id IN (SELECT c.id FROM public.notifications_retention_candidates(p_days, p_now) c LIMIT p_batch);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_total := v_total + v_n;
    v_i := v_i + 1;
    EXIT WHEN v_n < p_batch;
  END LOOP;
  RETURN jsonb_build_object('deleted', v_total, 'batches', v_i, 'cutoff', p_now - make_interval(days => p_days));
END;
$function$;

-- 3. cron run history ------------------------------------------------------------------------------------------------
CREATE FUNCTION public.cron_job_run_details_prune(
  p_keep interval DEFAULT '7 days', p_batch integer DEFAULT 100000, p_max_batches integer DEFAULT 10)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_total bigint := 0;
  v_n     bigint;
  v_i     integer := 0;
BEGIN
  IF p_keep IS NULL OR p_keep < interval '1 day' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'cron_job_run_details_prune: keep at least 1 day';
  END IF;
  LOOP
    EXIT WHEN v_i >= p_max_batches;
    DELETE FROM cron.job_run_details d
     WHERE d.runid IN (SELECT x.runid FROM cron.job_run_details x
                        WHERE coalesce(x.end_time, x.start_time) < now() - p_keep
                        ORDER BY x.runid LIMIT p_batch);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_total := v_total + v_n;
    v_i := v_i + 1;
    EXIT WHEN v_n < p_batch;
  END LOOP;
  RETURN v_total;
END;
$function$;

REVOKE ALL ON FUNCTION public.notifications_retention_candidates(integer, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notifications_retention_run(integer, integer, integer, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cron_job_run_details_prune(interval, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notifications_retention_candidates(integer, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.notifications_retention_run(integer, integer, integer, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.cron_job_run_details_prune(interval, integer, integer) TO service_role;

SELECT cron.schedule('kan986_prune_cron_run_details_hourly', '23 * * * *',
                     'SELECT public.cron_job_run_details_prune()');
SELECT cron.schedule('kan986_notifications_retention_daily', '41 2 * * *',
                     'SELECT public.notifications_retention_run()');
-- off until the first-run count is approved (KAN-986)
SELECT cron.alter_job((SELECT jobid FROM cron.job WHERE jobname = 'kan986_notifications_retention_daily'), active := false);

-- 4. KAN-1011 a: sequences and default privileges ------------------------------------------------------------------------
DO $seq$
DECLARE s record;
BEGIN
  FOR s IN SELECT c.oid::regclass AS rel FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'S' LOOP
    EXECUTE format('REVOKE ALL ON SEQUENCE %s FROM PUBLIC, anon, authenticated', s.rel);
  END LOOP;
END
$seq$;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE MAINTAIN ON TABLES FROM anon, authenticated;

-- 5. KAN-1011 b: write RPCs ----------------------------------------------------------------------------------------------
DO $rpc$
DECLARE f record; v_auth boolean; v_svc boolean;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f' AND p.provolatile = 'v'
       AND p.proname LIKE 'rpc\_%' AND has_function_privilege('anon', p.oid, 'EXECUTE')
       AND p.proname NOT IN (
         -- read-only, kept for anon
         'rpc_admin_submission_action_state', 'rpc_autocomplete_people', 'rpc_feed_ranked', 'rpc_get_activity_feed',
         'rpc_meetup_card', 'rpc_my_venue_permissions', 'rpc_nearby_users', 'rpc_potential_vibes', 'rpc_profile_search',
         'rpc_submission_approval_state', 'rpc_submission_audit_timeline', 'rpc_test_ping',
         'rpc_unified_search_sectioned', 'rpc_username_availability', 'rpc_username_suggest',
         -- write, but anon by design (KAN-109: flags_snapshot before sign-in; the function refuses any other event
         -- for anon). Added after PEER 16467; the live grant was restored by 20261117165842_kan986b_track_event_anon.
         'rpc_track_event')
  LOOP
    -- keep exactly what the signed-in and server roles had (often only through PUBLIC), remove anon and PUBLIC
    v_auth := has_function_privilege('authenticated', f.sig, 'EXECUTE');
    v_svc  := has_function_privilege('service_role', f.sig, 'EXECUTE');
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f.sig);
    IF v_auth THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f.sig); END IF;
    IF v_svc  THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f.sig); END IF;
  END LOOP;
END
$rpc$;

-- 6. KAN-1011 c: MAINTAIN --------------------------------------------------------------------------------------------------
DO $mnt$
DECLARE t record;
BEGIN
  FOR t IN
    SELECT c.oid::regclass AS rel FROM pg_class c
     WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'v', 'm', 'p', 'f')
       AND c.relname NOT IN ('notification_deliveries', 'notification_jobs')
       AND EXISTS (SELECT 1 FROM aclexplode(c.relacl) a
                    WHERE a.privilege_type = 'MAINTAIN' AND a.grantee IN ('anon'::regrole, 'authenticated'::regrole)
                      AND a.grantor = 'postgres'::regrole)
  LOOP
    EXECUTE format('REVOKE MAINTAIN ON TABLE %s FROM anon, authenticated', t.rel);
  END LOOP;
END
$mnt$;

-- 7. notification objects for anon -------------------------------------------------------------------------------------
REVOKE ALL ON TABLE public.notifications, public.notification_kinds, public.notification_scores,
                    public.notification_user_preferences, public.notification_hourly_caps FROM anon;

DO $nfn$
DECLARE f record; v_auth boolean; v_svc boolean;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'
       AND p.proname IN ('mark_notification_read', 'render_notification', 'calculate_notification_rank',
                         'calculate_notification_score', 'can_send_notification_now', 'should_bypass_quiet_hours',
                         'allow_social_notifications')
       AND has_function_privilege('anon', p.oid, 'EXECUTE')
  LOOP
    -- keep exactly what the signed-in and server roles had (often only through PUBLIC), remove anon and PUBLIC
    v_auth := has_function_privilege('authenticated', f.sig, 'EXECUTE');
    v_svc  := has_function_privilege('service_role', f.sig, 'EXECUTE');
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f.sig);
    IF v_auth THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f.sig); END IF;
    IF v_svc  THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f.sig); END IF;
  END LOOP;
END
$nfn$;

-- 8. post asserts -----------------------------------------------------------------------------------------------------
DO $post$
DECLARE v_bad text := '';
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'S'
               AND EXISTS (SELECT 1 FROM aclexplode(c.relacl) a
                            WHERE a.grantee IN (0, 'anon'::regrole, 'authenticated'::regrole))) THEN
    v_bad := v_bad || ' sequence-client-grant';
  END IF;
  IF (SELECT count(*) FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'
        AND p.provolatile = 'v' AND p.proname LIKE 'rpc\_%' AND has_function_privilege('anon', p.oid, 'EXECUTE')) <> 16 THEN
    v_bad := v_bad || ' anon-rpc-count';
  END IF;
  IF has_function_privilege('anon', 'public.rpc_cancel_game(uuid,text)', 'EXECUTE')
     OR EXISTS (SELECT 1 FROM pg_proc p WHERE p.proname = 'rpc_leave_game' AND has_function_privilege('anon', p.oid, 'EXECUTE')) THEN
    v_bad := v_bad || ' cancel-or-leave';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.rpc_cancel_game(uuid,text)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.rpc_cancel_game(uuid,text)', 'EXECUTE') THEN
    v_bad := v_bad || ' signed-in-lost-cancel';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class c, aclexplode(c.relacl) a
              WHERE c.relnamespace = 'public'::regnamespace AND a.privilege_type = 'MAINTAIN'
                AND a.grantee IN ('anon'::regrole, 'authenticated'::regrole)
                AND a.grantor = 'postgres'::regrole   -- PostGIS objects granted by supabase_admin are not ours to revoke
                AND c.relname NOT IN ('notification_deliveries', 'notification_jobs')) THEN
    v_bad := v_bad || ' maintain-left';
  END IF;
  IF has_table_privilege('anon', 'public.notifications', 'SELECT')
     OR has_table_privilege('anon', 'public.notification_kinds', 'SELECT')
     OR has_function_privilege('anon', 'public.mark_notification_read(uuid)', 'EXECUTE') THEN
    v_bad := v_bad || ' notification-anon';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.mark_notification_read(uuid)', 'EXECUTE')
     OR NOT has_table_privilege('authenticated', 'public.notifications', 'SELECT') THEN
    v_bad := v_bad || ' authenticated-lost-notifications';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_default_acl d, aclexplode(d.defaclacl) a
              WHERE d.defaclrole = 'postgres'::regrole AND d.defaclnamespace = 'public'::regnamespace
                AND ((d.defaclobjtype = 'S' AND a.grantee IN ('anon'::regrole, 'authenticated'::regrole))
                  OR (d.defaclobjtype = 'r' AND a.privilege_type = 'MAINTAIN' AND a.grantee IN ('anon'::regrole, 'authenticated'::regrole)))) THEN
    v_bad := v_bad || ' default-privileges';
  END IF;
  IF (SELECT count(*) FROM cron.job WHERE jobname = 'kan986_prune_cron_run_details_hourly' AND active) <> 1
     OR (SELECT count(*) FROM cron.job WHERE jobname = 'kan986_notifications_retention_daily' AND NOT active) <> 1 THEN
    v_bad := v_bad || ' cron';
  END IF;
  IF v_bad <> '' THEN
    RAISE EXCEPTION 'KAN-986 post assert failed:%', v_bad;
  END IF;
END
$post$;
