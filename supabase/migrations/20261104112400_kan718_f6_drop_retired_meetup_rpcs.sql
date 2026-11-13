-- KAN-859 (KAN-718 follow-up F6, Epic KAN-708): DROP the two RETIRED meetup RPCs
--   public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)
--   public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)
-- KAN-802/812 RETIRE rows #20 and #21 (KAN718_D04_DISPOSITION.md:40-41; KAN718_HANDOFF.md (b) RETIRE row, (g) 4,
-- (h) CTO ruling dreq-8ae9bcfa follow-up F6). This ticket is the authorised DROP author for exactly these two
-- functions. AUTHORED, NOT APPLIED: Memphis applies it later through the normal Thebes path (PEER route,
-- backend-N reviewer). Nothing else is dropped: no table, column, grant, policy or row is touched.
--
-- WHY RETIRE. Both bodies (baseline 20260829080500:13792-13832, never redefined; ACL only re-set at
-- 20260915120000:749-753) gate on meetups.owner_user_id, which does not exist on any chain (the column is
-- creator_user_id), so every call raises 42703. There is no working behaviour to preserve and no caller
-- (KAN-859 C1, re-run on alpha-karnak cd2639ed):
--   grep -rn "<name>" lib/ test/ supabase/functions/ supabase/migrations/ lib/core/config/supabase_config.dart
--   lib/                   -> 0 hits (no constant in supabase_config.dart, no call site)
--   supabase/functions/    -> 0 hits
--   test/                  -> test/supabase/meetups_hardening_migration_test.dart:17-18 only: a static test that
--                             reads the TEXT of 20260915120000 (which is unchanged by this file); not a caller
--   supabase/migrations/   -> baseline CREATE / OWNER / GRANT lines and 20260915120000 REVOKE/GRANT + post-check
--                             (both earlier than this file); nothing later names either function
--
-- KAN-712 HANDLING. Neither function is KAN-712-wrapped (20261103110000 never names them: they write
-- meetup_invites / meetup_link_tokens, not games/meetups). A bare DROP is legal only while that holds, so the guard
-- refuses if a kan712_wrapped_rpcs row or an *_kan712_inner exists.
--
-- DRIFT GUARD (T-058 substitute: production is not read by this ticket). md5(prosrc) is pinned to the repo
-- pre-image, read back with pg_get_functiondef on a tracked local chain:
--   rpc_meetup_invite_user  08d8cc7c0d7b99653b81d9cbeaf33b82
--   rpc_meetup_mint_link    2364638777f63f9f8fe6fa9e704b4153
-- plus plpgsql, SECURITY DEFINER, search_path=public, RETURNS uuid. If either has since been changed, this
-- refuses rather than dropping a function somebody fixed.
--
-- DEPENDENTS GUARD. Refuses if anything references either function: any pg_depend row with the function as the
-- referenced object (views/rules, triggers, policies, defaults, BEGIN ATOMIC bodies, casts, operators, extension
-- membership), any trigger or event trigger using it, the name in the prosrc of any OTHER function, or (if pg_cron
-- is installed) the name in any cron.job command. The DROPs carry no CASCADE (RESTRICT is the default) and no
-- IF EXISTS: a missing function fails the guard, it is never hidden.
--
-- ORDER: 20261104112400 sorts after 20261104112200 (KAN-856 F3, and F1 on its own branch) and 20261104112300
-- (F2 getnearbygames, on another branch: that slot is taken, so this file uses the next free one) and BEFORE
-- 20261105100000 (KAN-719 Z01). The DROP is independent of Z01 (neither body reads a Z01-slated column; Z01 drops
-- nothing these reference), so either order replays. Before Z01 is chosen so that F8's re-scope of Z01 / the D06
-- manifest / G6 sees RETIRE #20 #21 already gone instead of carrying them as pending.
--
-- EFFECT ON PINNED EVIDENCE (files NOT edited by this ticket): kan714_b15_coverage_probe.sql:284-285 and
-- KAN714_READ_MANIFEST.md rows 20-21 list both functions as present ('open-write'); the KAN-427 probe pack
-- (supabase/tests/kan427/meetups_hardening_probes.sql) names them too. Run after this migration they will report
-- them absent. Refreshing them is F8 / follow-up work, not done here.
--
-- ROLLBACK (verbatim pre-image from pg_get_functiondef on the local chain, plus owner and the live ACL
-- {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}; check_function_bodies off because the
-- bodies name meetups.owner_user_id, which does not exist):
--
--   BEGIN;
--   SET LOCAL check_function_bodies = false;
--   CREATE OR REPLACE FUNCTION public.rpc_meetup_invite_user(p_meetup_id uuid, p_to_user_id uuid, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
--    RETURNS uuid
--    LANGUAGE plpgsql
--    SECURITY DEFINER
--    SET search_path TO 'public'
--   AS $function$
--   declare idd uuid;
--   begin
--     if not exists (select 1 from public.meetups m where m.id=p_meetup_id and (m.owner_user_id=auth.uid() or public.is_admin(auth.uid()))) then
--       raise exception using errcode='P0001', message='not_host';
--     end if;
--
--     insert into public.meetup_invites(meetup_id, to_user_id, created_by, expires_at)
--     values (p_meetup_id, p_to_user_id, auth.uid(), p_expires_at)
--     returning id into idd;
--
--     perform public.emit_event('meetup.invite_sent','meetup', p_meetup_id, auth.uid(), jsonb_build_object('invite_id', idd, 'to_user_id', p_to_user_id));
--     return idd;
--   end;
--   $function$;
--   ALTER FUNCTION public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone) OWNER TO postgres;
--   REVOKE ALL ON FUNCTION public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone) FROM PUBLIC, anon;
--   GRANT EXECUTE ON FUNCTION public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone) TO authenticated, service_role;
--
--   CREATE OR REPLACE FUNCTION public.rpc_meetup_mint_link(p_meetup_id uuid, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_uses integer DEFAULT NULL::integer)
--    RETURNS uuid
--    LANGUAGE plpgsql
--    SECURITY DEFINER
--    SET search_path TO 'public'
--   AS $function$
--   declare t uuid;
--   begin
--     if not exists (select 1 from public.meetups m where m.id=p_meetup_id and (m.owner_user_id=auth.uid() or public.is_admin(auth.uid()))) then
--       raise exception using errcode='P0001', message='not_host';
--     end if;
--     t := gen_random_uuid();
--     insert into public.meetup_link_tokens(meetup_id, token, created_by, expires_at, max_uses)
--     values (p_meetup_id, t, auth.uid(), p_expires_at, p_max_uses);
--     return t;
--   end;
--   $function$;
--   ALTER FUNCTION public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer) OWNER TO postgres;
--   REVOKE ALL ON FUNCTION public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer) FROM PUBLIC, anon;
--   GRANT EXECUTE ON FUNCTION public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer) TO authenticated, service_role;
--   COMMIT;
--
-- (The leading "--   " of each rollback line is the comment prefix; the body lines inside $function$ keep their
-- own two-space indent, which is part of prosrc. Restoring with that indent reproduces the pinned md5s above.)
--
-- LOCAL PROOF: supabase/tests/events_p4/kan718_f6_drop_retired_meetup_rpcs_test.sql (present before, absent after).

