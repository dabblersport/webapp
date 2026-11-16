-- KAN-967 follow-up (PEER review comment 16387, non-blocking defect): a venue with two or more visible ratings came
-- back on more than one page. The page LIMIT and keyset run on the deduped set, but the keyset predicate is applied
-- BEFORE the DISTINCT ON (event_type, entity_id): page 1 shows the venue's newest rating, and the cursor then lets
-- the venue's OLDER rating (event_at < cursor) through on page 2. venue_rating is the only type with several
-- timestamps per (event_type, entity_id).
-- Fix, inside the venue_rating branch only: the source becomes the newest VISIBLE rating per venue
-- (DISTINCT ON venue_id ORDER BY created_at DESC, id DESC), chosen AFTER the rater visibility and block filters, so a
-- hidden or blocked newest rating never masks an older visible one. The venue filters (active, owner not blocked)
-- depend only on the venue, so they are unaffected by the order. Every other branch, the 6 parameters, the 28 output
-- columns, the dedupe, ordering and keyset are unchanged.
-- Authored from the live pg_get_functiondef: the body is read from the catalogue (pre-image md5
-- 2412d4ded7c092ce2489a1d838bf5598, guarded), one exactly-once text replacement is made, and the result is executed.
-- The return type is unchanged, so CREATE OR REPLACE keeps owner, SECURITY DEFINER, search_path, comment and ACL;
-- all are asserted afterwards.
-- Applied under G-002 by backend-3.

DO $mig$
DECLARE
  v_def  text;
  v_new  text;
  v_acl  text[];
  c_old  text := E'      FROM public.venue_rating_events vre\n';
  c_new  text := E'      FROM (SELECT DISTINCT ON (vr.venue_id) vr.*   -- KAN-967 fix: newest visible rating per venue\n'
              || E'              FROM public.venue_rating_events vr, prm\n'
              || E'             WHERE prm.viewer IS NOT NULL\n'
              || E'               AND public.is_profile_publicly_visible(vr.rater_profile_id)\n'
              || E'               AND NOT public.is_blocked(prm.viewer, vr.rater_user_id)\n'
              || E'             ORDER BY vr.venue_id, vr.created_at DESC, vr.id DESC) vre\n';
  r record;
BEGIN
  SELECT pg_get_functiondef(p.oid), (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x)
    INTO v_def, v_acl
    FROM pg_proc p WHERE p.oid = 'public.active_stream(text[],text,integer,timestamptz,text,uuid)'::regprocedure;
  IF md5(v_def) IS DISTINCT FROM '2412d4ded7c092ce2489a1d838bf5598' THEN
    RAISE EXCEPTION 'KAN-967 fix pre-image md5 mismatch: %', md5(v_def);
  END IF;
  IF v_acl IS DISTINCT FROM ARRAY['authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres'] THEN
    RAISE EXCEPTION 'KAN-967 fix pre-image ACL mismatch: %', v_acl;
  END IF;
  IF (length(v_def) - length(replace(v_def, c_old, ''))) / length(c_old) <> 1 THEN
    RAISE EXCEPTION 'KAN-967 fix: venue_rating source line not found exactly once';
  END IF;
  v_new := replace(v_def, c_old, c_new);
  EXECUTE v_new;

  SELECT md5(pg_get_functiondef(p.oid)) AS md5, pg_get_userbyid(p.proowner) AS owner, p.prosecdef, p.proconfig,
         p.provolatile, (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x) AS acl,
         obj_description(p.oid, 'pg_proc') AS cmt
    INTO r
    FROM pg_proc p WHERE p.oid = 'public.active_stream(text[],text,integer,timestamptz,text,uuid)'::regprocedure;
  IF r.md5 IS DISTINCT FROM md5(v_new) OR r.owner <> 'postgres' OR NOT r.prosecdef OR r.provolatile <> 's'
     OR r.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     OR r.acl IS DISTINCT FROM ARRAY['authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres']
     OR has_function_privilege('anon', 'public.active_stream(text[],text,integer,timestamptz,text,uuid)', 'EXECUTE')
     OR r.cmt NOT LIKE '%KAN-967%' THEN
    RAISE EXCEPTION 'KAN-967 fix post-image mismatch: md5=% owner=% secdef=% cfg=% acl=%', r.md5, r.owner, r.prosecdef, r.proconfig, r.acl;
  END IF;
END
$mig$;
