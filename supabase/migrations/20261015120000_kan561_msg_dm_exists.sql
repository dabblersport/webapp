-- KAN-561 (Messaging DMs W2): public.msg_dm_exists(p_other_user) -> boolean.   AUTHORED, NOT APPLIED (operations applies).
-- Needs KAN-560 (msg_dm_pairs). True when the caller (auth.uid()) and p_other_user already have a DM pair, including an
-- EMPTY one the other user started and one older than any list cap. The Worker uses it so re-opening an existing pair is
-- never charged to the hourly new-DM limit. Reads one UNIQUE-indexed row; returns a boolean only (no ids, no content).
-- Rollback: supabase/tests/messaging/dm_exists_rollback.sql (revokes EXECUTE; nothing is dropped; the Worker then fails open).
BEGIN;

CREATE OR REPLACE FUNCTION public.msg_dm_exists(p_other_user uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_other_user IS NULL OR p_other_user = v_uid THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  RETURN EXISTS (SELECT 1 FROM public.msg_dm_pairs d
                  WHERE d.user_low = least(v_uid, p_other_user) AND d.user_high = greatest(v_uid, p_other_user));
END;
$$;

REVOKE ALL ON FUNCTION public.msg_dm_exists(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_dm_exists(uuid) TO authenticated;

COMMIT;
