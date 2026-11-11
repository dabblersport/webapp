-- KAN-913 (KAN-714 W, Epic KAN-708): move the reads of public.rpc_cancel_game_kan712_inner(uuid,text) off the 22
-- public.games columns that KAN-866 will drop, onto public.events. Writes do not move.
--
-- AUTHORED, NOT APPLIED. Memphis applies it (D-043). Local proof:
-- supabase/tests/events_p4/kan714_w_rpc_cancel_game_kan712_inner_test.sql.
--
-- THE 22 COLUMNS (CTO rule): creator_profile_id, creator_user_id, title, start_at, end_at, capacity,
-- listing_visibility, join_policy, is_cancelled, cancelled_at, cancelled_reason, sport_id, area_id,
-- geo_location_id, venue_id, min_skill, max_skill, joining_rule, cost_cover, request_id, created_at, updated_at.
--
-- PRE-IMAGE: the KAN-810 body (20261104112000_kan810_cancel_game_idempotent.sql, its post-image; no later migration
-- redefines it: grep over supabase/migrations/). Taken from pg_get_functiondef on the local tracked chain (T-058):
--   md5(prosrc)                 = f5b4c52d331cc03f6d6a7ae806cd3f36
--   md5(pg_get_functiondef(..)) = 89cb182331912604be5f093b650e83d7
-- Its games column use:
--   READ  (WHERE of the UPDATE)  id, creator_user_id, is_cancelled
--   READ  (NOT FOUND fallback)   id, creator_user_id, is_cancelled
--   WRITE (UPDATE ... SET)       is_cancelled, cancelled_at, cancelled_reason
-- Of the reads, creator_user_id and is_cancelled are in the 22; id is not.
--
-- CHANGE (the inner body only):
--   * UPDATE target public.games and its SET list are byte-identical. The WHERE keeps  id = p_game_id  and reads the
--     host / cancel predicate from the parent row instead:
--       AND event_id IN (SELECT e.id FROM public.events e WHERE e.event_type = 'game'
--                          AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
--                          AND e.is_cancelled IS NOT TRUE)
--     (event_id is not one of the 22.)
--   * The NOT FOUND fallback reads the same predicate from public.events, joined e.id = g.event_id AND
--     e.event_type = 'game'.
--   Semantics are identical while games and events agree on creator_user_id and is_cancelled for every game and every
--   game has its parent: the KAN-712 compat mirror keeps that true, and the stage guard below refuses to apply if it is
--   not true now. The wrapper still holds the events row FOR UPDATE, so the UPDATE and the fallback read stay
--   serialised against a concurrent cancel. events.is_cancelled is NOT NULL (20261101140000), as games.is_cancelled.
--
-- KAN-712: rpc_cancel_game IS WRAPPED (kan712_wrapped_rpcs row, lock_spec 'game:p_game_id'). The body is changed only
-- through the contract path, exactly as 20261104112000_kan810_cancel_game_idempotent.sql does, in this one
-- transaction: 2a kan712_unwrap_rpc, 2b CREATE OR REPLACE public.rpc_cancel_game (the unwrapped original),
-- 2c kan712_wrap_rpc with the recorded lock_spec. Signature, defaults, return type, owner, ACL, SECURITY DEFINER,
-- search_path and volatility of both functions are unchanged and asserted.
--
-- No DROP except the wrapper DROP inside kan712_unwrap_rpc (re-created by 2c with the recorded ACL), no CASCADE, no
-- grant change, no data mutation, no other function touched.
--
-- ROLLBACK (commented; one transaction, superuser): the full pre-image definition, restored through the same path.
--   BEGIN;
--   CREATE TEMP TABLE kan913_rb ON COMMIT DROP AS
--     SELECT name, identity_args, lock_spec FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_cancel_game';
--   SELECT public.kan712_unwrap_rpc(name, identity_args) FROM pg_temp.kan913_rb;
--   CREATE OR REPLACE FUNCTION public.rpc_cancel_game(p_game_id uuid, p_reason text DEFAULT NULL::text)
--    RETURNS text
--    LANGUAGE plpgsql
--    SECURITY DEFINER
--    SET search_path TO 'public'
--   AS $function$
--   BEGIN
--     UPDATE public.games
--     SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
--     WHERE id = p_game_id
--       AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
--       AND is_cancelled IS NOT TRUE;   -- KAN-810: a repeat cancel keeps the first cancel's cancelled_at / reason
--     IF NOT FOUND THEN
--       -- KAN-810: already cancelled, and the caller may cancel it: same result as before, nothing rewritten.
--       IF EXISTS (SELECT 1 FROM public.games
--                   WHERE id = p_game_id
--                     AND is_cancelled IS TRUE
--                     AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()))) THEN
--         RETURN 'cancelled';
--       END IF;
--       RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
--     END IF;
--     RETURN 'cancelled';
--   END$function$;
--   SELECT public.kan712_wrap_rpc('public.rpc_cancel_game(uuid,text)'::regprocedure, lock_spec) FROM pg_temp.kan913_rb;
--   DO $rb$ BEGIN
--     IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure)
--        <> 'f5b4c52d331cc03f6d6a7ae806cd3f36' THEN
--       RAISE EXCEPTION 'KAN-913 rollback: inner is not the pre-image after restore';
--     END IF;
--   END $rb$;
--   COMMIT;
-- (The rollback body is plain text inside the dollar quote: un-comment by removing the leading "--   ".)
--
-- LIVE DIFF for Memphis (read-only; run BEFORE and AFTER applying, and diff). Row 1 rpc_cancel_game: src_md5 and
-- every attribute identical before and after (local chain: 32e9b96473d6351cc2a10db926212822), proacl
-- {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}, proconfig
-- {"search_path=\"\""}. Row 2 rpc_cancel_game_kan712_inner: src_md5 f5b4c52d331cc03f6d6a7ae806cd3f36 before,
-- 39f496234ef7fd35295ab0ab4740f703 after; proacl {postgres=X/postgres}, proconfig {search_path=public}, prosecdef t,
-- provolatile v, owner postgres, args and result identical. Then wrapped_rows 1 and parity_mismatch 0 both times;
-- legacy_reads 1 before, 0 after.
--
--   SELECT p.oid::regprocedure AS fn, md5(p.prosrc) AS src_md5, p.proacl, p.proconfig, p.prosecdef, p.provolatile,
--          p.proowner::regrole AS owner, pg_get_function_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS res
--     FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
--      AND p.proname IN ('rpc_cancel_game', 'rpc_cancel_game_kan712_inner') ORDER BY 1;
--   SELECT (SELECT count(*) FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_cancel_game'
--             AND inner_name = 'rpc_cancel_game_kan712_inner' AND lock_spec = 'game:p_game_id') AS wrapped_rows,
--          (SELECT count(*) FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
--            WHERE e.id IS NULL OR e.creator_user_id IS DISTINCT FROM g.creator_user_id
--               OR e.is_cancelled IS DISTINCT FROM g.is_cancelled) AS parity_mismatch,
--          (SELECT count(*) FROM pg_proc WHERE oid = 'public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure
--             AND (prosrc ~* '(\mg|\mgames)\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M'
--                  OR regexp_replace(replace(prosrc, 'SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason', ''),
--                                    '--[^\n]*', '', 'g') ~* '(^|[^.a-z0-9_])(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M')) AS legacy_reads;

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  v_missing text[] := '{}';
  v_n bigint;
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-913: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-913: public.events missing (KAN-710 not applied)';
  END IF;
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.games',   'trg_zz_kan712_games_after_delete')) AS t(rel, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.rel::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      v_missing := v_missing || (r.rel || '.' || r.tg);
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    v_missing := v_missing || 'public.kan712_wrapped_rpcs'::text;
  END IF;
  IF to_regprocedure('public.kan712_unwrap_rpc(text,text)') IS NULL
     OR to_regprocedure('public.kan712_wrap_rpc(regprocedure,text)') IS NULL THEN
    v_missing := v_missing || 'public.kan712_unwrap_rpc / public.kan712_wrap_rpc'::text;
  END IF;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'KAN-913: prerequisite stage missing: %', array_to_string(v_missing, ', ');
  END IF;

  -- Wrapped exactly as KAN-712 recorded it: change it only by unwrap -> replace -> wrap.
  EXECUTE $q$SELECT count(*) FROM public.kan712_wrapped_rpcs w
              WHERE (w.name, w.identity_args, w.inner_name, w.lock_spec, w.original_owner::regrole::text,
                     w.original_acl::text) =
                    ('rpc_cancel_game', 'p_game_id uuid, p_reason text', 'rpc_cancel_game_kan712_inner',
                     'game:p_game_id', 'postgres',
                     '{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}')$q$
    INTO v_n;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'KAN-913: rpc_cancel_game is not wrapped as KAN-712 recorded it — re-assess';
  END IF;

  -- The columns the new body reads exist and are NOT NULL where the predicate relies on it.
  IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'event_id' AND NOT attisdropped)
     OR NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.events'::regclass AND attname = 'creator_user_id' AND NOT attisdropped)
     OR NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.events'::regclass AND attname = 'event_type' AND NOT attisdropped)
     OR NOT (SELECT attnotnull FROM pg_attribute WHERE attrelid = 'public.events'::regclass AND attname = 'is_cancelled' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'KAN-913: games.event_id / events.creator_user_id / event_type / is_cancelled (NOT NULL) not as expected — re-assess';
  END IF;

  -- Semantics hold only while every game has its parent and both agree on the predicate columns.
  SELECT count(*) INTO v_n
    FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE e.id IS NULL OR e.creator_user_id IS DISTINCT FROM g.creator_user_id
      OR e.is_cancelled IS DISTINCT FROM g.is_cancelled;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'KAN-913: % games row(s) without their game event or differing on creator_user_id / is_cancelled — re-assess', v_n;
  END IF;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift pin: the inner must be the pre-image (KAN-810 post-image). An already-applied state fails here.
-- ---------------------------------------------------------------------------------------------------------
DO $pins$
DECLARE v text;
BEGIN
  IF to_regprocedure('public.rpc_cancel_game_kan712_inner(uuid,text)') IS NULL
     OR to_regprocedure('public.rpc_cancel_game(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'KAN-913 pin: rpc_cancel_game / rpc_cancel_game_kan712_inner missing';
  END IF;
  SELECT md5(prosrc) INTO v FROM pg_proc WHERE oid = to_regprocedure('public.rpc_cancel_game_kan712_inner(uuid,text)');
  IF v IS DISTINCT FROM 'f5b4c52d331cc03f6d6a7ae806cd3f36' THEN
    RAISE EXCEPTION 'KAN-913 pin: rpc_cancel_game_kan712_inner body drifted (md5(prosrc) % expected f5b4c52d331cc03f6d6a7ae806cd3f36) — already applied, or the pre-image moved', v;
  END IF;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('rpc_cancel_game', 'rpc_cancel_game_kan712_inner')) <> 2 THEN
    RAISE EXCEPTION 'KAN-913 pin: an overload of rpc_cancel_game exists — re-assess';
  END IF;
END
$pins$;

-- Attribute capture for the post-conditions (ON COMMIT DROP). Keyed by signature: the wrapper is re-created (new oid),
-- the body keeps its oid (rename, replace, rename).
CREATE TEMP TABLE kan913_pre ON COMMIT DROP AS
  SELECT p.oid::regprocedure::text AS sig, p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile,
         p.proconfig, pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS res,
         pg_get_function_arguments(p.oid) AS full_args, md5(pg_get_functiondef(p.oid)) AS md
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname IN ('rpc_cancel_game', 'rpc_cancel_game_kan712_inner');
CREATE TEMP TABLE kan913_pre_wrapped ON COMMIT DROP AS
  SELECT CASE WHEN w.name = 'rpc_cancel_game' THEN (to_jsonb(w) - 'wrapped_at')::text ELSE to_jsonb(w)::text END AS row_text
    FROM public.kan712_wrapped_rpcs w;
CREATE TEMP TABLE kan913_pre_others ON COMMIT DROP AS
  SELECT p.oid::regprocedure::text AS sig, md5(pg_get_functiondef(p.oid)) AS md, p.proacl::text AS acl
    FROM public.kan712_wrapped_rpcs w
    JOIN pg_proc p ON p.pronamespace = 'public'::regnamespace AND p.proname IN (w.name, w.inner_name)
                  AND pg_get_function_identity_arguments(p.oid) = w.identity_args
   WHERE w.name <> 'rpc_cancel_game';
CREATE TEMP TABLE kan913_wrap ON COMMIT DROP AS
  SELECT w.name, w.identity_args, w.lock_spec FROM public.kan712_wrapped_rpcs w WHERE w.name = 'rpc_cancel_game';

-- ---------------------------------------------------------------------------------------------------------
-- 2a. Unwrap (KAN712_CONTRACT.md path)
-- ---------------------------------------------------------------------------------------------------------
DO $unwrap$
DECLARE r record;
BEGIN
  IF (SELECT count(*) FROM pg_temp.kan913_wrap) <> 1 THEN
    RAISE EXCEPTION 'KAN-913 unwrap: expected 1 recorded row';
  END IF;
  SELECT * INTO r FROM pg_temp.kan913_wrap;
  PERFORM public.kan712_unwrap_rpc(r.name, r.identity_args);
  IF to_regprocedure('public.rpc_cancel_game_kan712_inner(uuid,text)') IS NOT NULL
     OR EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_cancel_game')
     OR (SELECT oid FROM pg_proc WHERE oid = to_regprocedure('public.rpc_cancel_game(uuid,text)'))
        IS DISTINCT FROM (SELECT oid FROM pg_temp.kan913_pre WHERE sig = 'rpc_cancel_game_kan712_inner(uuid,text)') THEN
    RAISE EXCEPTION 'KAN-913 unwrap: unexpected state after kan712_unwrap_rpc';
  END IF;
END
$unwrap$;

-- ---------------------------------------------------------------------------------------------------------
-- 2b. Replace the unwrapped body (authored from pg_get_functiondef of the inner, T-058; attributes unchanged)
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_cancel_game(p_game_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.games
  SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
  WHERE id = p_game_id
    AND event_id IN (SELECT e.id FROM public.events e   -- KAN-913: host / cancel predicate read from the parent
                      WHERE e.event_type = 'game'
                        AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
                        AND e.is_cancelled IS NOT TRUE);   -- KAN-810: a repeat cancel keeps the first cancel's cancelled_at / reason
  IF NOT FOUND THEN
    -- KAN-810: already cancelled, and the caller may cancel it: same result as before, nothing rewritten.
    IF EXISTS (SELECT 1 FROM public.games g
                 JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-913
                WHERE g.id = p_game_id
                  AND e.is_cancelled IS TRUE
                  AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))) THEN
      RETURN 'cancelled';
    END IF;
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  RETURN 'cancelled';
END$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 2c. Re-wrap with the recorded lock_spec (wrapper regenerated from the live pg_proc entry)
-- ---------------------------------------------------------------------------------------------------------
DO $wrap$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM pg_temp.kan913_wrap;
  PERFORM public.kan712_wrap_rpc(
    (SELECT p.oid FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname = r.name
        AND pg_get_function_identity_arguments(p.oid) = r.identity_args)::regprocedure, r.lock_spec);
