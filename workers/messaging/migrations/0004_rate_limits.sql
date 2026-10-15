-- KAN-548: fixed-window rate-limit counters in the LOCAL D1 schema. AUTHORED here; applied to the live D1 by Memphis
-- after review. Additive only: CREATE TABLE IF NOT EXISTS, no DROP, nothing deleted.
--
-- One row per (subject, scope) holding the CURRENT window only. A new window overwrites the row in the same
-- upsert (src/rate_limit.ts), so there is no stale-row growth and no scheduled prune job.
--   subject      the opaque verified user id the Worker already derived (never a client-supplied value)
--   scope        'send_conv_min:<conversation id>', 'send_hour' or 'report_hour'
--   window_start start of the window, whole epoch seconds
--   count        requests admitted in that window
-- WITHOUT ROWID: the primary key IS the table, so a counter write is exactly one written row (no separate index row).

CREATE TABLE IF NOT EXISTS rate_limits (
  subject      TEXT    NOT NULL,
  scope        TEXT    NOT NULL,
  window_start INTEGER NOT NULL CHECK (window_start >= 0),
  count        INTEGER NOT NULL CHECK (count >= 1),
  PRIMARY KEY (subject, scope)
) WITHOUT ROWID;
