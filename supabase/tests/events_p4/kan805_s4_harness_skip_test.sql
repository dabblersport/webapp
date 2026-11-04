-- KAN-819 (KAN-805 follow-up): the KAN-781 postcheck S4 trigger scan must skip harness objects.
-- LOCAL THROWAWAY DATABASE ONLY (name must start k805/k819). Never Supabase. Everything runs in BEGIN ... ROLLBACK.
--
-- Run from the repository root:
--   psql -X -v ON_ERROR_STOP=1 -d k819t -f supabase/tests/events_p4/kan805_s4_harness_skip_test.sql
--
-- It cuts the S4 trigger loop's query out of kan719_z04_postcheck.sql with sed, so it tests the real text, and runs it
-- against a fixture where meetups has lost a column (k805_gone, listed in k781_removed):
--   (a) a trigger whose function is harness_*  and reads NEW.k805_gone -> must be SKIPPED by S4
--   (b) a trigger whose function is not harness and reads NEW.k805_gone -> must be reported by S4 (FAIL)
-- Prints one PASS line per case and exits 0; raises (non-zero exit) if either expectation is wrong.

\set s4sql `sed -n '/^-- S4 triggers/,/^  END LOOP;/p' supabase/tests/events_p4/kan719_z04_postcheck.sql | sed -n '/FOR r IN SELECT DISTINCT t.tgrelid/,/ LOOP$/p' | sed -e '1s/^ *FOR r IN //' -e '$s/ LOOP$//'`

DO $g$ BEGIN
  IF current_database() !~ '^(k805|k819)' OR to_regnamespace('auth') IS NOT NULL OR to_regnamespace('storage') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-819 TEST REFUSED: % is not a k805*/k819* throwaway database', current_database();
  END IF;
END $g$;

BEGIN;
CREATE TABLE IF NOT EXISTS public.games (id int);
CREATE TABLE IF NOT EXISTS public.meetups (id int);
ALTER TABLE public.meetups ADD COLUMN k805_gone int;

CREATE FUNCTION public.harness_k805_reads_gone() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN NEW.k805_gone := coalesce(NEW.k805_gone, 0); RETURN NEW; END $f$;
CREATE FUNCTION public.k805_product_reads_gone() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN IF NEW.k805_gone IS NULL THEN NULL; END IF; RETURN NEW; END $f$;
CREATE TRIGGER k805_trg_harness BEFORE INSERT ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.harness_k805_reads_gone();
CREATE TRIGGER k805_trg_product BEFORE INSERT ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.k805_product_reads_gone();

-- The column is removed; plpgsql bodies are not column-checked, so both triggers stay attached and still name it.
ALTER TABLE public.meetups DROP COLUMN k805_gone;
CREATE TEMP TABLE k781_removed (tbl text, col text);
INSERT INTO k781_removed VALUES ('meetups', 'k805_gone');

-- The postcheck's own S4 trigger query, verbatim.
CREATE TEMP VIEW k805_s4 AS :s4sql ;

DO $t$ DECLARE src text := pg_get_viewdef('k805_s4'::regclass); BEGIN
  IF src !~ 'pg_trigger' OR src !~ 'k781_removed' THEN
    RAISE EXCEPTION 'KAN-819 TEST BROKEN: sed did not extract the S4 trigger query: %', src;
  END IF;
  -- (a) harness trigger must be skipped
  IF EXISTS (SELECT 1 FROM k805_s4 WHERE tgname = 'k805_trg_harness') THEN
    RAISE EXCEPTION 'KAN-819 (a) FAIL: S4 counts trigger k805_trg_harness (function harness_k805_reads_gone) - harness objects are not skipped';
  END IF;
  RAISE NOTICE 'KAN-819 (a) PASS: harness_* trigger function reading NEW.k805_gone is SKIPPED by S4';
  -- (b) product trigger must still be reported
  IF NOT EXISTS (SELECT 1 FROM k805_s4 WHERE tgname = 'k805_trg_product' AND tbl = 'meetups' AND col = 'k805_gone') THEN
    RAISE EXCEPTION 'KAN-819 (b) FAIL: S4 does not report product trigger k805_trg_product reading NEW.k805_gone';
  END IF;
  RAISE NOTICE 'KAN-819 (b) PASS: non-harness trigger function reading NEW.k805_gone gives S4 FAIL';
END $t$;
ROLLBACK;
