-- KAN-714 ROLLBACK — one transaction. Restores the 6 views and 5 functions byte-for-byte from
-- public.kan714_preimage (captured by 20261105100000_kan714_events_parent_reads.sql), drops the two KAN-714
-- indexes, and empties the pre-image table (so the migration's re-apply guard passes). It does NOT drop the
-- pre-image table (no DROP TABLE); the table is empty, RLS on, no API grants.
--
-- Proof (KAN714_CONTRACT.md section 6): catalogue fingerprint and data hashes before KAN-714 == after rollback
-- (fingerprint_kan714.sql), and the parity snapshot diff is empty.
--
-- Run as a superuser / BYPASSRLS role:  psql -v ON_ERROR_STOP=1 -f rollback_kan714.sql
BEGIN;
SET LOCAL search_path TO public, extensions;

DO $rb$
DECLARE r record; n int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-714 rollback: role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.kan714_preimage') IS NULL THEN
    RAISE EXCEPTION 'KAN-714 rollback: public.kan714_preimage missing — KAN-714 never applied';
  END IF;
  SELECT count(*) INTO n FROM public.kan714_preimage;
  IF n <> 11 THEN
    RAISE EXCEPTION 'KAN-714 rollback: expected 11 pre-image rows, found % (not applied, or already rolled back)', n;
  END IF;

  -- Functions: pg_get_functiondef() emits CREATE OR REPLACE with every attribute; OR REPLACE keeps owner/ACL.
  FOR r IN SELECT * FROM public.kan714_preimage WHERE kind = 'function' ORDER BY object LOOP
    EXECUTE r.definition;
  END LOOP;

  -- Views: v_meetup_counts first (v_meetup_list reads it; order does not matter for OR REPLACE, kept explicit).
  FOR r IN SELECT * FROM public.kan714_preimage WHERE kind = 'view'
            ORDER BY (object = 'v_meetup_counts') DESC, object LOOP
    EXECUTE format('CREATE OR REPLACE VIEW %s%s AS %s', r.object,
                   CASE WHEN r.reloptions IS NULL THEN ''
                        ELSE ' WITH (' || array_to_string(r.reloptions, ', ') || ')' END,
                   r.definition);
  END LOOP;

  -- Post-checks: definitions and attributes identical to the pre-image.
  FOR r IN SELECT pi.object, pi.definition = pg_get_functiondef(p.oid) AS same_def,
                  pi.acl IS NOT DISTINCT FROM p.proacl::text AND pi.owner = pg_get_userbyid(p.proowner)
                  AND pi.secdef = p.prosecdef AND pi.config IS NOT DISTINCT FROM p.proconfig
                  AND pi.volatility = p.provolatile AS same_attr
             FROM public.kan714_preimage pi JOIN pg_proc p ON p.oid = pi.object::regprocedure
            WHERE pi.kind = 'function' LOOP
    IF NOT (r.same_def AND r.same_attr) THEN
      RAISE EXCEPTION 'KAN-714 rollback: % not restored (def %, attrs %)', r.object, r.same_def, r.same_attr;
    END IF;
  END LOOP;
  FOR r IN SELECT pi.object, pi.definition = pg_get_viewdef(c.oid, false) AS same_def,
                  pi.acl IS NOT DISTINCT FROM c.relacl::text AND pi.owner = pg_get_userbyid(c.relowner)
                  AND pi.reloptions IS NOT DISTINCT FROM c.reloptions AS same_attr
             FROM public.kan714_preimage pi JOIN pg_class c ON c.oid = pi.object::regclass
            WHERE pi.kind = 'view' LOOP
    IF NOT (r.same_def AND r.same_attr) THEN
      RAISE EXCEPTION 'KAN-714 rollback: % not restored (def %, attrs %)', r.object, r.same_def, r.same_attr;
    END IF;
  END LOOP;
END
$rb$;

DROP INDEX IF EXISTS public.events_kan714_type_start_id_idx;
DROP INDEX IF EXISTS public.events_kan714_sport_type_start_idx;

DELETE FROM public.kan714_preimage;

COMMIT;
