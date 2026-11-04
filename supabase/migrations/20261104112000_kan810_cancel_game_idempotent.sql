-- KAN-810 (supporting fix for KAN-761 finding F4): a second rpc_cancel_game of an already-cancelled game no longer
-- overwrites the first cancel's cancelled_at / cancelled_reason.
--
-- AUTHORED, NOT APPLIED. Local proof only: supabase/tests/events_p4/kan810_cancel_idempotent.sql on the chain built by
-- supabase/tests/events_p4/build_kan810.sh. Rollback: the commented block at the end of this file.
--
-- DEFECT. public.rpc_cancel_game_kan712_inner(uuid,text) is the baseline rpc_cancel_game body
-- (20260829080500_baseline_schema.sql:11246-11259), renamed by the KAN-712 cutover (20261103110000:107); no later
-- migration redefines it (grep over supabase/migrations/). Its
--   UPDATE public.games SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
--    WHERE id = p_game_id AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()));
-- has no guard on is_cancelled, so a repeat cancel by the host or an admin rewrites cancelled_at and cancelled_reason.
-- Side effects are not doubled today and are not doubled after this change: trg_game_updated_notify and
-- msg_system_game_cancelled fire only on a false -> true transition of is_cancelled.
--
-- FIX (the inner body only):
--   * the UPDATE adds  AND is_cancelled IS NOT TRUE  (games.is_cancelled is NOT NULL DEFAULT false, baseline :22879,
--     so this equals "= false"; IS NOT TRUE is kept so a NULL could never be silently skipped);
--   * on NOT FOUND, it returns 'cancelled' when the game exists, is already cancelled and the caller is the host or
--     an admin (the same predicate as the UPDATE) — exactly what a repeat cancel returned before, minus the rewrite;
--   * otherwise it raises P0001 not_host_or_not_found, exactly as before (missing game, or a non-host non-admin,
--     whether or not the game is cancelled).
-- No other behaviour changes. A repeat cancel now writes no row at all, so games.updated_at / events.updated_at are no
-- longer bumped by it either (they were before, as a by-product of the rewrite). The read stays on games, as the
-- pre-image does (the compat mirror keeps games equal to events; the wrapper already holds the events row FOR UPDATE,
-- so the UPDATE and the fallback read are serialised against any concurrent cancel). The phase-4 repoint of this body
-- to events is still owed (supabase/tests/events_p4/kan719_z03_prestop_gate.sql:72 lists it); it is not done here.
-- Callers: rpc_cancel_game_series_kan712_inner and rpc_edit_game_series_future_kan712_inner call rpc_cancel_game only
-- for occurrences with NOT COALESCE(e.is_cancelled, false), so they never reach the new branch.
--
-- KAN-712: rpc_cancel_game IS WRAPPED (kan712_wrapped_rpcs row, lock_spec 'game:p_game_id'). This migration never
-- CREATE OR REPLACEs the wrapper. It changes the body through the contract path (KAN712_CONTRACT.md; as
-- 20261104101400_kan714_b14_series_rpc_reads.sql does), in this one transaction:
--   2a kan712_unwrap_rpc('rpc_cancel_game', identity_args): drops the generated wrapper, renames the inner back to
--      rpc_cancel_game, restores the recorded owner and ACL, deletes the control row;
--   2b CREATE OR REPLACE public.rpc_cancel_game(...) — at this point it IS the unwrapped original, not a wrapper;
--   2c kan712_wrap_rpc(rpc_cancel_game(uuid,text)::regprocedure, <recorded lock_spec>): regenerates the wrapper from
--      the live pg_proc entry (T-058), re-inserts the control row, renames the body to rpc_cancel_game_kan712_inner
--      and strips every API grant from it.
-- PRE-IMAGE: authored from pg_get_functiondef of rpc_cancel_game_kan712_inner on the local chain catalogue (T-058),
-- not from the migration file; only the name differs from the baseline text.
--
-- No DROP except the wrapper DROP inside kan712_unwrap_rpc (re-created by 2c with the recorded ACL), no CASCADE, no
-- grant change, no product-data mutation, no other function touched. Single transaction.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  v_missing text[] := '{}';
  v_n int;
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-810: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-810: public.events missing (KAN-710 not applied)';
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
    RAISE EXCEPTION 'KAN-810: prerequisite stage missing: %', array_to_string(v_missing, ', ');
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
    RAISE EXCEPTION 'KAN-810: rpc_cancel_game is not wrapped as KAN-712 recorded it — re-assess';
  END IF;

  -- games.is_cancelled is NOT NULL (the fix reads it in a WHERE clause).
  IF NOT (SELECT attnotnull FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'is_cancelled') THEN
    RAISE EXCEPTION 'KAN-810: games.is_cancelled is nullable — re-assess';
  END IF;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift pins: the inner must be the pre-image (an already-applied state fails here); the wrapper is pinned.
