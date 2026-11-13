-- KAN-724 LOCAL ONLY, READ-ONLY. Per-table data hash (the same expression as the test's pg_temp.datahash, R2)
-- plus the state of the function and index. Run before and after the migration's commented ROLLBACK block;
-- the three table hashes must be identical. Never run against Supabase.
\pset format unaligned
\pset tuples_only on
select 'events  ' || md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.events x
union all select 'games   ' || md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.games x
union all select 'meetups ' || md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.meetups x;
select 'fn md5=' || md5(prosrc) || ' index_present=' || (to_regclass('public.events_game_public_search_tsv_idx') is not null)
       || ' acl=' || proacl::text
  from pg_proc where oid = 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'::regprocedure;
