-- KAN-644 READ-ONLY catalog capture for Operations: run BEFORE and AFTER applying the migration, diff the two outputs.
-- (The author could not read the live catalog: execute_sql is refused to this team by the ops guard.)
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, md5(pg_get_functiondef(p.oid)) AS def_md5, p.prosecdef, p.proacl::text AS acl
  FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.proname IN
  ('trgfn_player_profile_persona_guard','trgfn_organiser_profile_persona_guard','trgfn_host_profile_persona_guard',
   'trgfn_block_legacy_persona_updates','trgfn_limit_active_profiles','trgfn_validate_persona_compatibility',
   'rpc_onboard_profile','choose_actor','trgfn_player_persona_guard_v2','trgfn_organiser_persona_guard_v2',
   'trgfn_host_persona_guard_v2','trgfn_unified_persona_guard','trgfn_contributor_sports_check') ORDER BY 1,2;
SELECT conrelid::regclass, conname, pg_get_constraintdef(oid) FROM pg_constraint
  WHERE conrelid IN ('public.profiles'::regclass,'public.player'::regclass,'public.organiser'::regclass,'public.host'::regclass,'public.sport_profiles'::regclass) ORDER BY 1,2;
SELECT tgrelid::regclass, tgname, tgenabled, pg_get_triggerdef(oid) FROM pg_trigger WHERE NOT tgisinternal
  AND tgrelid IN ('public.profiles'::regclass,'public.player'::regclass,'public.organiser'::regclass,'public.host'::regclass,'public.sport_profiles'::regclass) ORDER BY 1,2;
SELECT persona_type, count(*) FROM public.profiles GROUP BY 1 ORDER BY 1;                          -- aggregate counts only
SELECT count(*) AS profiles, count(DISTINCT user_id) AS users, count(*) FILTER (WHERE is_active) AS active FROM public.profiles;
SELECT count(*) AS multi_row_accounts FROM (SELECT user_id FROM public.profiles GROUP BY 1 HAVING count(*)>1) t;
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname='public' AND indexname='idx_one_active_profile_per_user';