-- ---------------------------------------------------------------------------------------------------------
DO $pins$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_cancel_game_kan712_inner(uuid,text)', 'e12056fd977b7305f8318e60a49b6f1b', '0b5bd8bbda5cfac206e75b262503c0cf'),
      ('public.rpc_cancel_game(uuid,text)',              'bf9763ac173e917cab60949d801e86f2', '04c4a67e76499824dc9a632fd70e63fc')
    ) AS t(fn, md_def, md_src)
  LOOP
    IF to_regprocedure(r.fn) IS NULL THEN
      RAISE EXCEPTION 'KAN-810 pin: % missing', r.fn;
    END IF;
    IF md5(pg_get_functiondef(to_regprocedure(r.fn))) IS DISTINCT FROM r.md_def
       OR (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure(r.fn)) IS DISTINCT FROM r.md_src THEN
      RAISE EXCEPTION 'KAN-810 pin: % drifted (functiondef md5 %, prosrc md5 %) — already applied, or the pre-image moved',
        r.fn, md5(pg_get_functiondef(to_regprocedure(r.fn))),
        (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure(r.fn));
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('rpc_cancel_game', 'rpc_cancel_game_kan712_inner')) <> 2 THEN
    RAISE EXCEPTION 'KAN-810 pin: an overload of rpc_cancel_game exists — re-assess';
  END IF;
END
$pins$;

-- Attribute capture for the post-conditions (ON COMMIT DROP). Keyed by signature: the wrapper is re-created (new oid),
-- the body keeps its oid (rename, replace, rename).
CREATE TEMP TABLE kan810_pre ON COMMIT DROP AS
  SELECT p.oid::regprocedure::text AS sig, p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile,
         p.proconfig, pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS res,
         pg_get_function_arguments(p.oid) AS full_args, md5(pg_get_functiondef(p.oid)) AS md
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname IN ('rpc_cancel_game', 'rpc_cancel_game_kan712_inner');
CREATE TEMP TABLE kan810_pre_wrapped ON COMMIT DROP AS
  SELECT CASE WHEN w.name = 'rpc_cancel_game' THEN (to_jsonb(w) - 'wrapped_at')::text ELSE to_jsonb(w)::text END AS row_text
    FROM public.kan712_wrapped_rpcs w;
CREATE TEMP TABLE kan810_pre_others ON COMMIT DROP AS
  SELECT p.oid::regprocedure::text AS sig, md5(pg_get_functiondef(p.oid)) AS md, p.proacl::text AS acl
    FROM public.kan712_wrapped_rpcs w
    JOIN pg_proc p ON p.pronamespace = 'public'::regnamespace AND p.proname IN (w.name, w.inner_name)
                  AND pg_get_function_identity_arguments(p.oid) = w.identity_args
   WHERE w.name <> 'rpc_cancel_game';
CREATE TEMP TABLE kan810_wrap ON COMMIT DROP AS
  SELECT w.name, w.identity_args, w.lock_spec FROM public.kan712_wrapped_rpcs w WHERE w.name = 'rpc_cancel_game';

