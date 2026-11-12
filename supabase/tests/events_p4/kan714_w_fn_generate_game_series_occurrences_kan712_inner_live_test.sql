-- KAN-914 live check for supabase/migrations/20261111122200_kan714_w_fn_generate_game_series_occurrences_kan712_inner.sql. Read-only; run as postgres.
--   T0 the live body is the recorded pre-image (md5(prosrc) 3ac00133f33a11047aed47caa0865907)
--   T1 functiondef md5 7338260d4d3292367eac2e8bdc4365a0 (the migration is a byte-exact no-op)
--   T2 the body reads none of the 22 KAN-866 columns from public.games (games referenced only as allowed)
--   T3 ACL / attributes unchanged
-- Rollback proof: BEGIN; <migration>; <this file>; ROLLBACK -- all ok with the same md5s.
SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label, E'\n' ORDER BY n) AS tap FROM (
  SELECT 0 n, md5(p.prosrc) = '3ac00133f33a11047aed47caa0865907' ok, 'body = recorded pre-image' label FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure
  UNION ALL SELECT 1, md5(pg_get_functiondef(p.oid)) = '7338260d4d3292367eac2e8bdc4365a0', 'functiondef unchanged' FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure
  UNION ALL SELECT 2, (SELECT count(*) FROM regexp_matches(p.prosrc, '\mpublic\.games\M', 'g')) = 1 AND p.prosrc ~ 'UPDATE public\.games SET series_id = s\.id WHERE id = v_gid;', 'no read of public.games' FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure
  UNION ALL SELECT 3, p.proacl::text = '{postgres=X/postgres}' AND p.prosecdef AND p.proowner = 'postgres'::regrole
     AND p.proconfig = '{"search_path=public, pg_temp"}', 'ACL / attributes unchanged' FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure
) t;
