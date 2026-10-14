-- KAN-513 (T18): local D1 audit table for the moderator read of a reported message. LOCAL emulator only.
-- One row per read that returned text: who (moderator user id), which report, which message, when.
-- It holds ids and a timestamp and NEVER the message text. Nothing here is deleted; no DROP anywhere.

CREATE TABLE IF NOT EXISTS moderator_reads (
  id           TEXT PRIMARY KEY,
  moderator_id TEXT NOT NULL,
  report_id    TEXT NOT NULL,
  message_id   TEXT NOT NULL,
  read_at      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS moderator_reads_by_report ON moderator_reads (report_id, read_at);