-- ---------------------------------------------------------------------------------------------------------
-- 2a. Unwrap (KAN712_CONTRACT.md path)
-- ---------------------------------------------------------------------------------------------------------
DO $unwrap$
DECLARE r record;
BEGIN
  IF (SELECT count(*) FROM pg_temp.kan810_wrap) <> 1 THEN
    RAISE EXCEPTION 'KAN-810 unwrap: expected 1 recorded row';
  END IF;
  SELECT * INTO r FROM pg_temp.kan810_wrap;
  PERFORM public.kan712_unwrap_rpc(r.name, r.identity_args);
  IF to_regprocedure('public.rpc_cancel_game_kan712_inner(uuid,text)') IS NOT NULL
     OR EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_cancel_game')
     OR (SELECT oid FROM pg_proc WHERE oid = to_regprocedure('public.rpc_cancel_game(uuid,text)'))
        IS DISTINCT FROM (SELECT oid FROM pg_temp.kan810_pre WHERE sig = 'rpc_cancel_game_kan712_inner(uuid,text)') THEN
    RAISE EXCEPTION 'KAN-810 unwrap: unexpected state after kan712_unwrap_rpc';
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
    AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
    AND is_cancelled IS NOT TRUE;   -- KAN-810: a repeat cancel keeps the first cancel's cancelled_at / reason
  IF NOT FOUND THEN
    -- KAN-810: already cancelled, and the caller may cancel it: same result as before, nothing rewritten.
    IF EXISTS (SELECT 1 FROM public.games
                WHERE id = p_game_id
                  AND is_cancelled IS TRUE
                  AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()))) THEN
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
  SELECT * INTO r FROM pg_temp.kan810_wrap;
  PERFORM public.kan712_wrap_rpc(
    (SELECT p.oid FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname = r.name
        AND pg_get_function_identity_arguments(p.oid) = r.identity_args)::regprocedure, r.lock_spec);
END
$wrap$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; v text;
BEGIN
  -- New inner definition pinned; wrapper byte-identical to the pre-image.
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_cancel_game_kan712_inner(uuid,text)', '89cb182331912604be5f093b650e83d7'),
      ('public.rpc_cancel_game(uuid,text)',              'bf9763ac173e917cab60949d801e86f2')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-810 post: % definition md5 % (expected %)', r.fn, v, r.md;
    END IF;
  END LOOP;

  -- Signature, arguments/defaults, result, owner, ACL, SECURITY DEFINER, volatility, search_path identical for both;
  -- the inner (body) oid unchanged.
  IF EXISTS (SELECT 1 FROM pg_temp.kan810_pre p LEFT JOIN pg_proc c ON c.oid = to_regprocedure(p.sig)
              WHERE c.oid IS NULL OR c.proowner <> p.proowner OR c.proacl::text IS DISTINCT FROM p.acl
                 OR c.prosecdef <> p.prosecdef OR c.provolatile <> p.provolatile
                 OR c.proconfig IS DISTINCT FROM p.proconfig
                 OR pg_get_function_identity_arguments(c.oid) <> p.args
                 OR pg_get_function_arguments(c.oid) <> p.full_args
                 OR pg_get_function_result(c.oid) <> p.res
                 OR (p.sig LIKE '%\_kan712\_inner(%' AND c.oid <> p.oid))
     OR (SELECT count(*) FROM pg_temp.kan810_pre) <> 2 THEN
    RAISE EXCEPTION 'KAN-810 post: signature / owner / ACL / SECURITY DEFINER / volatility / search_path / inner oid changed';
  END IF;
  -- The wrapper survived and its ACL equals the original ACL recorded by KAN-712.
  IF (SELECT count(*) FROM public.kan712_wrapped_rpcs w JOIN pg_proc p
         ON p.pronamespace = 'public'::regnamespace AND p.proname = w.name
        AND pg_get_function_identity_arguments(p.oid) = w.identity_args
       WHERE w.name = 'rpc_cancel_game'
         AND 'kan712.contract=on' = ANY (p.proconfig)
         AND p.prosrc LIKE '%public.' || w.inner_name || '(%'
         AND p.prosrc LIKE '%FOR UPDATE%'
         AND p.proacl::text IS NOT DISTINCT FROM w.original_acl::text) <> 1 THEN
    RAISE EXCEPTION 'KAN-810 post: rpc_cancel_game is not wrapped again as KAN-712 recorded it';
  END IF;
  -- No overload; the inner is owner-only.
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('rpc_cancel_game', 'rpc_cancel_game_kan712_inner')) <> 2
     OR EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                 WHERE p.oid = to_regprocedure('public.rpc_cancel_game_kan712_inner(uuid,text)')
                   AND a.grantee <> p.proowner) THEN
    RAISE EXCEPTION 'KAN-810 post: overload count changed or the inner became callable by a non-owner';
  END IF;
  -- Control rows identical: rpc_cancel_game except wrapped_at, every other row byte-identical.
  IF EXISTS (SELECT row_text FROM pg_temp.kan810_pre_wrapped
             EXCEPT SELECT CASE WHEN w.name = 'rpc_cancel_game' THEN (to_jsonb(w) - 'wrapped_at')::text
                                ELSE to_jsonb(w)::text END FROM public.kan712_wrapped_rpcs w)
     OR EXISTS (SELECT CASE WHEN w.name = 'rpc_cancel_game' THEN (to_jsonb(w) - 'wrapped_at')::text
                            ELSE to_jsonb(w)::text END FROM public.kan712_wrapped_rpcs w
                EXCEPT SELECT row_text FROM pg_temp.kan810_pre_wrapped) THEN
    RAISE EXCEPTION 'KAN-810 post: kan712_wrapped_rpcs changed';
  END IF;
  -- Every other wrapped RPC untouched.
  IF EXISTS (SELECT 1 FROM pg_temp.kan810_pre_others o
              WHERE to_regprocedure(o.sig) IS NULL
                 OR md5(pg_get_functiondef(to_regprocedure(o.sig))) IS DISTINCT FROM o.md
                 OR (SELECT proacl::text FROM pg_proc WHERE oid = to_regprocedure(o.sig)) IS DISTINCT FROM o.acl) THEN
    RAISE EXCEPTION 'KAN-810 post: another KAN-712-wrapped RPC changed';
  END IF;
