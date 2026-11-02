-- KAN-714 catalogue fingerprint + data hashes. LOCAL THROWAWAY POSTGRES ONLY. Read-only.
-- Run before KAN-714, after KAN-714 and after rollback_kan714.sql. before == after-rollback must hold line for line.
-- public.kan714_preimage is excluded from the catalogue fingerprint (the rollback empties it but does not drop it:
-- no DROP TABLE); its own line reports its row count, which must be 0 or absent after rollback.
\set ON_ERROR_STOP 1



SELECT set_config('search_path', 'public, extensions', false) IS NULL AS _sp \gset

-- functions in public: signature, body, attributes, ACL, owner
SELECT 'FN|' || md5(string_agg(p.oid::regprocedure::text || '|' || md5(pg_get_functiondef(p.oid)) || '|' ||
       coalesce(p.proacl::text, '') || '|' || pg_get_userbyid(p.proowner), E'\n' ORDER BY p.oid::regprocedure::text)) ||
       '|n=' || count(*)
  FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind IN ('f', 'p');

-- views in public: definition, reloptions, ACL, owner, column signature
SELECT 'VW|' || md5(string_agg(c.relname || '|' || md5(pg_get_viewdef(c.oid, false)) || '|' ||
       coalesce(array_to_string(c.reloptions, ','), '') || '|' || coalesce(c.relacl::text, '') || '|' ||
       pg_get_userbyid(c.relowner), E'\n' ORDER BY c.relname)) || '|n=' || count(*)
  FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('v', 'm');

-- tables, columns, indexes, constraints, triggers, policies in public (excluding the KAN-714 pre-image table)
SELECT 'REL|' || md5(string_agg(c.relname || ':' || c.relkind::text || ':' || coalesce(c.relacl::text, '') || ':' ||
       c.relrowsecurity::text || c.relforcerowsecurity::text, ',' ORDER BY c.relname)) || '|n=' || count(*)
  FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p', 'i', 'S')
   AND c.relname NOT LIKE 'kan714_preimage%';
SELECT 'COL|' || md5(string_agg(c.relname || '.' || a.attname || ':' || format_type(a.atttypid, a.atttypmod) || ':' ||
       a.attnotnull::text, ',' ORDER BY c.relname, a.attnum)) || '|n=' || count(*)
  FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
 WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p', 'v') AND a.attnum > 0 AND NOT a.attisdropped
   AND c.relname <> 'kan714_preimage';
SELECT 'IDX|' || md5(string_agg(pg_get_indexdef(i.indexrelid), E'\n' ORDER BY pg_get_indexdef(i.indexrelid))) || '|n=' || count(*)
  FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid
 WHERE c.relnamespace = 'public'::regnamespace AND c.relname <> 'kan714_preimage';
SELECT 'CON|' || md5(string_agg(conrelid::regclass::text || ':' || conname || ':' || pg_get_constraintdef(oid), E'\n'
       ORDER BY conrelid::regclass::text, conname)) || '|n=' || count(*)
  FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND conrelid <> coalesce(to_regclass('public.kan714_preimage'), 0);
SELECT 'TRG|' || md5(string_agg(tgrelid::regclass::text || ':' || tgname || ':' || tgenabled::text || ':' ||
       md5(pg_get_triggerdef(oid)), E'\n' ORDER BY tgrelid::regclass::text, tgname)) || '|n=' || count(*)
  FROM pg_trigger WHERE NOT tgisinternal;
SELECT 'POL|' || md5(coalesce(string_agg(polrelid::regclass::text || ':' || polname || ':' ||
       coalesce(pg_get_expr(polqual, polrelid), '') || ':' || coalesce(pg_get_expr(polwithcheck, polrelid), ''),
       E'\n' ORDER BY polrelid::regclass::text, polname), '')) || '|n=' || count(*)
  FROM pg_policy;

-- data hashes (full row text, ordered by primary key)
SELECT 'DATA|events|'  || md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), '')) || '|n=' || count(*) FROM public.events t;
SELECT 'DATA|games|'   || md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), '')) || '|n=' || count(*) FROM public.games t;
SELECT 'DATA|meetups|' || md5(coalesce(string_agg(t::text, E'\n' ORDER BY t.id), '')) || '|n=' || count(*) FROM public.meetups t;
SELECT 'DATA|game_roster|'  || md5(coalesce(string_agg(t::text, E'\n' ORDER BY t::text), '')) || '|n=' || count(*) FROM public.game_roster t;
SELECT 'DATA|meetup_rsvps|' || md5(coalesce(string_agg(t::text, E'\n' ORDER BY t::text), '')) || '|n=' || count(*) FROM public.meetup_rsvps t;

SELECT 'PRE|kan714_preimage|' || CASE WHEN to_regclass('public.kan714_preimage') IS NULL THEN 'empty'
       WHEN (xpath('/row/c/text()', query_to_xml('SELECT count(*) AS c FROM public.kan714_preimage', false, true, '')))[1]::text = '0'
       THEN 'empty' ELSE 'ROWS-PRESENT' END;
