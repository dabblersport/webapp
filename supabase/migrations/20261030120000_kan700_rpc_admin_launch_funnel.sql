-- KAN-700: admin-only launch funnel read over public.analytics_events.
-- Additive: one new function. No new table, rpc_track_event untouched, no data written.
-- Counts only the four launch events (signup, game_created, game_joined, check_in) per UTC day.
-- Returns counts only: never properties, never a user identifier.

CREATE OR REPLACE FUNCTION public.rpc_admin_launch_funnel(p_from date, p_to date)
RETURNS TABLE(day date, event_name text, events bigint, distinct_users bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;

  IF p_from IS NULL OR p_to IS NULL OR p_to < p_from THEN
    RAISE EXCEPTION 'invalid date range' USING ERRCODE = '22023';
  END IF;
  IF (p_to - p_from) + 1 > 92 THEN
    RAISE EXCEPTION 'date range exceeds 92 days' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT (ae.created_at AT TIME ZONE 'UTC')::date AS day,
         ae.event_name,
         count(*)::bigint AS events,
         count(DISTINCT ae.user_id)::bigint AS distinct_users
    FROM public.analytics_events ae
   WHERE ae.event_name IN ('signup', 'game_created', 'game_joined', 'check_in')
     AND ae.created_at >= (p_from::timestamp AT TIME ZONE 'UTC')
     AND ae.created_at <  ((p_to + 1)::timestamp AT TIME ZONE 'UTC')
   GROUP BY 1, 2
   ORDER BY 1, 2;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rpc_admin_launch_funnel(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_admin_launch_funnel(date, date) TO authenticated, service_role;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.rpc_admin_launch_funnel(date,date)', 'EXECUTE') THEN
    RAISE EXCEPTION 'KAN-700: rpc_admin_launch_funnel must not be executable by anon';
  END IF;
END $$;
