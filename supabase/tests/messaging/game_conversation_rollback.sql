-- KAN-563 rollback for 20261017120000_kan563_msg_game_conversation.sql.   AUTHORED, NOT RUN. Nothing is dropped.
-- Removes the grant so no caller can use the function; GET /v1/games/{gameId}/conversation then answers 401 (PostgREST
-- refuses the call with 401/403, which the Worker treats as a rejected token). Conversation rows it created stay (identifiers only). Re-applying the migration restores the grant.
BEGIN;
REVOKE ALL ON FUNCTION public.msg_game_conversation(uuid, text) FROM PUBLIC, anon, authenticated;
COMMIT;
