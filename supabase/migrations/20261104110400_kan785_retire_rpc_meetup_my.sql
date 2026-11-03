-- KAN-785 — RETIRE public.rpc_meetup_my(). It cannot execute: every call raises 42703 (undefined column).
--
-- AUTHORED FOR REVIEW. NEVER APPLIED BY THIS TICKET. Local proof only: supabase/tests/kan785_rpc_meetup_my.sql,
-- run on a throwaway PG16 by a clean-archive script (git archive of the commit, tracked migrations only).
--
-- WHY RETIRE, NOT FIX. The body (baseline 20260829080500_baseline_schema.sql:13835-13846, never redefined since)
-- reads meetups.owner_user_id, meetups.starts_at and meetups.visibility; none exists (the columns are
-- creator_user_id / start_at / listing_visibility). KAN-725 (B06, 20261104100600) pinned it unchanged and recorded
-- the defect. There is no working behaviour to preserve and no caller:
--   $ grep -rn "rpc_meetup_my" lib supabase test
--   lib/        -> 0 hits (no constant in lib/core/config/supabase_config.dart, no call site)
--   supabase/functions/ -> 0 hits
--   test/       -> 0 hits
--   supabase/migrations/ -> only the baseline CREATE + GRANTs (20260829080500:13835-13846, :36505-36507), the B06
--                 pin/guard (20261104100600) and a comment in an untracked, unrelated 20261105100000 draft
--   supabase/tests/ -> evidence/probe files only (B06 test R1/D4, KAN-714 harness/snapshot, KAN-734 manifest
--                 row 73, KAN-718 D01 scan, KAN-725 harness). No SQL object calls it.
-- Decision recorded in the ticket: no real caller -> retire.
--
-- KAN-712 HANDLING. rpc_meetup_my is NOT KAN-712-wrapped: 20261103110000_kan712_cutover.sql never names it, and
-- B06 asserts no kan712_wrapped_rpcs row and no rpc_meetup_my_kan712_inner. A bare DROP is the legal path only
-- while that holds, so the guard below refuses if either a wrapped_rpcs row or an *_kan712_inner exists (the
-- KAN712_CONTRACT.md unwrap path, kan712_unwrap_rpc, must run first in that case). Nothing to unwrap today.
--
-- DRIFT GUARD. Drops only the exact known-broken definition: md5(pg_get_functiondef) must equal the B06 pin
-- 9459dd31f4dfc534d26b3e37e49326b9. If someone has since fixed it, this refuses rather than dropping a working RPC.
-- No CASCADE: if any object depended on it, the DROP fails loudly instead of taking it along.
--
-- IDEMPOTENT. DROP FUNCTION IF EXISTS with the exact (only) signature, public.rpc_meetup_my(). A re-run is a no-op.
-- There is one overload (no-argument); no other signature exists in any migration.
--
-- EFFECT ON PINNED EVIDENCE (files NOT edited by this ticket): KAN-734's READ_MANIFEST row 73 and
-- kan714_b15_coverage_probe.sql (exp_present / exp_resid lists, 'pinned' row), the B06 test (D1/D2/D4/R1, which pin
-- the function's presence/definition) and the KAN-718 D01 scan list all name rpc_meetup_my(). Run AFTER this
-- migration, those probes will report it absent. They describe the pre-KAN-785 catalogue; refreshing them is
-- follow-up work, not done here.
--
-- ROLLBACK (verbatim pre-image; create with check_function_bodies off, as the baseline dump does, because the body
-- names columns meetups does not have). Restores md5 9459dd31f4dfc534d26b3e37e49326b9 and the ACL
-- {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}:
--
--   SET check_function_bodies = false;
--   CREATE OR REPLACE FUNCTION "public"."rpc_meetup_my"() RETURNS TABLE("id" "uuid", "title" "text", "starts_at" timestamp with time zone, "visibility" "text", "host_actor_id" "uuid", "updated_at" timestamp with time zone)
--       LANGUAGE "sql" STABLE
--       SET "search_path" TO 'public', 'pg_temp'
--       AS $$
--     select m.id, m.title, m.starts_at, m.visibility, m.host_actor_id, m.updated_at
--     from public.meetups m
--     where m.owner_user_id = auth.uid()
--     order by m.starts_at
--   $$;
--
--
--   ALTER FUNCTION "public"."rpc_meetup_my"() OWNER TO "postgres";
--   GRANT ALL ON FUNCTION "public"."rpc_meetup_my"() TO "anon";
--   GRANT ALL ON FUNCTION "public"."rpc_meetup_my"() TO "authenticated";
--   GRANT ALL ON FUNCTION "public"."rpc_meetup_my"() TO "service_role";
--   RESET check_function_bodies;

BEGIN;

DO $$
DECLARE v_md5 text;
BEGIN
  -- KAN-712: refuse if wrapped (unwrap path first).
  IF to_regclass('public.kan712_wrapped_rpcs') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_meetup_my') THEN
      RAISE EXCEPTION 'KAN-785: rpc_meetup_my is KAN-712-wrapped — run kan712_unwrap_rpc first (KAN712_CONTRACT.md), stop';
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace
              AND proname = 'rpc_meetup_my_kan712_inner') THEN
    RAISE EXCEPTION 'KAN-785: rpc_meetup_my_kan712_inner exists — use the KAN-712 unwrap path, stop';
  END IF;

  -- Exactly one overload, and it is the known-broken pre-image.
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_meetup_my') > 1 THEN
    RAISE EXCEPTION 'KAN-785: unexpected extra rpc_meetup_my overload, stop';
  END IF;
  IF to_regprocedure('public.rpc_meetup_my()') IS NOT NULL THEN
    v_md5 := md5(pg_get_functiondef('public.rpc_meetup_my()'::regprocedure));
    IF v_md5 <> '9459dd31f4dfc534d26b3e37e49326b9' THEN
      RAISE EXCEPTION 'KAN-785: rpc_meetup_my() drifted from the broken pre-image (md5 %), refusing to drop', v_md5;
    END IF;
  END IF;
END $$;

DROP FUNCTION IF EXISTS public.rpc_meetup_my();

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_meetup_my') THEN
    RAISE EXCEPTION 'KAN-785: post-condition failed, rpc_meetup_my still present';
  END IF;
END $$;

COMMIT;
