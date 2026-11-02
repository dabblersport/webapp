-- KAN-712 (Events P2), stage 2 of 2: ATOMIC CUTOVER. events becomes authoritative for the shared fields.
--
-- STATUS: authored, NOT applied to any Supabase project. Executed on a local throwaway PG 16 only
-- (supabase/tests/events_p2/KAN712_CONTRACT.md, "Local verification").
--
-- One transaction. It:
--   1. locks events, games and meetups (SHARE ROW EXCLUSIVE: no concurrent writer; in-flight writers
--      finish first, later writers queue behind the commit and then run under the new contract);
--   2. proves the KAN-711 preconditions (parity 0 rows, links validated, backfill finished, no open
--      exceptions, KAN-711 triggers present and enabled);
--   3. DISABLES the KAN-711 legacy -> events mirrors (trg_kan711_{games,meetups}_mirror). The KAN-711
--      event_id assigner and updated_at keeper stay on and are reused;
--   4. attaches the KAN-712 guard (BEFORE INSERT OR UPDATE, sorts last), the after-delete parent
--      removal, and the events -> legacy compat mirror;
--   5. wraps every UPDATE-path RPC (generated from the live catalogue; ACL preserved exactly) so the
--      events row lock is taken FIRST;
--   6. fails closed if any other public function writes games/meetups with UPDATE, or with INSERT/DELETE
--      outside the reviewed allowlist.
-- Rollback: supabase/tests/events_p2/rollback_kan712.sql (one transaction, restores phase 1 exactly).
-- NEVER run kan711_events_backfill_run / _batch after this: they disable every non-kan711 trigger on
-- the legacy tables, which includes the KAN-712 guard.

BEGIN;
SET LOCAL lock_timeout = '10s';

LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;

-- 1. Preconditions --------------------------------------------------------------------------------
DO $$
DECLARE
  v_n bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-712 cutover: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL
     OR to_regprocedure('public.kan712_legacy_guard()') IS NULL
     OR to_regprocedure('public.kan712_wrap_rpc(regprocedure,text)') IS NULL THEN
    RAISE EXCEPTION 'KAN-712 cutover: stage 1 (20261103100000) not applied';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE '%kan712%')
     OR EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs) THEN
    RAISE EXCEPTION 'KAN-712 cutover: already applied (kan712 triggers or wrapped RPCs exist)';
  END IF;
  -- KAN-711 triggers present and enabled.
  IF (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_kan711_games_assign_event_id', 'trg_kan711_meetups_assign_event_id',
        'trg_kan711_events_keep_updated_at', 'trg_kan711_games_mirror', 'trg_kan711_meetups_mirror') AND tgenabled = 'O') <> 5 THEN
    RAISE EXCEPTION 'KAN-712 cutover: the five KAN-711 triggers are not all present and enabled';
  END IF;
  -- Backfill finished, nothing unresolved.
  IF EXISTS (SELECT 1 FROM public.events_backfill_checkpoint WHERE finished_at IS NULL)
     OR (SELECT count(*) FROM public.events_backfill_checkpoint) <> 2 THEN
    RAISE EXCEPTION 'KAN-712 cutover: KAN-711 backfill not finished for both kinds';
  END IF;
  SELECT count(*) INTO v_n FROM public.events_backfill_exceptions WHERE resolved_at IS NULL;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'KAN-712 cutover: % unresolved KAN-711 backfill exceptions', v_n;
  END IF;
  -- Links validated (kan711_events_validate_links has run and succeeded).
  IF (SELECT count(*) FROM pg_constraint WHERE conname IN ('games_event_id_not_null', 'meetups_event_id_not_null') AND convalidated) <> 2
     OR (SELECT count(*) FROM pg_constraint WHERE conname IN ('games_event_id_fkey', 'meetups_event_id_fkey') AND convalidated) <> 2 THEN
    RAISE EXCEPTION 'KAN-712 cutover: run public.kan711_events_validate_links() first (event_id NOT NULL / FK not validated)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.games WHERE event_id IS NULL) OR EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS NULL) THEN
    RAISE EXCEPTION 'KAN-712 cutover: legacy rows with NULL event_id';
  END IF;
  -- Parity: zero rows. Computed under the table locks above, so nothing can drift before commit.
  SELECT count(*) INTO v_n FROM public.kan711_events_parity;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'KAN-712 cutover: kan711_events_parity has % rows (must be 0)', v_n;
  END IF;
  -- No parent without a child (the guard and compat mirror assume 1:1 for linked rows).
  SELECT count(*) INTO v_n FROM public.events e
   WHERE NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = e.id)
     AND NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = e.id);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'KAN-712 cutover: % events rows have no legacy child', v_n;
  END IF;
