-- Applied to remote as migration version 20260711011917.
--
-- Security fix: admin_force_delete_auth_user and admin_cleanup_user_data
-- were SECURITY DEFINER functions granted to anon/authenticated with NO
-- admin check, allowing any caller (even unauthenticated, holding only the
-- public anon key) to delete or wipe an arbitrary user's account/data.
-- Adds the same public.is_admin() guard used by every other admin_*/
-- rpc_admin_* function in this schema (e.g. admin_take_action,
-- rpc_admin_freeze_user, admin_wallet_adjust).

CREATE OR REPLACE FUNCTION public.admin_force_delete_auth_user(p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_user_uuid UUID;
  v_deleted_sessions INTEGER := 0;
  v_deleted_identities INTEGER := 0;
  v_deleted_mfa_factors INTEGER := 0;
  v_deleted_refresh_tokens INTEGER := 0;
  v_deleted_user BOOLEAN := FALSE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin privileges required';
  END IF;

  -- Validate input and convert to UUID
  IF p_user_id IS NULL OR p_user_id = '' THEN
    RAISE EXCEPTION 'User ID cannot be null or empty';
  END IF;

  -- Cast to UUID to ensure type safety
  BEGIN
    v_user_uuid := p_user_id::UUID;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid UUID format: %', p_user_id;
  END;

  -- Delete from auth.sessions
  EXECUTE format('DELETE FROM auth.sessions WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_sessions = ROW_COUNT;

  -- Delete from auth.identities
  EXECUTE format('DELETE FROM auth.identities WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_identities = ROW_COUNT;

  -- Delete from auth.mfa_factors
  EXECUTE format('DELETE FROM auth.mfa_factors WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_mfa_factors = ROW_COUNT;

  -- Delete from auth.refresh_tokens
  EXECUTE format('DELETE FROM auth.refresh_tokens WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_refresh_tokens = ROW_COUNT;

  -- Delete from auth.mfa_amr_claims if exists
  BEGIN
    EXECUTE format('DELETE FROM auth.mfa_amr_claims WHERE session_id IN (SELECT id FROM auth.sessions WHERE user_id::text = %L)', v_user_uuid::text);
  EXCEPTION
    WHEN undefined_table THEN NULL; -- Table might not exist
  END;

  -- Delete from auth.mfa_challenges if exists
  BEGIN
    EXECUTE format('DELETE FROM auth.mfa_challenges WHERE factor_id IN (SELECT id FROM auth.mfa_factors WHERE user_id::text = %L)', v_user_uuid::text);
  EXCEPTION
    WHEN undefined_table THEN NULL; -- Table might not exist
  END;

  -- Finally, delete the user from auth.users
  EXECUTE format('DELETE FROM auth.users WHERE id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_user = ROW_COUNT;

  IF v_deleted_user = 0 THEN
    RAISE EXCEPTION 'User not found in auth.users: %', p_user_id;
  END IF;

  -- Return summary
  RETURN jsonb_build_object(
    'success', TRUE,
    'user_id', v_user_uuid,
    'deleted', jsonb_build_object(
      'sessions', v_deleted_sessions,
      'identities', v_deleted_identities,
      'mfa_factors', v_deleted_mfa_factors,
      'refresh_tokens', v_deleted_refresh_tokens,
      'user', TRUE
    )
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error deleting auth user: %', SQLERRM;
END;
$function$;

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

  -- Games
  IF NOT p_dry_run THEN
    DELETE FROM public.games WHERE creator_profile_id = v_profile_id;
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