END
$post$;

COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- ROLLBACK (commented; run as one transaction, superuser). Restores the pre-image body through the same contract
-- path. Pins: inner 89cb182331912604be5f093b650e83d7 before, e12056fd977b7305f8318e60a49b6f1b after; wrapper
-- bf9763ac173e917cab60949d801e86f2 throughout.
-- ---------------------------------------------------------------------------------------------------------
-- BEGIN;
-- DO $rb$ BEGIN
--   IF md5(pg_get_functiondef('public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure)) <> '89cb182331912604be5f093b650e83d7'
--      OR md5(pg_get_functiondef('public.rpc_cancel_game(uuid,text)'::regprocedure)) <> 'bf9763ac173e917cab60949d801e86f2' THEN
--     RAISE EXCEPTION 'KAN-810 rollback: not the KAN-810 post-image, stop';
--   END IF;
-- END $rb$;
-- CREATE TEMP TABLE kan810_rb ON COMMIT DROP AS
--   SELECT name, identity_args, lock_spec FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_cancel_game';
-- SELECT public.kan712_unwrap_rpc(name, identity_args) FROM pg_temp.kan810_rb;
-- CREATE OR REPLACE FUNCTION public.rpc_cancel_game(p_game_id uuid, p_reason text DEFAULT NULL::text)
--  RETURNS text
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
-- BEGIN
--   UPDATE public.games
--   SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
--   WHERE id = p_game_id
--     AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()));
--   IF NOT FOUND THEN
--     RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
--   END IF;
--   RETURN 'cancelled';
-- END$function$;
-- SELECT public.kan712_wrap_rpc('public.rpc_cancel_game(uuid,text)'::regprocedure, lock_spec) FROM pg_temp.kan810_rb;
-- DO $rb2$ BEGIN
--   IF md5(pg_get_functiondef('public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure)) <> 'e12056fd977b7305f8318e60a49b6f1b'
--      OR md5(pg_get_functiondef('public.rpc_cancel_game(uuid,text)'::regprocedure)) <> 'bf9763ac173e917cab60949d801e86f2'
--      OR (SELECT proacl::text FROM pg_proc WHERE oid = 'public.rpc_cancel_game(uuid,text)'::regprocedure)
--         IS DISTINCT FROM '{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
--      OR (SELECT proacl::text FROM pg_proc WHERE oid = 'public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure)
--         IS DISTINCT FROM '{postgres=X/postgres}' THEN
--     RAISE EXCEPTION 'KAN-810 rollback: post-check failed';
--   END IF;
-- END $rb2$;
-- COMMIT;
