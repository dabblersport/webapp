-- KAN-672: ratings grants hardening (REVOKE only).
-- Source: cto ruling dreq-09242ad8 (security_exception) on KAN-664 probes P2.2 and P3.
-- Only privileges are removed. No row-level-security rule, table, column or data is touched.
--
-- Findings behind the scope:
--  * lib/ has no direct read or write of game_rating_events, venue_rating_events,
--    user_reputation_events or rating_reports, so every client privilege on them goes.
--    rating_reports gets written only inside rpc_report_rating (SECURITY DEFINER), so
--    authenticated keeps no INSERT on it either.
--  * lib/data/repositories/ratings_repository_impl.dart selects from public.ratings, but
--    RatingsRepository has no consumer in lib/ or test/. KAN-664 replaces client reads
--    with rpc_get_user_rating_aggregate. SELECT on ratings goes.
--  * rpc_rate_user keeps EXECUTE for authenticated; anon and PUBLIC lose it.
-- service_role and the table owner are not touched.

BEGIN;

REVOKE ALL ON FUNCTION public.rpc_rate_user(uuid, uuid, uuid, jsonb, text) FROM PUBLIC, anon;

REVOKE ALL ON TABLE
  public.ratings,
  public.game_rating_events,
  public.venue_rating_events,
  public.user_reputation_events,
  public.rating_reports
FROM PUBLIC, anon, authenticated;

COMMIT;
