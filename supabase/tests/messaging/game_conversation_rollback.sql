-- KAN-563 rollback for 20261015130000_kan563_msg_game_conversation.sql.   AUTHORED, NOT RUN. Nothing is dropped.
-- Revokes EXECUTE so no caller can use the function; the Worker then answers GET /v1/games/{gameId}/conversation with a
-- 502 (no reason). Rows the function created in msg_conversations are ordinary game conversations and stay.
BEGIN;
REVOKE ALL ON FUNCTION public.msg_game_conversation(uuid, text) FROM PUBLIC, anon, authenticated;
COMMIT;