BEGIN;
SET LOCAL lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Pre-guard. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
DO $pre$
DECLARE
  v_inv oid := to_regprocedure('public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)');
  v_mnt oid := to_regprocedure('public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)');
  v_bad text;
BEGIN
  -- Both exist with exactly these signatures, and they are the only overloads of their names.
  IF v_inv IS NULL THEN
    RAISE EXCEPTION 'KAN-859 pre: public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone) does not exist';
  END IF;
  IF v_mnt IS NULL THEN
    RAISE EXCEPTION 'KAN-859 pre: public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer) does not exist';
  END IF;
  SELECT string_agg(p.oid::regprocedure::text, ', ') INTO v_bad
    FROM pg_proc p
   WHERE p.proname IN ('rpc_meetup_invite_user', 'rpc_meetup_mint_link')
     AND p.oid NOT IN (v_inv, v_mnt);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-859 pre: unexpected other overload(s): %', v_bad;
  END IF;

  -- The known pre-image (drift guard). Null-safe (KAN-859 C2): every term is IS NOT DISTINCT FROM / IS TRUE /
  -- IS FALSE and the whole predicate is COALESCE(..., false), so a NULL anywhere (e.g. proconfig after RESET ALL)
  -- refuses instead of passing.
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = v_inv AND NOT COALESCE((
       md5(p.prosrc) IS NOT DISTINCT FROM '08d8cc7c0d7b99653b81d9cbeaf33b82'
       AND p.prolang IS NOT DISTINCT FROM (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
       AND p.prosecdef IS TRUE AND p.prorettype IS NOT DISTINCT FROM 'uuid'::regtype AND p.proretset IS FALSE
       AND p.proconfig IS NOT DISTINCT FROM ARRAY['search_path=public']::text[]), false)) THEN
    RAISE EXCEPTION 'KAN-859 pre: rpc_meetup_invite_user drifted from the retired pre-image (md5 %), refusing to drop',
      (SELECT md5(prosrc) FROM pg_proc WHERE oid = v_inv);
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = v_mnt AND NOT COALESCE((
       md5(p.prosrc) IS NOT DISTINCT FROM '2364638777f63f9f8fe6fa9e704b4153'
       AND p.prolang IS NOT DISTINCT FROM (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
       AND p.prosecdef IS TRUE AND p.prorettype IS NOT DISTINCT FROM 'uuid'::regtype AND p.proretset IS FALSE
       AND p.proconfig IS NOT DISTINCT FROM ARRAY['search_path=public']::text[]), false)) THEN
    RAISE EXCEPTION 'KAN-859 pre: rpc_meetup_mint_link drifted from the retired pre-image (md5 %), refusing to drop',
      (SELECT md5(prosrc) FROM pg_proc WHERE oid = v_mnt);
  END IF;

  -- KAN-712: not wrapped (otherwise the KAN712_CONTRACT.md unwrap path must run first).
  IF to_regclass('public.kan712_wrapped_rpcs') IS NOT NULL THEN
    EXECUTE $q$SELECT string_agg(name::text, ', ') FROM public.kan712_wrapped_rpcs
                WHERE name::text IN ('rpc_meetup_invite_user', 'rpc_meetup_mint_link')$q$ INTO v_bad;
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION 'KAN-859 pre: KAN-712-wrapped: % (run kan712_unwrap_rpc first)', v_bad;
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc
              WHERE proname IN ('rpc_meetup_invite_user_kan712_inner', 'rpc_meetup_mint_link_kan712_inner')) THEN
    RAISE EXCEPTION 'KAN-859 pre: a *_kan712_inner exists; use the KAN-712 unwrap path';
  END IF;

  -- Zero dependents: catalogue dependencies on either function.
  SELECT string_agg(format('%s (deptype %s) on %s', pg_describe_object(d.classid, d.objid, d.objsubid),
                           d.deptype, d.refobjid::regprocedure), '; ')
    INTO v_bad
    FROM pg_depend d
   WHERE d.refclassid = 'pg_proc'::regclass AND d.refobjid IN (v_inv, v_mnt);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-859 pre: dependents exist: %', v_bad;
  END IF;
  -- Triggers / event triggers (also covered by pg_depend; asserted directly).
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgfoid IN (v_inv, v_mnt))
     OR EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtfoid IN (v_inv, v_mnt)) THEN
    RAISE EXCEPTION 'KAN-859 pre: a trigger or event trigger uses one of the functions';
  END IF;
  -- Late-bound references: any OTHER function whose source names either function.
  SELECT string_agg(p.oid::regprocedure::text, ', ') INTO v_bad
    FROM pg_proc p
   WHERE p.oid NOT IN (v_inv, v_mnt)
     AND p.prosrc ~ '(rpc_meetup_invite_user|rpc_meetup_mint_link)';
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-859 pre: other function source references a retired RPC: %', v_bad;
  END IF;
  -- Scheduled jobs (only where pg_cron is installed).
  IF to_regclass('cron.job') IS NOT NULL THEN
    EXECUTE $q$SELECT string_agg(jobid::text, ', ') FROM cron.job
                WHERE command ~ '(rpc_meetup_invite_user|rpc_meetup_mint_link)'$q$ INTO v_bad;
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION 'KAN-859 pre: cron job(s) reference a retired RPC: %', v_bad;
    END IF;
  END IF;
END
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. The two DROPs. Exact signatures; no CASCADE; no IF EXISTS.
-- ---------------------------------------------------------------------------------------------------------
DROP FUNCTION public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone);
DROP FUNCTION public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer);

-- ---------------------------------------------------------------------------------------------------------
-- 2. Post-check: both absent, under any signature.
-- ---------------------------------------------------------------------------------------------------------
DO $post$
BEGIN
  IF to_regprocedure('public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)') IS NOT NULL
     OR to_regprocedure('public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)') IS NOT NULL
     OR EXISTS (SELECT 1 FROM pg_proc WHERE proname IN ('rpc_meetup_invite_user', 'rpc_meetup_mint_link')) THEN
    RAISE EXCEPTION 'KAN-859 post: a retired RPC is still present';
  END IF;
END
$post$;

COMMIT;
