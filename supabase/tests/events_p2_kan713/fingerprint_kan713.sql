-- KAN-713 CATALOGUE FINGERPRINT + DATA HASHES. Read-only. LOCAL THROWAWAY POSTGRES ONLY.
-- Run BEFORE KAN-713 and AFTER rollback_kan713.sql; `diff` must be empty. The only object the rollback
-- deliberately keeps, public.kan713_preimage (the saved pre-images), is excluded.
--   fn|signature|md5(pg_get_functiondef)|owner|acl        every public function/procedure
--   tg|table|trigger|tgenabled|md5(pg_get_triggerdef)     every user trigger in public
--   pol|table|policy|cmd|permissive|roles|md5(qual)|md5(with_check)
--   rel|table|relrowsecurity|relforcerowsecurity|acl
--   data|table|rows|md5(all rows ordered by id)            events, games, meetups, meetup_attendees, game_roster
\pset format unaligned
\pset tuples_only on
\pset pager off
SELECT 'fn|' || p.oid::regprocedure::text || '|' || md5(pg_get_functiondef(p.oid)) || '|' || p.proowner::regrole::text || '|' ||
       coalesce((SELECT string_agg(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE a.grantee::regrole::text END || ':' || a.privilege_type || ':' || a.is_grantable, ','
                  ORDER BY 1) FROM aclexplode(p.proacl) a), 'default')
  FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind IN ('f', 'p')
UNION ALL
SELECT 'tg|' || c.relname || '|' || t.tgname || '|' || t.tgenabled::text || '|' || md5(pg_get_triggerdef(t.oid))
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
 WHERE c.relnamespace = 'public'::regnamespace AND NOT t.tgisinternal
UNION ALL
SELECT 'pol|' || tablename || '|' || policyname || '|' || cmd || '|' || permissive || '|' || array_to_string(roles, ',') || '|' ||
       coalesce(md5(qual), '-') || '|' || coalesce(md5(with_check), '-')
  FROM pg_policies WHERE schemaname = 'public'
UNION ALL
SELECT 'rel|' || c.relname || '|' || c.relrowsecurity || '|' || c.relforcerowsecurity || '|' ||
       coalesce((SELECT string_agg(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE a.grantee::regrole::text END || ':' || a.privilege_type, ',' ORDER BY 1)
                   FROM aclexplode(c.relacl) a), 'default')
  FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'v', 'p') AND c.relname <> 'kan713_preimage'
ORDER BY 1;
SELECT 'data|events|' || count(*) || '|' || md5(coalesce(string_agg(t::text, '' ORDER BY t.id), '')) FROM public.events t;
SELECT 'data|games|' || count(*) || '|' || md5(coalesce(string_agg(t::text, '' ORDER BY t.id), '')) FROM public.games t;
SELECT 'data|meetups|' || count(*) || '|' || md5(coalesce(string_agg(t::text, '' ORDER BY t.id), '')) FROM public.meetups t;
SELECT 'data|meetup_attendees|' || count(*) || '|' || md5(coalesce(string_agg(t::text, '' ORDER BY t.meetup_id, t.user_id), '')) FROM public.meetup_attendees t;
SELECT 'data|game_roster|' || count(*) || '|' || md5(coalesce(string_agg(t::text, '' ORDER BY t.game_id, t.user_id), '')) FROM public.game_roster t;
