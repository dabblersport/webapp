-- KAN-79 (CRITICAL): public.create_seed_user has 4 SECURITY DEFINER overloads,
-- all executable by anon (grant is implicit via PUBLIC -- "=X/postgres" in the
-- ACL, no explicit anon=X entry; REVOKE FROM anon alone would be a no-op).
-- 3 of the 4 overloads write directly into auth.users with
-- email_confirmed_at = now() and a hardcoded password hash (the 55 rows fixed
-- in KAN-78); the 4th (uuid-first) writes profiles/sport_profiles/player for a
-- caller-supplied id. All are reachable unauthenticated via
-- POST /rest/v1/rpc/create_seed_user, letting anyone create arbitrary accounts
-- or squat a real prospective user's email/username ahead of them.
--
-- No caller anywhere: zero references in lib/**, zero in supabase/functions/**,
-- zero other in-database function bodies call it. The seeding work is finished
-- (55 accounts created 2026-04-29..2026-05-04, nothing since). Per T-030, a
-- function with no reason to exist in production is dropped, not gated --
-- CREATE OR REPLACE and grant sweeps have already been shown in this project to
-- silently reopen closed holes (see security_invoker reset pattern), so keeping
-- it revoked-but-present is a loaded weapon; dropping it cannot be re-exposed
-- by accident.
--
-- G-002: authored by backend-owner, NOT applied here. cto applies after
-- measuring preconditions live and posting verification back to KAN-79.

DROP FUNCTION IF EXISTS public.create_seed_user(text, text, text, integer, text, text);
DROP FUNCTION IF EXISTS public.create_seed_user(text, text, text, text, integer, text);
DROP FUNCTION IF EXISTS public.create_seed_user(text, text, text, text, integer, text, text);
DROP FUNCTION IF EXISTS public.create_seed_user(uuid, text, text, text, text, integer, text, text);

-- ============================================================
-- VERIFICATION (run all, all must hold)
-- ============================================================
-- 1. No overload remains. Expect 0.
--    SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--    WHERE n.nspname = 'public' AND p.proname = 'create_seed_user';
--
-- 2. Unauthenticated POST /rest/v1/rpc/create_seed_user now returns 404, not 200
--    (exercise as a real anon REST call on Canary, not inferred from the grant).
--
-- 3. Row counts are unchanged by the drop -- data stays, only the function goes.
--    SELECT count(*) FROM auth.users;    -- expect 242 (measured live pre-apply)
--    SELECT count(*) FROM public.profiles; -- expect 154 (measured live pre-apply)
