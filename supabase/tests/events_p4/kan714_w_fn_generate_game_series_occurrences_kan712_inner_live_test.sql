-- KAN-914 live check for supabase/migrations/20261111122200_kan714_w_fn_generate_game_series_occurrences_kan712_inner.sql. Read-only; run as postgres.
-- Re-pinned 2026-11-13 after KAN-718 (supabase/migrations/20261113052438_kan718_writers_series.sql) rewrote this inner to
-- sync events itself. The KAN-914 pins were md5(prosrc) 3ac00133f33a11047aed47caa0865907 and functiondef
-- 7338260d4d3292367eac2e8bdc4365a0; with those, T0/T1 read "not ok" on the KAN-718 body (seen 2026-11-13).
--   T0 the live body is the KAN-718 body (md5(prosrc) 43251ce46a33575705995b0cd1ec5d5a)
--   T1 functiondef md5 2879da6d27ec8bf86c0edcc956ac8bf5
--   T2 the body reads none of the 22 KAN-866 columns from public.games: its only games references are the
--      v_g row variable and the series_id UPDATE ... RETURNING that feeds kan718_game_event_sync
--   T3 ACL / attributes unchanged
SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label, E'\n' ORDER BY n) AS tap FROM (
  SELECT 0 n, md5(p.prosrc) = '43251ce46a33575705995b0cd1ec5d5a' ok, 'body = KAN-718 body' label FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure
  UNION ALL SELECT 1, md5(pg_get_functiondef(p.oid)) = '2879da6d27ec8bf86c0edcc956ac8bf5', 'functiondef = KAN-718 functiondef' FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure
  UNION ALL SELECT 2, (SELECT count(*) FROM regexp_matches(p.prosrc, '\mpublic\.games\M', 'g')) = 2
                  AND p.prosrc ~ 'UPDATE public\.games SET series_id = s\.id WHERE id = v_gid\s+RETURNING \* INTO v_g;'
                  AND p.prosrc ~ 'kan718_game_event_sync'
                  AND p.prosrc !~* 'from\s+public\.games\M', 'no read of public.games; series_id update syncs events' FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure
  UNION ALL SELECT 3, p.proacl::text = '{postgres=X/postgres}' AND p.prosecdef AND p.proowner = 'postgres'::regrole
     AND p.proconfig = '{"search_path=public, pg_temp"}', 'ACL / attributes unchanged' FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure
) t;
