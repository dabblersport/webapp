-- KAN-694 rollback: reverses ONLY 20261030130000_kan694_rpc_series_edit_cancel.sql. Memphis runs it via execute_sql.
-- Drops the three functions this migration created. Leaves KAN-671/KAN-693 objects, game_series rows and all games rows
-- (including cancelled or edited occurrences) intact: data written by the RPCs is not reverted.
BEGIN;
DROP FUNCTION IF EXISTS public.rpc_cancel_game_series(uuid,text);
DROP FUNCTION IF EXISTS public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean);
DROP FUNCTION IF EXISTS public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid);
COMMIT;
