-- Rollback for KAN-1031. Restores the proacl and bodies captured 2026-11-22 before apply.
-- run_seed_meetup_template, join_open_meetups_for_seeding and trgfn ACL were already service_role-only: nothing to restore.
-- perform_check_in ACL is unchanged by CREATE OR REPLACE.

GRANT EXECUTE ON FUNCTION public.admin_whois_profile(uuid) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reuse_touch(text,jsonb,text,integer,uuid,jsonb) TO PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.run_badge_engine() TO PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.award_user_metric_badge(text,jsonb) TO PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.award_top_host_weekly(text,jsonb) TO PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.award_venue_dim_top(text,jsonb) TO PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_fill_posts_sport_key() TO PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_scrub_posts_body() TO PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_seed_profiles_for_posting() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_seed_profiles_for_games() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_open_games_for_seeding() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_games_needing_players() TO PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fill_game_with_seed_profiles(uuid,uuid,text,integer,uuid[]) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_rewards_apply_event(uuid,uuid,text,text,jsonb) TO authenticated;

ALTER FUNCTION public.trgfn_rewards_from_outbox() SECURITY INVOKER;

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
