-- KAN-718 (Epic KAN-708, phase 2): admin_cleanup_user_data deletes the events parent itself.
-- Authored from the live pg_get_functiondef (2026-11-13). Signature, return shape, SECURITY DEFINER,
-- search_path, owner and ACL unchanged (CREATE OR REPLACE keeps owner and ACL).
-- The games DELETE becomes a DELETE of the game's events parents; games_event_id_fkey is ON DELETE
-- CASCADE, so each games row goes with its parent. Before, trg_zz_kan712_games_after_delete removed the
-- parent; without it the later profiles DELETE would fail on the events creator_profile_id FK.
-- The EXISTS keeps the count to parents that have a games row (1:1), so ROW_COUNT still counts games
-- rows. GET DIAGNOSTICS placement is unchanged: in a dry run it still reads the ROW_COUNT of the
-- profile lookup, as before.

CREATE OR REPLACE FUNCTION public.admin_cleanup_user_data(p_user_id uuid, p_dry_run boolean DEFAULT true)
 RETURNS TABLE(affected_table text, affected_column text, rows_affected bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r           record;
  v_profile_id uuid;
  v_sql       text;
  v_count     bigint;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin privileges required';
  END IF;

  PERFORM set_config('app.admin_cleanup', 'on', true);

  SELECT id INTO v_profile_id FROM public.profiles WHERE user_id = p_user_id;

  IF v_profile_id IS NULL THEN
    affected_table := 'profiles'; affected_column := 'user_id'; rows_affected := 0;
    RETURN NEXT; RETURN;
  END IF;

  -- Games. KAN-732 (KAN-714 B13): ownership is a SHARED fact and is read from the game's events
  -- parent. KAN-718: the parent is deleted here and games_event_id_fkey (ON DELETE CASCADE) removes
  -- the games row; the EXISTS keeps ROW_COUNT to parents with a games row (1:1), so it counts games rows.
  IF NOT p_dry_run THEN
    DELETE FROM public.events e
     WHERE e.event_type = 'game'
       AND e.creator_profile_id = v_profile_id
       AND EXISTS (SELECT 1 FROM public.games g WHERE g.event_id = e.id);
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count > 0 THEN
    affected_table := 'games'; affected_column := 'creator_profile_id'; rows_affected := v_count;
    RETURN NEXT;
  END IF;

  -- Posts
  IF NOT p_dry_run THEN
    DELETE FROM public.posts WHERE author_profile_id = v_profile_id;
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count > 0 THEN
    affected_table := 'posts'; affected_column := 'author_profile_id'; rows_affected := v_count;
    RETURN NEXT;
  END IF;

  FOR r IN
    SELECT c.table_schema, c.table_name, c.column_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name
    WHERE c.table_schema = 'public'
      AND c.column_name IN ('user_id', 'profile_id')
      AND t.table_type = 'BASE TABLE'
      AND c.table_name NOT IN ('profiles', 'games', 'posts')
  LOOP
    v_sql := format('SELECT count(*) FROM %I.%I WHERE %I = $1',
      r.table_schema, r.table_name, r.column_name);

    EXECUTE v_sql INTO v_count
      USING CASE WHEN r.column_name = 'user_id' THEN p_user_id ELSE v_profile_id END;

    IF v_count > 0 THEN
      IF NOT p_dry_run THEN
        v_sql := format('DELETE FROM %I.%I WHERE %I = $1',
          r.table_schema, r.table_name, r.column_name);
        EXECUTE v_sql
          USING CASE WHEN r.column_name = 'user_id' THEN p_user_id ELSE v_profile_id END;
      END IF;
      affected_table := r.table_name; affected_column := r.column_name; rows_affected := v_count;
      RETURN NEXT;
    END IF;
  END LOOP;

  IF NOT p_dry_run THEN
    DELETE FROM public.profiles WHERE id = v_profile_id;
  END IF;
  affected_table := 'profiles'; affected_column := 'id'; rows_affected := 1;
  RETURN NEXT;
END;
$function$;
