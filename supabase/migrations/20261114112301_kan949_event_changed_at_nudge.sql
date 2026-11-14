-- KAN-949: keep the KAN-755 listing-refresh nudge firing once shared columns live only on events.
-- A retained games/meetups column, bumped by an independent AFTER UPDATE trigger on events.
-- Additive. Writes only games/meetups, never events. No ordering dependency on other events triggers.
-- Applied live to wtncuzcskpigqpmnxwws as version 20261114112301.

alter table public.games   add column if not exists event_changed_at timestamptz;
alter table public.meetups add column if not exists event_changed_at timestamptz;

comment on column public.games.event_changed_at is
  'KAN-949: bumped by trg_kan949_events_nudge_subtype when a listing-relevant events field changes; Realtime nudge only.';
comment on column public.meetups.event_changed_at is
  'KAN-949: bumped by trg_kan949_events_nudge_subtype when a listing-relevant events field changes; Realtime nudge only.';

create or replace function public.kan949_events_nudge_subtype()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if new.event_type = 'game' then
    update public.games   set event_changed_at = clock_timestamp() where event_id = new.id;
  elsif new.event_type = 'meetup' then
    update public.meetups set event_changed_at = clock_timestamp() where event_id = new.id;
  end if;
  return null;
end
$function$;

revoke all on function public.kan949_events_nudge_subtype() from public, anon, authenticated;

drop trigger if exists trg_kan949_events_nudge_subtype on public.events;
create trigger trg_kan949_events_nudge_subtype
after update on public.events
for each row
when (
  (old.title, old.start_at, old.end_at, old.capacity, old.listing_visibility, old.join_policy,
   old.is_cancelled, old.cancelled_at, old.cancelled_reason, old.sport_id, old.area_id,
   old.geo_location_id, old.venue_id, old.min_skill, old.max_skill, old.joining_rule, old.cost_cover)
  is distinct from
  (new.title, new.start_at, new.end_at, new.capacity, new.listing_visibility, new.join_policy,
   new.is_cancelled, new.cancelled_at, new.cancelled_reason, new.sport_id, new.area_id,
   new.geo_location_id, new.venue_id, new.min_skill, new.max_skill, new.joining_rule, new.cost_cover)
)
execute function public.kan949_events_nudge_subtype();

-- Publication column lists: re-add each table with its current list plus event_changed_at.
alter publication supabase_realtime drop table public.games;
alter publication supabase_realtime add table public.games
  (id, title, start_at, end_at, capacity, is_cancelled, cancelled_at, cancelled_reason,
   updated_at, sport_id, geo_location_id, area_id, venue_id, event_changed_at);
alter publication supabase_realtime drop table public.meetups;
alter publication supabase_realtime add table public.meetups (id, vibe_key, event_changed_at);
