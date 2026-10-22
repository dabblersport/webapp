-- KAN-611 rollback. AUTHORED, NOT APPLIED. Rollback is itself an apply and needs Memphis (execute_sql only, never
-- apply_migration). Project wtncuzcskpigqpmnxwws only.
--
-- No DROP of any object. For each of create_post / rpc_create_game / rpc_create_meetup:
--   1. the new function is renamed <fn>_v3_rolledback and revoked from PUBLIC, anon, authenticated;
--   2. <fn>_legacy_v2 is renamed back to <fn>;
--   3. the grants the legacy function had before KAN-611 are restored.
-- Left in place on purpose (additive, inert once the functions are back): posts/games/meetups.request_id, the three
-- partial unique indexes (posts_author_user_request_id_key, games_creator_user_request_id_key,
-- meetups_creator_user_request_id_key), kan611_stamp_request_id() and its two triggers (they act only while
-- thebes.create_request_id is set, which only the rolled-back wrappers did). Rows already stamped keep their request_id.
--
-- Grants restored = the ones recorded in supabase/migrations: authenticated + service_role for all three.
-- rpc_create_game was ALSO recorded as granted to anon (20261008140000). If Memphis's pre-apply live ACL capture
-- (README.md) showed anon on rpc_create_game, uncomment the marked line to restore it exactly; otherwise leave it.

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
-- ONLY if the pre-apply live ACL showed anon:
-- GRANT EXECUTE ON FUNCTION public.rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric) TO anon;

-- rpc_create_meetup
ALTER FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) RENAME TO rpc_create_meetup_v3_rolledback;
REVOKE ALL ON FUNCTION public.rpc_create_meetup_v3_rolledback(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean, uuid) FROM PUBLIC, anon, authenticated;
ALTER FUNCTION public.rpc_create_meetup_legacy_v2(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) RENAME TO rpc_create_meetup;
REVOKE ALL ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_meetup(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb, boolean) TO authenticated, service_role;

COMMIT;
