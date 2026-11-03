-- KAN-731 LOCAL ONLY, READ-ONLY. Per-table data hash (the same expressions as the test pg_temp.datahash, R2) plus
-- the md5 and ACL of the four function bodies. Run before and after the migration's commented ROLLBACK block: the
-- six table hashes must be identical, and the function lines move from the KAN-731 bodies to the pins.
-- Never run against Supabase.
\pset format unaligned
\pset tuples_only on
select 'events        ' || md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.events x
union all select 'games         ' || md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.games x
union all select 'meetups       ' || md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.meetups x
union all select 'meetup_rsvps  ' || md5(coalesce(string_agg(x::text, '|' order by x::text), '')) from public.meetup_rsvps x
union all select 'game_roster   ' || md5(coalesce(string_agg(x::text, '|' order by x::text), '')) from public.game_roster x
union all select 'notifications ' || md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.notifications x;
select 'fn ' || proname || ' md5=' || md5(prosrc) || ' acl=' || coalesce(proacl::text, 'NULL')
  from pg_proc
 where pronamespace = 'public'::regnamespace
   and proname in ('rpc_get_activity_feed', 'trg_meetup_rsvps_notify', 'trg_meetups_cancel_notify', 'active_stream')
 order by proname;