END $$;

-- 2. Direction switch ------------------------------------------------------------------------------
ALTER TABLE public.games   DISABLE TRIGGER trg_kan711_games_mirror;
ALTER TABLE public.meetups DISABLE TRIGGER trg_kan711_meetups_mirror;

CREATE TRIGGER trg_zz_kan712_games_guard   BEFORE INSERT OR UPDATE ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan712_legacy_guard();
CREATE TRIGGER trg_zz_kan712_meetups_guard BEFORE INSERT OR UPDATE ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.kan712_legacy_guard();
CREATE TRIGGER trg_zz_kan712_games_after_delete   AFTER DELETE ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.kan712_legacy_after_delete();
CREATE TRIGGER trg_zz_kan712_meetups_after_delete AFTER DELETE ON public.meetups
  FOR EACH ROW EXECUTE FUNCTION public.kan712_legacy_after_delete();
CREATE TRIGGER trg_zz_kan712_events_compat_mirror AFTER UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.kan712_events_compat_mirror();

-- 3. Wrap every UPDATE-path RPC (all overloads of each name). Required names must exist. ------------
DO $$
DECLARE
  t record;
  f record;
  v_hits int;
BEGIN
  FOR t IN SELECT * FROM (VALUES
      ('rpc_update_game',                     'game:p_game_id',      true),
      ('rpc_update_game_legacy_v1',           'game:p_game_id',      false),
      ('rpc_reschedule_game',                 'game:p_game_id',      true),
      ('rpc_cancel_game',                     'game:p_game_id',      true),
      ('rpc_booking_hold_for_game',           'game:p_game_id',      true),
      ('rpc_edit_game_series_occurrence',     'game:p_game_id',      true),
      ('rpc_meetup_update',                   'meetup:p_meetup_id',  true),
      ('rpc_meetup_cancel',                   'meetup:p_meetup_id',  true),
      ('rpc_edit_game_series_future',         'series:p_series_id',  true),
      ('rpc_cancel_game_series',              'series:p_series_id',  true),
      ('fn_generate_game_series_occurrences', 'series:p_series_id',  true)
    ) AS v(name, lock_spec, required)
  LOOP
    v_hits := 0;
    FOR f IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
              WHERE p.pronamespace = 'public'::regnamespace AND p.proname = t.name ORDER BY p.oid LOOP
      PERFORM public.kan712_wrap_rpc(f.sig, t.lock_spec);
      v_hits := v_hits + 1;
    END LOOP;
    IF v_hits = 0 AND t.required THEN
      RAISE EXCEPTION 'KAN-712 cutover: required RPC public.% not found', t.name;
    ELSIF v_hits = 0 THEN
      RAISE NOTICE 'KAN-712 cutover: optional RPC public.% absent, skipped', t.name;
    END IF;
  END LOOP;
END $$;

-- 4. Post-conditions ---------------------------------------------------------------------------------
DO $$
DECLARE
  r record;
  v_bad text;
