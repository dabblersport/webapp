-- KAN-911 live check for supabase/migrations/20261111122100_kan714_w_rpc_create_game.sql. Read-only; run as postgres.
--   T0 the live body is the recorded pre-image (md5(prosrc) 1b3aa6f2b8033bdf64c5bc856d6c7f43)
--   T1 functiondef md5 58605023253923f46847ad106c724df3 (the migration is a byte-exact no-op)
--   T2 the body reads none of the 22 KAN-866 columns from public.games (games referenced only as allowed)
--   T3 ACL / attributes unchanged
-- Rollback proof: BEGIN; <migration>; <this file>; ROLLBACK -- all ok with the same md5s.
SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label, E'\n' ORDER BY n) AS tap FROM (
  SELECT 0 n, md5(p.prosrc) = '1b3aa6f2b8033bdf64c5bc856d6c7f43' ok, 'body = recorded pre-image' label FROM pg_proc p WHERE p.oid = 'public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)'::regprocedure
  UNION ALL SELECT 1, md5(pg_get_functiondef(p.oid)) = '58605023253923f46847ad106c724df3', 'functiondef unchanged' FROM pg_proc p WHERE p.oid = 'public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)'::regprocedure
  UNION ALL SELECT 2, NOT (p.prosrc ~* '\mpublic\.games\M'), 'no read of public.games' FROM pg_proc p WHERE p.oid = 'public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)'::regprocedure
  UNION ALL SELECT 3, p.proacl::text = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' AND p.prosecdef AND p.proowner = 'postgres'::regrole
     AND p.proconfig = '{"search_path=public, pg_temp"}', 'ACL / attributes unchanged' FROM pg_proc p WHERE p.oid = 'public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)'::regprocedure
) t;
