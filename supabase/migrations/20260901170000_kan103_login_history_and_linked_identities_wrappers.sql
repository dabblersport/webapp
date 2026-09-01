-- KAN-103 / KAN-52 followup — reconciles the last 2 of 4 remaining
-- flagged-missing DataExportService categories that turn out to be real,
-- exportable data, not schema gaps: `login_history` and
-- `third_party_connections`. Verified live 2026-09-01 (execute_sql against
-- information_schema/pg_proc, project wtncuzcskpigqpmnxwws).
--
-- Neither `public.login_history` nor `public.third_party_connections` ever
-- existed. The data itself does exist, but only inside Supabase's own
-- `auth` schema (auth.audit_log_entries, auth.identities), which is not
-- directly client-readable — PostgREST only exposes `public`/configured
-- schemas, and `anon`/`authenticated` have no grants on `auth.*`. The fix
-- is the same pattern already used by public.can_view_venue_bookings():
-- a SECURITY DEFINER function in `public` that reads the auth-schema table
-- itself (definer runs as the function owner, bypassing the caller's lack
-- of grants) but filters strictly to auth.uid(), so each caller only ever
-- sees their own rows. No table is created; nothing is duplicated out of
-- `auth` into `public`.
--
-- `performance_metrics`/`user_game_statistics` (the other 2 of the 4) are
-- NOT a schema gap at all — `public.sport_profiles` already carries real
-- per-sport performance columns (matches_played, xp_*, form_score,
-- attendance/cancellation/punctuality/teamwork/reliability scores,
-- performance_highlights, performance_by_venue) and
-- `public.user_reputation_aggregate` carries the cross-sport reputation
-- aggregate. That reconciliation is Dart-only (data_export_service.dart);
-- no migration needed for it.
--
-- NOT YET APPLIED — per G-002 / decision 019, only `cto` may apply this to
-- production. Authored and posted to KAN-103/KAN-52 for handoff.

BEGIN;

-- ---------------------------------------------------------------------------
-- get_my_login_history — wraps auth.audit_log_entries, scoped to the
-- caller's own login events only. Mirrors the login_history export scope
-- the service already declared (security monitoring, last 6 months,
-- capped rows) before it pointed at a table that never existed.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_login_history(
  p_since timestamptz DEFAULT (now() - interval '180 days'),
  p_limit integer DEFAULT 1000
)
RETURNS TABLE (
  login_at    timestamptz,
  ip_address  text,
  provider    text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
STABLE
AS $$
  SELECT
    ael.created_at AS login_at,
    NULLIF(ael.ip_address, '') AS ip_address,
    (ael.payload -> 'traits' ->> 'provider') AS provider
  FROM auth.audit_log_entries ael
  WHERE ael.payload ->> 'actor_id' = auth.uid()::text
    AND ael.payload ->> 'action' = 'login'
    AND ael.created_at >= p_since
  ORDER BY ael.created_at DESC
  LIMIT LEAST(GREATEST(p_limit, 0), 1000);
$$;

REVOKE ALL ON FUNCTION public.get_my_login_history(timestamptz, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_login_history(timestamptz, integer) TO authenticated;

-- ---------------------------------------------------------------------------
-- get_my_linked_identities — wraps auth.identities, scoped to the caller's
-- own linked sign-in providers only (e.g. Google Sign-In). Connection
-- metadata only (provider, connected_at, last_sign_in_at) — no OAuth
-- tokens or provider profile payloads are exposed, matching what
-- DataExportService already documented as its third-party export scope.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_linked_identities()
RETURNS TABLE (
  provider        text,
  connected_at    timestamptz,
  last_sign_in_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
STABLE
AS $$
  SELECT
    ai.provider,
    ai.created_at AS connected_at,
    ai.last_sign_in_at
  FROM auth.identities ai
  WHERE ai.user_id = auth.uid()
  ORDER BY ai.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.get_my_linked_identities() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_linked_identities() TO authenticated;

COMMIT;

-- ============================================================================
-- VERIFICATION — run as postgres after apply.
-- ============================================================================
--
-- 1. Both functions exist and are SECURITY DEFINER:
--    SELECT proname, prosecdef FROM pg_proc
--    WHERE proname IN ('get_my_login_history','get_my_linked_identities');
--    -- expect: t, t
--
-- 2. anon has no EXECUTE grant on either:
--    SELECT has_function_privilege('anon','public.get_my_login_history(timestamptz,integer)','EXECUTE'); -- expect: false
--    SELECT has_function_privilege('anon','public.get_my_linked_identities()','EXECUTE'); -- expect: false
--    authenticated DOES:
--    SELECT has_function_privilege('authenticated','public.get_my_login_history(timestamptz,integer)','EXECUTE'); -- expect: true
--    SELECT has_function_privilege('authenticated','public.get_my_linked_identities()','EXECUTE'); -- expect: true
--
-- 3. A user only ever sees their own rows, never another user's:
--    BEGIN;
--      SET LOCAL ROLE authenticated;
--      SELECT set_config('request.jwt.claims', json_build_object('sub','<user_a_id>')::text, true);
--      SELECT * FROM public.get_my_login_history(); -- expect: only rows where auth.audit_log_entries.payload->>'actor_id' = '<user_a_id>'
--      SELECT * FROM public.get_my_linked_identities(); -- expect: only rows where auth.identities.user_id = '<user_a_id>'
--    ROLLBACK;
--
-- 4. Sanity check against known data (already observed live, 2026-09-01):
--    auth.audit_log_entries has a payload with action='login',
--    actor_id='ec959ff7-46ef-4bf2-aab4-3515b81f5846', traits->>'provider'='google'
--    for that user — get_my_login_history() run as that user should surface
--    it as one row with provider='google'.
