-- KAN-710 rollback (E2). AUTHORED, NOT APPLIED. Needs DROP authority (Memphis). The migration is
-- purely additive, so this removes only what 20261101140000_kan710_events_parent_schema.sql created.
-- Refuses to run once events/event_id hold data (KAN-711+ applied).
begin;
do $$ begin
  if exists (select 1 from public.events)
     or exists (select 1 from public.games where event_id is not null)
     or exists (select 1 from public.meetups where event_id is not null) then
    raise exception 'KAN-710 rollback refused: events/event_id already populated (KAN-711+ applied)';
  end if;
end $$;
drop trigger if exists trg_games_series_occurrence_check on public.games;
drop trigger if exists trg_games_event_link_check on public.games;
drop trigger if exists trg_meetups_event_link_check on public.meetups;
alter table public.games   drop column if exists event_id;   -- drops its unique + FK
alter table public.meetups drop column if exists event_id;
drop table if exists public.events;                           -- drops its triggers and indexes
drop function if exists public.events_check_series_occurrence();
drop function if exists public.events_check_parent_children();
drop function if exists public.events_check_subtype_link();
drop function if exists public.events_guard_type_immutable();
drop function if exists public.events_set_search_tsv();
commit;
-- Then re-run KAN-709/09 P-11: games / meetups row counts and the 20 inbound FKs unchanged.
