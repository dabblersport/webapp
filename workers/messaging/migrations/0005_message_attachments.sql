-- KAN-581: private image attachments for messages. AUTHORED here; applied to the live D1 by Memphis after review
-- (needs-ops: workers/messaging/migrations/0005_message_attachments.sql). Additive only: CREATE ... IF NOT EXISTS, no DROP,
-- nothing deleted, no change to messages or conversation_seq.
--
-- Attachment RECORDS live in D1 beside the message rows; the image BYTES live in the private R2 bucket under object_key
-- (src/attachments.ts). Nothing here is a URL: a client always asks the Worker for an attachment by id and the Worker
-- re-checks membership on every read.
--   id               stable attachment id handed to the client
--   conversation_id  the conversation it was uploaded to; a message may bind only attachments of its own conversation
--   uploader_id      the verified user id (from msg_authorize), never a client-supplied value; only that user may bind it
--   upload_key       the client's idempotency key for the upload: a retried upload returns the same row, no second object
--   object_key       the R2 key, m/<conversation_id>/<id>
--   mime_type        the type the Worker SNIFFED from the bytes (image/jpeg, image/png or image/webp), not the declared one
--   byte_size        the real byte length
--   width, height    parsed from the image header when possible
--   message_id       NULL until the send binds it; once set it never changes
--   position         0-based order inside the message
--   created_at       ISO time; an unbound row older than a day is an orphan (cleanup is a separate, unapproved job)

CREATE TABLE IF NOT EXISTS message_attachments (
  id              TEXT    PRIMARY KEY,
  conversation_id TEXT    NOT NULL,
  uploader_id     TEXT    NOT NULL,
  upload_key      TEXT    NOT NULL,
  object_key      TEXT    NOT NULL,
  mime_type       TEXT    NOT NULL CHECK (mime_type IN ('image/jpeg', 'image/png', 'image/webp')),
  byte_size       INTEGER NOT NULL CHECK (byte_size >= 1),
  width           INTEGER CHECK (width IS NULL OR width >= 1),
  height          INTEGER CHECK (height IS NULL OR height >= 1),
  message_id      TEXT,
  position        INTEGER CHECK (position IS NULL OR position >= 0),
  created_at      TEXT    NOT NULL,
  UNIQUE (conversation_id, uploader_id, upload_key)
);

CREATE INDEX IF NOT EXISTS idx_message_attachments_message ON message_attachments (message_id);
