-- KAN-505 (Messaging T8) 4/4: per-user Realtime topic policy (D18 option b).
-- AUTHORED, NOT APPLIED. Team Habu. Project wtncuzcskpigqpmnxwws, non-prod branch first.
-- Kept in its own file so it can be held back independently of 1/4-3/4.
--
-- A signed-in user may receive on a private channel only when the topic is their own
-- 'user:<uid>'. auth.uid() null makes the comparison null, so access fails closed.
-- Only SELECT (receive) is granted; the Worker broadcasts as service_role.
-- D27 ("Allow public access" off) is NOT part of this ticket: until it is switched off,
-- a non-private join is not governed by this policy (T9 tests that, in non-prod).

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname = 'realtime'
       AND tablename = 'messages'
       AND policyname = 'msg_user_topic_receive'
  ) THEN
    CREATE POLICY msg_user_topic_receive
      ON realtime.messages
      FOR SELECT
      TO authenticated
      USING (realtime.topic() = 'user:' || auth.uid()::text);
  END IF;
END;
$$;
