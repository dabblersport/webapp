-- KAN-78 (CRITICAL): 55 live production auth.users accounts share a known,
-- hardcoded password planted by the (now-dropped, see KAN-79) create_seed_user
-- RPC. Proven live by crypt() match against the literal during triage -- not
-- reproduced here, since this file is meant to be committed and the literal
-- must never enter git history (see KAN-78 comment thread).
-- 52/55 are @gmail.com addresses built from a persona's display name, which is
-- publicly browsable in-app -- the email is guessable, not secret. A guessed
-- email + this shared password yields a real authenticated JWT with full RLS
-- write access as that persona. None of the 55 have ever signed in
-- (last_sign_in_at IS NULL for all), so nulling the password costs nothing.
-- Accounts are passwordless by design in this project (trg_strip_signup_password
-- already forces this for every NEW insert); this brings the 55 historical rows,
-- written before that trigger existed, into line with that standing position.
--
-- Scoped by the is_seed metadata flag rather than the password hash: every
-- account with raw_user_meta_data->>'is_seed' = 'true' was independently
-- confirmed (live, 2026-08-29) to be exactly the 55 rows carrying the known
-- hash, and none of the 55 have ever signed in, so no seed account has since
-- been given a real credential to protect. The hard count assertion below
-- guards against that assumption going stale: if the live count of
-- is_seed='true' AND encrypted_password IS NOT NULL is not exactly 55 at
-- apply time, the statement aborts instead of nulling an unexpected set.
--
-- Data mutation only -- no schema/privilege change -- kept in its own migration
-- per this project's convention of not mixing DDL/privilege with data changes.
--
-- G-002: authored by backend-owner, NOT applied here. cto applies after
-- measuring preconditions live and posting verification back to KAN-78.

DO $$
DECLARE
  affected_count integer;
BEGIN
  SELECT count(*) INTO affected_count
  FROM auth.users
  WHERE raw_user_meta_data->>'is_seed' = 'true'
    AND encrypted_password IS NOT NULL;

  IF affected_count <> 55 THEN
    RAISE EXCEPTION
      'Expected exactly 55 seed accounts with a non-null password, found %. Aborting -- re-verify live before proceeding.',
      affected_count;
  END IF;

  UPDATE auth.users
  SET encrypted_password = NULL
  WHERE raw_user_meta_data->>'is_seed' = 'true'
    AND encrypted_password IS NOT NULL;
END $$;

-- ============================================================
-- VERIFICATION (run all, all must hold)
-- ============================================================
-- 1. No seed account still carries a password. Expect 0.
--    SELECT count(*) FROM auth.users
--    WHERE raw_user_meta_data->>'is_seed'='true' AND encrypted_password IS NOT NULL;
--
-- 2. Seed accounts are disabled for password login, not deleted -- still 55.
--    SELECT count(*) FROM auth.users WHERE raw_user_meta_data->>'is_seed'='true';
--
-- 3. Non-seed accounts are untouched: still 162 (measured live pre-apply,
--    2026-08-29, by backend-owner -- independently re-derived from cto-10's
--    KAN-78 numbers, not merely trusted).
--    SELECT count(*) FROM auth.users WHERE encrypted_password IS NOT NULL;
--
-- 4. Spot-check: a seed persona can no longer obtain a session via password
--    grant with the known shared password (exercise
--    POST /auth/v1/token?grant_type=password against a known seed email on
--    Canary/staging, expect 400/invalid_grant).
