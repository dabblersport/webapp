-- KAN-548: fixed-window rate-limit counters in the LOCAL D1 schema. AUTHORED here; applied to the live D1 by Memphis
-- after review. Additive only: CREATE TABLE IF NOT EXISTS, no DROP, nothing deleted.
--
-- One row per (subject, scope) holding the CURRENT windows only. A new window overwrites the row in the same upsert
-- (src/rate_limit.ts), so there is no stale-row growth and no scheduled prune job. An admitted request is exactly one
-- written row, which is why a send's two limits share one row.
--   subject           the opaque verified user id the Worker already derived (never a client-supplied value)
--   scope             'send' (hour window + per-conversation minute window) or 'report_hour'
--   window_start      start of the hour window, whole epoch seconds
--   count             requests admitted in that hour window
--   sub_window_start  scope 'send' only: start of the current minute window, whole epoch seconds
--   sub_counts        scope 'send' only: JSON object { "<conversation id>": admitted this minute }
-- WITHOUT ROWID: the primary key IS the table, so a counter write is exactly one written row (no separate index row).

CREATE TABLE IF NOT EXISTS rate_limits (
  subject          TEXT    NOT NULL,
  scope            TEXT    NOT NULL,
  window_start     INTEGER NOT NULL CHECK (window_start >= 0),
  count            INTEGER NOT NULL CHECK (count >= 1),
  sub_window_start INTEGER CHECK (sub_window_start IS NULL OR sub_window_start >= 0),
  sub_counts       TEXT,
  PRIMARY KEY (subject, scope)
) WITHOUT ROWID;
