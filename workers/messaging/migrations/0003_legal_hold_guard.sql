-- KAN-512 (T17): legal hold enforcement in the LOCAL D1 schema. Applied to the local emulator only.
-- The legal_hold column already exists (0001_messages.sql, default 0). This file makes the flag binding for
-- EVERY code path, not only the Worker's own helpers: a held row cannot be deleted (so it cannot expire), and
-- a hold cannot be cleared once set. A report sets the hold (src/retention.ts).
-- Trigger bodies span lines; the statement separator is a semicolon at the end of a line outside a body.

CREATE TRIGGER IF NOT EXISTS messages_legal_hold_no_delete
BEFORE DELETE ON messages
FOR EACH ROW WHEN OLD.legal_hold = 1
BEGIN
  SELECT RAISE(ABORT, 'legal_hold');
END;

CREATE TRIGGER IF NOT EXISTS messages_legal_hold_no_release
BEFORE UPDATE OF legal_hold ON messages
FOR EACH ROW WHEN OLD.legal_hold = 1 AND NEW.legal_hold <> 1
BEGIN
  SELECT RAISE(ABORT, 'legal_hold');
END;

CREATE INDEX IF NOT EXISTS messages_legal_hold_idx ON messages (legal_hold);
