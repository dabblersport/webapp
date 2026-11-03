-- KAN-791 local stack, step 3 (after GoTrue migrations and the Events chain). LOCAL THROWAWAY PG16 ONLY.
\set ON_ERROR_STOP 1

-- auth.uid() as Supabase defines it. The KAN-711 harness stub reads only request.jwt.claim.sub;
-- PostgREST 12+ sets only request.jwt.claims (JSON). This body reads both, so the chain's own
-- probes (which set claim.sub) and real PostgREST requests (which set claims) both resolve.
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
CREATE OR REPLACE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid(), auth.role() TO anon, authenticated, service_role;

-- Stack-only probe surface, kept OUT of public so catalogue probes over public (B15, D01) see nothing new.
-- Reached through PostgREST with the header  Content-Profile: local_stack  /  Accept-Profile: local_stack.
CREATE SCHEMA IF NOT EXISTS local_stack;
GRANT USAGE ON SCHEMA local_stack TO anon, authenticated, service_role;
CREATE OR REPLACE FUNCTION local_stack.whoami() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object('uid', auth.uid(), 'role', auth.role(), 'current_user', current_user)
$$;
REVOKE ALL ON FUNCTION local_stack.whoami() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION local_stack.whoami() TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
