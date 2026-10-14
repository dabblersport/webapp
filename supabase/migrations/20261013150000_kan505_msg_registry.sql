-- KAN-505 (Messaging T8) 1/4: game-chat conversation and membership registry.
-- AUTHORED, NOT APPLIED. Team Habu. Project wtncuzcskpigqpmnxwws, non-prod branch first.
--
-- The registry holds identifiers only. There is NO message text, body, preview or
-- attachment column anywhere in it: message content lives outside Supabase (D21).
--
-- Membership truth is public.game_roster, read at call time by public.msg_authorize.
-- msg_conversation_members only records what the roster cannot: left_at_seq, the last
-- sequence number a voluntarily-leaving member may still read (D7). It is written by
-- service_role (the Worker), never by the app.
--
-- Nothing here is ever deleted: foreign keys are plain (no cascade).
-- RLS is enabled with NO policy, so anon and authenticated read and write nothing;
-- only service_role (which bypasses RLS) and SECURITY DEFINER functions reach it.

CREATE TABLE IF NOT EXISTS public.msg_conversations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind       text NOT NULL DEFAULT 'game' CONSTRAINT msg_conversations_kind_check CHECK (kind = 'game'),
  game_id    uuid NOT NULL CONSTRAINT msg_conversations_game_id_key UNIQUE
             REFERENCES public.games (id),
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.msg_conversations IS
  'KAN-505: one conversation per game. Identifiers only, no message content. Writability is derived from games.end_at / games.is_cancelled at call time.';

CREATE TABLE IF NOT EXISTS public.msg_conversation_members (
  conversation_id uuid NOT NULL REFERENCES public.msg_conversations (id),
  user_id         uuid NOT NULL,
  roster_id       uuid REFERENCES public.game_roster (id),
  left_at_seq     bigint CONSTRAINT msg_conversation_members_left_at_seq_check CHECK (left_at_seq IS NULL OR left_at_seq >= 0),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

COMMENT ON TABLE public.msg_conversation_members IS
  'KAN-505: per-member registry keyed to game_roster. Holds left_at_seq for voluntary leavers (D7). Roster status is read live from game_roster.';

CREATE INDEX IF NOT EXISTS msg_conversation_members_user_idx
  ON public.msg_conversation_members (user_id);

ALTER TABLE public.msg_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.msg_conversation_members ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.msg_conversations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.msg_conversation_members FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.msg_conversations TO service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.msg_conversation_members TO service_role;