BEGIN
  -- 4a. Wrapped RPCs: ACL equals the recorded original; wrapper attributes; inner closed.
  -- identity_args carries argument names, which to_regprocedure() rejects; match on pg_proc instead.
  FOR r IN SELECT w.*,
                  (SELECT x.oid FROM pg_proc x WHERE x.pronamespace = 'public'::regnamespace AND x.proname = w.name
                      AND pg_get_function_identity_arguments(x.oid) = w.identity_args) AS wf,
                  (SELECT x.oid FROM pg_proc x WHERE x.pronamespace = 'public'::regnamespace AND x.proname = w.inner_name
                      AND pg_get_function_identity_arguments(x.oid) = w.identity_args) AS inf
             FROM public.kan712_wrapped_rpcs w LOOP
    IF r.wf IS NULL OR r.inf IS NULL THEN
      RAISE EXCEPTION 'KAN-712 post: wrapper or inner missing for %(%)', r.name, r.identity_args;
    END IF;
    IF EXISTS (
         (SELECT a.grantee, a.privilege_type, a.is_grantable FROM pg_proc p,
                 aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE p.oid = r.wf AND a.grantee <> p.proowner)
         EXCEPT
         (SELECT a.grantee, a.privilege_type, a.is_grantable FROM aclexplode(coalesce(r.original_acl, acldefault('f', r.original_owner))) a
           WHERE a.grantee <> r.original_owner))
       OR EXISTS (
         (SELECT a.grantee, a.privilege_type, a.is_grantable FROM aclexplode(coalesce(r.original_acl, acldefault('f', r.original_owner))) a
           WHERE a.grantee <> r.original_owner)
         EXCEPT
         (SELECT a.grantee, a.privilege_type, a.is_grantable FROM pg_proc p,
                 aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a WHERE p.oid = r.wf AND a.grantee <> p.proowner)) THEN
      RAISE EXCEPTION 'KAN-712 post: ACL of wrapper %(%) differs from the original', r.name, r.identity_args;
    END IF;
    IF (SELECT proowner FROM pg_proc WHERE oid = r.wf) <> r.original_owner THEN
      RAISE EXCEPTION 'KAN-712 post: owner of wrapper %(%) changed', r.name, r.identity_args;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = r.wf AND p.prosecdef
                      AND 'search_path=""' = ANY (coalesce(p.proconfig, '{}'))
                      AND 'kan712.contract=on' = ANY (coalesce(p.proconfig, '{}'))) THEN
      RAISE EXCEPTION 'KAN-712 post: wrapper %(%) lacks SECURITY DEFINER / search_path / kan712.contract', r.name, r.identity_args;
    END IF;
    IF has_function_privilege('anon', r.inf, 'EXECUTE') OR has_function_privilege('authenticated', r.inf, 'EXECUTE')
       OR has_function_privilege('service_role', r.inf, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                   WHERE p.oid = r.inf AND a.grantee <> p.proowner) THEN
      RAISE EXCEPTION 'KAN-712 post: inner % is executable by a role other than its owner', r.inf;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM public.kan712_wrapped_rpcs) < 10 THEN
    RAISE EXCEPTION 'KAN-712 post: expected at least 10 wrapped RPCs';
  END IF;

  -- 4b. kan712 functions: pinned search_path, not executable by API roles (update_event_shared: service_role only).
  FOR r IN SELECT p.oid::regprocedure AS f, p.proname, p.proconfig FROM pg_proc p
            WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'kan712\_%' AND p.proname NOT LIKE '%\_kan712\_inner' LOOP
    IF NOT ('search_path=""' = ANY (coalesce(r.proconfig, '{}'))) THEN
      RAISE EXCEPTION 'KAN-712 post: % lacks SET search_path = ''''', r.f;
    END IF;
    IF has_function_privilege('anon', r.f, 'EXECUTE') OR has_function_privilege('authenticated', r.f, 'EXECUTE')
       OR has_function_privilege('service_role', r.f, 'EXECUTE') <> (r.proname = 'kan712_update_event_shared') THEN
      RAISE EXCEPTION 'KAN-712 post: EXECUTE on % is wrong', r.f;
    END IF;
  END LOOP;

  -- 4c. Trigger shape.
  IF (SELECT array_agg(tgname::text ORDER BY tgname::text COLLATE "C") FROM pg_trigger
       WHERE tgrelid = 'public.events'::regclass AND NOT tgisinternal)
     IS DISTINCT FROM ARRAY['trg_events_exclusive_check', 'trg_events_search_tsv', 'trg_events_series_start_check',
                            'trg_events_touch', 'trg_events_type_immutable',
                            'trg_kan711_events_keep_updated_at', 'trg_zz_kan712_events_compat_mirror'] THEN
    RAISE EXCEPTION 'KAN-712 post: events trigger set differs from KAN-710 five + KAN-711 keeper + KAN-712 compat mirror';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_kan711_games_mirror', 'trg_kan711_meetups_mirror') AND tgenabled = 'D') <> 2 THEN
    RAISE EXCEPTION 'KAN-712 post: KAN-711 mirrors are not both disabled';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_kan711_games_assign_event_id', 'trg_kan711_meetups_assign_event_id',
        'trg_kan711_events_keep_updated_at') AND tgenabled = 'O') <> 3 THEN
    RAISE EXCEPTION 'KAN-712 post: KAN-711 assigners/keeper must stay enabled';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'trg\_zz\_kan712\_%' AND tgenabled = 'O') <> 5 THEN
    RAISE EXCEPTION 'KAN-712 post: expected 5 enabled kan712 triggers';
  END IF;
  -- The guard must be the LAST BEFORE ROW trigger on each legacy table (it maps the final row).
  FOR r IN SELECT c.relname, (SELECT max(t.tgname::text COLLATE "C") FROM pg_trigger t
                               WHERE t.tgrelid = c.oid AND NOT t.tgisinternal AND (t.tgtype & 2) = 2 AND (t.tgtype & 1) = 1) AS last_before
             FROM pg_class c WHERE c.oid IN ('public.games'::regclass, 'public.meetups'::regclass) LOOP
    IF r.last_before <> format('trg_zz_kan712_%s_guard', r.relname) THEN
      RAISE EXCEPTION 'KAN-712 post: % has BEFORE ROW trigger % sorting after the guard', r.relname, r.last_before;
    END IF;
  END LOOP;

  -- 4d. Fail closed on unclassified writers. Any public function (other than kan711_/kan712_ machinery
  -- and the renamed inners, which only wrappers can call) whose source UPDATEs games/meetups is
  -- unclassified; INSERT/DELETE is allowed only for the reviewed creators/cleanup (routed by the guard
  -- and the after-delete trigger). Classify the hit in KAN712_CONTRACT.md and wrap or allowlist it.
  SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text) INTO v_bad
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname NOT LIKE 'kan711\_%' AND p.proname NOT LIKE 'kan712\_%' AND p.proname NOT LIKE '%\_kan712\_inner'
     AND (
       p.prosrc ~* '\mupdate\s+(only\s+)?("?public"?\s*\.\s*)?"?(games|meetups)\M'
       OR (p.prosrc ~* '\m(insert\s+into|delete\s+from)\s+(only\s+)?("?public"?\s*\.\s*)?"?(games|meetups)\M'
           AND p.proname NOT IN ('rpc_create_game', 'rpc_create_game_legacy_v1', 'rpc_create_game_legacy_v2',
                                 'rpc_create_meetup', 'rpc_create_meetup_legacy_v1', 'rpc_create_meetup_legacy_v2',
                                 'rpc_challenge_spawn_game', 'admin_cleanup_user_data'))
     );
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-712 post: unclassified writers of games/meetups: %', v_bad;
  END IF;
END $$;

COMMIT;
