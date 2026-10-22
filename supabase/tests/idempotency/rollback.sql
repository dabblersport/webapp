-- KAN-611 rollback. AUTHORED, NOT APPLIED. Rollback is itself an apply and needs Memphis (execute_sql only, never
-- apply_migration). No DROP: the new functions are renamed and revoked, the previous functions are renamed back.
-- Kept on purpose (additive, inert once the functions are back): posts/games/meetups.request_id, the three partial
-- unique indexes, kan611_stamp_request_id() and the two stamping triggers (they only act while the setting
-- thebes.create_request_id is set, which only the new wrappers do). Rows already stamped keep their request_id.
-- Project wtncuzcskpigqpmnxwws only.

BEGIN;

-- create_post
ALTER FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid, uuid) RENAME TO create_post_v3_rolledback;
REVOKE ALL ON FUNCTION public.create_post_v3_rolledback(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid, uuid) FROM PUBLIC, anon, authenticated;
ALTER FUNCTION public.create_post_legacy_v2(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) RENAME TO create_post;
REVOKE ALL ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_post(text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[], uuid, text, double precision, double precision, uuid) TO authenticated, service_role;

-- rpc_create_game
ALTER FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) RENAME TO rpc_create_game_v3_rolledback;
REVOKE ALL ON FUNCTION public.rpc_create_game_v3_rolledback(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid) FROM PUBLIC, anon, authenticated;
ALTER FUNCTION public.rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) RENAME TO rpc_create_game;
REVOKE ALL ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) TO authenticated, service_role;

-- rpc_create_meetup
ALTER FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) RENAME TO rpc_create_meetup_v3_rolledback;
REVOKE ALL ON FUNCTION public.rpc_create_meetup_v3_rolledback(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) FROM PUBLIC, anon, authenticated;
ALTER FUNCTION public.rpc_create_meetup_legacy_v2(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) RENAME TO rpc_create_meetup;
REVOKE ALL ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) TO authenticated, service_role;

COMMIT;
