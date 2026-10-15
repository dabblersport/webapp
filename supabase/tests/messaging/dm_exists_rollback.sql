-- KAN-561 rollback for 20261015120000_kan561_msg_dm_exists.sql.   AUTHORED, NOT RUN. Nothing is dropped.
-- Removes the grant so no caller can use the function; the Worker then fails open (the hourly new-DM limiter does not
-- charge) and the database's daily cap of 20 still binds. Re-applying the migration restores the grant.
BEGIN;
REVOKE ALL ON FUNCTION public.msg_dm_exists(uuid) FROM PUBLIC, anon, authenticated;
COMMIT;
