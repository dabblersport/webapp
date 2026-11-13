-- KAN-689: rpc_get_activity_feed returned 400 (42702 "column reference
-- "time_bucket" is ambiguous"). The function RETURNS TABLE(..., time_bucket,
-- scheduled_for, happened_at, priority, ...), so those names are PL/pgSQL
-- variables, and the final ORDER BY used them unqualified against `filtered`.
-- Fix: alias `filtered` and qualify every ORDER BY column. Signature, return
-- shape and logic are unchanged. Additive: CREATE OR REPLACE only.
CREATE OR REPLACE FUNCTION public.rpc_get_activity_feed(_period text DEFAULT 'all'::text, _limit integer DEFAULT 50, _cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(id uuid, subject_type text, subject_id uuid, verb text, status text, time_bucket text, happened_at timestamp with time zone, scheduled_for timestamp with time zone, priority integer, payload jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  WITH me AS (
    SELECT auth.uid() AS user_id
  ),
  game_created AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'created'::text                                               AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN g.end_at < NOW()                              THEN 'past'
        WHEN g.start_at <= NOW() AND g.end_at >= NOW()    THEN 'present'
        WHEN g.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      g.created_at                                                  AS happened_at,
      g.start_at                                                    AS scheduled_for,
      90                                                            AS priority,
      jsonb_build_object('role', 'host')                            AS payload
    FROM public.games g
    JOIN me ON g.creator_user_id = me.user_id
    WHERE g.is_cancelled = false
  ),
  game_joined AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'joined'::text                                                AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN g.end_at < NOW()                              THEN 'past'
        WHEN g.start_at <= NOW() AND g.end_at >= NOW()    THEN 'present'
        WHEN g.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      gr.joined_at                                                  AS happened_at,
      g.start_at                                                    AS scheduled_for,
      80                                                            AS priority,
      jsonb_build_object('role', 'player')                          AS payload
    FROM public.game_roster gr
    JOIN public.games g ON g.id = gr.game_id
    JOIN me ON gr.user_id = me.user_id
    WHERE gr.status = 'active'
      AND g.is_cancelled = false
      AND g.creator_user_id <> me.user_id
  ),
  game_events AS (
    SELECT * FROM game_created
    UNION ALL
    SELECT * FROM game_joined
  ),
  filtered AS (
    SELECT * FROM game_events e
    WHERE (_period = 'all' OR e.time_bucket = _period)
      AND (_cursor IS NULL OR e.happened_at < _cursor)
  )
  SELECT f.* FROM filtered f
  ORDER BY
    CASE f.time_bucket WHEN 'upcoming' THEN 1 WHEN 'present' THEN 2 WHEN 'past' THEN 3 END,
    f.scheduled_for ASC,
    f.happened_at DESC,
    f.priority DESC
  LIMIT _limit;
END;
$function$;
