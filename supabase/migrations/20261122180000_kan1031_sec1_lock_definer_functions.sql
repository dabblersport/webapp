-- KAN-1031 (SEC-1): lock anon-callable SECURITY DEFINER functions.
-- 7 days of edge_logs (2026-11-15..22) show only service_role/n8n callers of these RPCs.
-- Rollback: supabase/rollbacks/20261122180000_kan1031_sec1_lock_definer_functions_rollback.sql

-- 1. perform_check_in: the app passes its own auth uid; reject anyone else's.
CREATE OR REPLACE FUNCTION public.perform_check_in(p_user_id uuid, p_device_info jsonb DEFAULT NULL::jsonb)
 RETURNS TABLE(total_days_completed integer, streak_count integer, is_completed boolean, is_first_check_in_today boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  rec RECORD;
  new_total INTEGER;
  new_streak INTEGER;
  is_first BOOLEAN;
  today_date DATE := CURRENT_DATE;
BEGIN
  -- KAN-1031: only the caller may check themselves in (service_role exempt).
  IF coalesce(auth.role(), '') <> 'service_role'
     AND (p_user_id IS NULL OR auth.uid() IS NULL OR p_user_id <> auth.uid()) THEN
    RAISE EXCEPTION 'perform_check_in: p_user_id must be the caller' USING ERRCODE = '42501';
  END IF;

  -- Get current status
  SELECT * INTO rec FROM user_check_ins WHERE user_id = p_user_id;

  -- Already checked in today?
  IF rec.last_check_in IS NOT NULL AND DATE(rec.last_check_in) = today_date THEN
    RETURN QUERY SELECT rec.total_days_completed, rec.streak_count, (rec.total_days_completed >= 14), FALSE;
    RETURN;
  END IF;

  is_first := TRUE;

  -- New user
  IF rec.user_id IS NULL THEN
    new_total := 1;
    new_streak := 1;
    INSERT INTO user_check_ins (user_id, total_days_completed, streak_count, last_check_in)
    VALUES (p_user_id, new_total, new_streak, NOW());
  ELSE
    -- Existing user
    IF today_date - DATE(rec.last_check_in) = 1 THEN
      new_streak := rec.streak_count + 1;
    ELSE
      new_streak := 1;
    END IF;
    new_total := rec.total_days_completed + 1;
    UPDATE user_check_ins
    SET total_days_completed = new_total, streak_count = new_streak, last_check_in = NOW()
    WHERE user_id = p_user_id;
  END IF;

  -- Log it with streak_at_time
  INSERT INTO check_in_logs (user_id, check_in_date, device_info, streak_at_time)
  VALUES (p_user_id, today_date, p_device_info, new_streak);

  RETURN QUERY SELECT new_total, new_streak, (new_total >= 14), is_first;
END;
$function$;

-- 2. Rewards trigger function runs as owner so it can call the locked RPC.
ALTER FUNCTION public.trgfn_rewards_from_outbox() SECURITY DEFINER;
ALTER FUNCTION public.trgfn_rewards_from_outbox() SET search_path = public, pg_temp;

-- 3. Revoke from PUBLIC, anon, authenticated; keep service_role.
DO $$
DECLARE f regprocedure;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND (p.proname IN (
      'fill_game_with_seed_profiles','get_seed_profiles_for_games','get_seed_profiles_for_posting',
      'get_open_games_for_seeding','get_games_needing_players','join_open_meetups_for_seeding',
      'run_seed_meetup_template','admin_scrub_posts_body','admin_fill_posts_sport_key',
      'admin_whois_profile','run_badge_engine','reuse_touch','rpc_rewards_apply_event')
      OR p.proname LIKE 'award\_%')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END $$;
