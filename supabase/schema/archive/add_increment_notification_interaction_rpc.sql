-- Atomic interaction-count increment for notifications.
--
-- The Flutter repo previously did a read-then-write (`select interaction_count`
-- then `update ... interaction_count = current + 1`) because PostgREST cannot
-- express `column = column + 1`. Two concurrent taps on the same notification
-- both read the same value and the count is under-counted. This RPC performs
-- the increment in a single statement.
--
-- SECURITY INVOKER (the default) so the existing RLS UPDATE policy
-- `n_self_update` (auth.uid() = to_user_id) applies; the WHERE clause repeats
-- the owner check as defense in depth. A user can only touch their own rows.

CREATE OR REPLACE FUNCTION public.increment_notification_interaction(p_id uuid)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
  UPDATE public.notifications
     SET clicked_at = now(),
         interaction_count = COALESCE(interaction_count, 0) + 1
   WHERE id = p_id
     AND to_user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.increment_notification_interaction(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_notification_interaction(uuid) TO authenticated;

-- Drop the redundant duplicate SELECT policy on notifications. `n_self_read`
-- and "Users can read own notifications" are byte-identical
-- (auth.uid() = to_user_id); keep the canonical one.
DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
