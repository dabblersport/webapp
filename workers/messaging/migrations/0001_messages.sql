-- KAN-506 (T10): local D1 schema for game-chat messages. Applied to the LOCAL emulator only.
-- Message text lives in D1, never in Supabase. Nothing here is deleted (D5: read-only, nothing deleted).
-- Each statement is terminated by a semicolon on its own trailing position; no DROP anywhere.

CREATE TABLE IF NOT EXISTS messages (
  id              TEXT    PRIMARY KEY,
  conversation_id TEXT    NOT NULL,
  seq             INTEGER NOT NULL CHECK (seq >= 1),
  sender_id       TEXT    NOT NULL,
  body            TEXT    NOT NULL,
  created_at      TEXT    NOT NULL,
  client_key      TEXT    NOT NULL,
  legal_hold      INTEGER NOT NULL DEFAULT 0 CHECK (legal_hold IN (0, 1)),
  UNIQUE (conversation_id, seq),
  UNIQUE (conversation_id, sender_id, client_key)
);

-- Per-conversation counter. last_seq is the seq most recently assigned in that conversation.
-- It is advanced in the SAME atomic D1 batch that inserts the message (see src/db.ts).
CREATE TABLE IF NOT EXISTS conversation_seq (
  conversation_id TEXT    PRIMARY KEY,
  last_seq        INTEGER NOT NULL CHECK (last_seq >= 0)
);