END
$wrap$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE v text; v_src text; v_rest text;
BEGIN
  -- New inner body pinned; wrapper definition identical to what it was before this migration.
  SELECT prosrc, md5(prosrc) INTO v_src, v FROM pg_proc
   WHERE oid = to_regprocedure('public.rpc_cancel_game_kan712_inner(uuid,text)');
  IF v IS DISTINCT FROM '39f496234ef7fd35295ab0ab4740f703' THEN
    RAISE EXCEPTION 'KAN-913 post: rpc_cancel_game_kan712_inner md5(prosrc) % (expected 39f496234ef7fd35295ab0ab4740f703)', v;
  END IF;
  IF md5(pg_get_functiondef(to_regprocedure('public.rpc_cancel_game(uuid,text)')))
     IS DISTINCT FROM (SELECT md FROM pg_temp.kan913_pre WHERE sig = 'rpc_cancel_game(uuid,text)') THEN
    RAISE EXCEPTION 'KAN-913 post: the regenerated rpc_cancel_game wrapper differs from the pre-image wrapper';
  END IF;

  -- No read of the 22 columns left on games: none qualified by g. / games., and, outside the unchanged UPDATE SET list,
  -- none unqualified (every remaining occurrence is e.<column>).
  IF v_src ~* '(\mg|\mgames)\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M' THEN
    RAISE EXCEPTION 'KAN-913 post: the inner still reads a legacy games column through g. / games.';
  END IF;
  IF (length(v_src) - length(replace(v_src, 'SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason', '')))
     <> length('SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason')
     OR position('UPDATE public.games' IN v_src) = 0 THEN
    RAISE EXCEPTION 'KAN-913 post: the UPDATE public.games SET list is not exactly the pre-image one';
  END IF;
  v_rest := regexp_replace(replace(v_src, 'SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason', ''),
                           '--[^\n]*', '', 'g');
  IF v_rest ~* '(^|[^.a-z0-9_])(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M' THEN
    RAISE EXCEPTION 'KAN-913 post: the inner reads a legacy column unqualified outside the UPDATE SET list';
  END IF;

  -- Signature, arguments/defaults, result, owner, ACL, SECURITY DEFINER, volatility, search_path identical for both;
  -- the inner (body) oid unchanged.
  IF EXISTS (SELECT 1 FROM pg_temp.kan913_pre p LEFT JOIN pg_proc c ON c.oid = to_regprocedure(p.sig)
              WHERE c.oid IS NULL OR c.proowner <> p.proowner OR c.proacl::text IS DISTINCT FROM p.acl
                 OR c.prosecdef <> p.prosecdef OR c.provolatile <> p.provolatile
                 OR c.proconfig IS DISTINCT FROM p.proconfig
                 OR pg_get_function_identity_arguments(c.oid) <> p.args
                 OR pg_get_function_arguments(c.oid) <> p.full_args
                 OR pg_get_function_result(c.oid) <> p.res
                 OR (p.sig LIKE '%\_kan712\_inner(%' AND c.oid <> p.oid))
     OR (SELECT count(*) FROM pg_temp.kan913_pre) <> 2 THEN
    RAISE EXCEPTION 'KAN-913 post: signature / owner / ACL / SECURITY DEFINER / volatility / search_path / inner oid changed';
  END IF;
  -- The wrapper survived and its ACL equals the original ACL recorded by KAN-712.
  IF (SELECT count(*) FROM public.kan712_wrapped_rpcs w JOIN pg_proc p
         ON p.pronamespace = 'public'::regnamespace AND p.proname = w.name
        AND pg_get_function_identity_arguments(p.oid) = w.identity_args
       WHERE w.name = 'rpc_cancel_game'
         AND position('set_config(''kan712.contract'', ''on'', true)' IN p.prosrc) > 0
         AND p.prosrc LIKE '%public.' || w.inner_name || '(%'
         AND p.prosrc LIKE '%FOR UPDATE%'
         AND p.proacl::text IS NOT DISTINCT FROM w.original_acl::text) <> 1 THEN
    RAISE EXCEPTION 'KAN-913 post: rpc_cancel_game is not wrapped again as KAN-712 recorded it';
  END IF;
  -- No overload; the inner is owner-only.
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('rpc_cancel_game', 'rpc_cancel_game_kan712_inner')) <> 2
     OR EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                 WHERE p.oid = to_regprocedure('public.rpc_cancel_game_kan712_inner(uuid,text)')
                   AND a.grantee <> p.proowner) THEN
    RAISE EXCEPTION 'KAN-913 post: overload count changed or the inner became callable by a non-owner';
  END IF;
  -- Control rows identical: rpc_cancel_game except wrapped_at, every other row byte-identical.
  IF EXISTS (SELECT row_text FROM pg_temp.kan913_pre_wrapped
             EXCEPT SELECT CASE WHEN w.name = 'rpc_cancel_game' THEN (to_jsonb(w) - 'wrapped_at')::text
                                ELSE to_jsonb(w)::text END FROM public.kan712_wrapped_rpcs w)
     OR EXISTS (SELECT CASE WHEN w.name = 'rpc_cancel_game' THEN (to_jsonb(w) - 'wrapped_at')::text
                            ELSE to_jsonb(w)::text END FROM public.kan712_wrapped_rpcs w
                EXCEPT SELECT row_text FROM pg_temp.kan913_pre_wrapped) THEN
    RAISE EXCEPTION 'KAN-913 post: kan712_wrapped_rpcs changed';
  END IF;
  -- Every other wrapped RPC untouched.
  IF EXISTS (SELECT 1 FROM pg_temp.kan913_pre_others o
              WHERE to_regprocedure(o.sig) IS NULL
                 OR md5(pg_get_functiondef(to_regprocedure(o.sig))) IS DISTINCT FROM o.md
                 OR (SELECT proacl::text FROM pg_proc WHERE oid = to_regprocedure(o.sig)) IS DISTINCT FROM o.acl) THEN
    RAISE EXCEPTION 'KAN-913 post: another KAN-712-wrapped RPC changed';
  END IF;
END
$post$;

COMMIT;
