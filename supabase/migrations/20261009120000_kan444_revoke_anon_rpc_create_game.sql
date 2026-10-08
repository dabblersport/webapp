-- KAN-444: anonymous visitors must not create games (cpo ruling; cto ruling).
-- Privilege-only and reversible (D-042 class A). Applied live 2026-10-09.
-- Repeated here so a replay of 20261008140000_game_price_meetup_setting.sql
-- (line 278 grants EXECUTE to anon) ends without the anon grant.
REVOKE EXECUTE ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) FROM anon, PUBLIC;
