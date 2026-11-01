-- KAN-710 (Epic KAN-708, step E2): public.events parent schema + subtype identity links.
-- AUTHORED, NOT APPLIED. Memphis applies after review. Contract: KAN-709 (00, 01, 03, 04, 09).
--
-- Additive only. No backfill (KAN-711), no DROP, no legacy column/row/RPC/view change, no
-- publication, no activity/attendance/notify wiring. games/meetups keep working untouched:
-- the new event_id columns are nullable and every check below is a no-op while they are NULL.
--
-- Security model: events is reachable by nobody but postgres/service_role. RLS is ENABLED and
-- FORCED with ZERO policies; every grant to PUBLIC/anon/authenticated is revoked. Later steps
-- (KAN-713/E5/E6) add postgres-owned SECURITY DEFINER views/RPCs. Every function here is owned
-- by postgres, SECURITY DEFINER only where it must read events on behalf of a caller that has
-- no access, with search_path = public, pg_temp, and EXECUTE revoked from PUBLIC/anon/authenticated.
-- ASSUMPTION (probe E-02): role postgres has BYPASSRLS, so FORCE RLS does not block the
-- definer functions below.

begin;

-- ---------------------------------------------------------------------------
-- 1. Parent table
-- ---------------------------------------------------------------------------
create table public.events (
  id                  uuid        not null,                -- supplied: equals the legacy games/meetups id
  event_type          text        not null,
  creator_profile_id  uuid        not null,
  creator_user_id     uuid        not null,                -- no FK (matches legacy games/meetups)
  title               text,
  start_at            timestamptz not null,
  end_at              timestamptz,
  capacity            integer,
  listing_visibility  text        not null default 'public',
  join_policy         text        not null default 'open',
  is_cancelled        boolean     not null default false,
  cancelled_at        timestamptz,
  cancelled_reason    text,
  sport_id            uuid,
  area_id             uuid,
  geo_location_id     uuid,
  venue_id            uuid,
  min_skill           smallint,
  max_skill           smallint,
  joining_rule        text        not null default 'free',
  cost_cover          text        not null default 'free',
  request_id          uuid,
  search_tsv          tsvector,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint events_pkey primary key (id),

  constraint events_creator_profile_id_fkey foreign key (creator_profile_id)
    references public.profiles (id) on delete restrict,
  constraint events_sport_id_fkey foreign key (sport_id)
    references public.sports (id) on delete set null,
  constraint events_area_id_fkey foreign key (area_id)
    references public.areas (id) on delete set null,
  constraint events_geo_location_id_fkey foreign key (geo_location_id)
    references public.geo_locations (id),
  constraint events_venue_id_fkey foreign key (venue_id)
    references public.venues (id) on delete set null,

  -- type
  constraint events_event_type_check check (event_type in ('game', 'meetup')),

  -- shared
  constraint events_end_after_start check (end_at is null or end_at > start_at),
  constraint events_joining_rule_check check (joining_rule in ('free', 'members_only', 'paid')),
  constraint events_cost_cover_check check (cost_cover in ('free', 'members_only', 'paid')),
  -- verbatim from games_cost_cover_logic / meetups_cost_cover_logic (identical on both)
  constraint events_cost_cover_logic check (
    (joining_rule = 'free' and cost_cover = 'free')
    or (joining_rule = 'members_only' and cost_cover = 'members_only')
    or (joining_rule = 'paid' and cost_cover in ('paid', 'free'))),

  -- game-only rules (each guarded by event_type, never unioned with meetup sets)
  constraint events_game_end_required check (event_type <> 'game' or end_at is not null),
  constraint events_game_capacity_check check (event_type <> 'game' or (capacity is not null and capacity between 2 and 64)),
  constraint events_game_visibility_check check (event_type <> 'game' or listing_visibility in ('public', 'followers', 'private')),
  constraint events_game_join_policy_check check (event_type <> 'game' or join_policy in ('open', 'request', 'invite', 'link')),
  constraint events_game_sport_required check (event_type <> 'game' or sport_id is not null),
  constraint events_game_area_required check (event_type <> 'game' or area_id is not null),
  constraint events_game_geo_required check (event_type <> 'game' or geo_location_id is not null),
  constraint events_game_skill_check check (event_type <> 'game' or (
    (min_skill is null or min_skill between 1 and 10) and (max_skill is null or max_skill between 1 and 10))),

  -- meetup-only rules
  constraint events_meetup_title_check check (event_type <> 'meetup' or (title is not null and char_length(title) between 3 and 80)),
  constraint events_meetup_capacity_check check (event_type <> 'meetup' or capacity is null or capacity > 0),
  constraint events_meetup_visibility_check check (event_type <> 'meetup' or listing_visibility in ('public', 'circle', 'invite', 'link', 'hidden')),
  constraint events_meetup_join_policy_check check (event_type <> 'meetup' or join_policy in ('open', 'request', 'invite', 'link', 'closed')),
  constraint events_meetup_cancel_null check (event_type <> 'meetup' or (cancelled_at is null and cancelled_reason is null))
);

alter table public.events owner to postgres;

-- ---------------------------------------------------------------------------
-- 2. RLS forced, zero policies, zero client grants
-- ---------------------------------------------------------------------------
alter table public.events enable row level security;
alter table public.events force row level security;
revoke all on table public.events from public;
revoke all on table public.events from anon;
revoke all on table public.events from authenticated;

-- ---------------------------------------------------------------------------
-- 3. Indexes (01 §6)
-- ---------------------------------------------------------------------------
create index events_start_at_idx            on public.events (start_at);
create index events_type_start_at_idx       on public.events (event_type, start_at);
create index events_creator_user_start_idx  on public.events (creator_user_id, start_at desc);
create index events_creator_profile_idx     on public.events (creator_profile_id);
create index events_type_vis_join_idx       on public.events (event_type, listing_visibility, join_policy);
create index events_geo_location_idx        on public.events (geo_location_id);
create index events_area_idx                on public.events (area_id);
create index events_upcoming_idx            on public.events (start_at) where not is_cancelled;
create index events_title_lower_idx         on public.events (lower(public.unaccent_immutable(title)) text_pattern_ops) where title is not null;
create index events_search_tsv_idx          on public.events using gin (search_tsv);
-- Request replay: one parent per (type, creator, request_id).
create unique index events_type_creator_request_id_key
  on public.events (event_type, creator_profile_id, request_id) where request_id is not null;

-- ---------------------------------------------------------------------------
-- 4. Functions (all owned by postgres)
-- ---------------------------------------------------------------------------

-- 4a. search_tsv. Per type, title only: meetup description/location_name live on the meetups
--     subtype, so the parent cannot see them. meetups.search_tsv stays authoritative for meetup
--     full-text until KAN-718 ports it (KNOWN LIMITATION, documented in the handoff).
create function public.events_set_search_tsv() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if new.event_type = 'meetup' then
    new.search_tsv := setweight(to_tsvector('simple', public.unaccent_immutable(coalesce(new.title, ''))), 'A');
  else
    new.search_tsv := to_tsvector('simple', public.unaccent_immutable(coalesce(new.title, '')));
  end if;
  return new;
end $$;
alter function public.events_set_search_tsv() owner to postgres;

-- 4b. event_type is immutable: no game <-> meetup retagging.
create function public.events_guard_type_immutable() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  if new.event_type is distinct from old.event_type then
    raise exception 'events.event_type is immutable (% -> %)', old.event_type, new.event_type
      using errcode = 'check_violation';
  end if;
  if new.id is distinct from old.id then
    raise exception 'events.id is immutable' using errcode = 'check_violation';
  end if;
  return new;
end $$;
alter function public.events_guard_type_immutable() owner to postgres;

-- 4c. Exclusive ownership, subtype side. Deferred to commit so parent + child can be inserted in
--     either order in one transaction. NULL event_id (every legacy row today) is always allowed.
--     SECURITY DEFINER because the invoking role has no access to events.
create function public.events_check_subtype_link() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  want_type text := case tg_table_name when 'games' then 'game' when 'meetups' then 'meetup' end;
  have_type text;
  other_hit boolean;
begin
  if new.event_id is null then
    return null;
  end if;
  if new.event_id is distinct from new.id then
    raise exception '%.event_id must equal the row id (% vs %)', tg_table_name, new.event_id, new.id
      using errcode = 'check_violation';
  end if;
  select event_type into have_type from public.events where id = new.event_id;
  if not found then
    raise exception 'orphan: % % links to missing event %', tg_table_name, new.id, new.event_id
      using errcode = 'foreign_key_violation';
  end if;
  if have_type is distinct from want_type then
    raise exception 'wrong subtype: event % is %, linked from %', new.event_id, have_type, tg_table_name
      using errcode = 'check_violation';
  end if;
  if tg_table_name = 'games' then
    select exists (select 1 from public.meetups where event_id = new.event_id) into other_hit;
  else
    select exists (select 1 from public.games where event_id = new.event_id) into other_hit;
  end if;
  if other_hit then
    raise exception 'event % is already owned by the other subtype', new.event_id
      using errcode = 'unique_violation';
  end if;
  return null;
end $$;
alter function public.events_check_subtype_link() owner to postgres;

-- 4d. Exclusive ownership, parent side: a subtype row linked to this event must be of its type.
--     "Parent has exactly one child" is deliberately NOT enforced here (phase 1: legacy
--     authoritative, parents may briefly precede children). E4 (KAN-712) enables it.
create function public.events_check_parent_children() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.event_type = 'game' and exists (select 1 from public.meetups where event_id = new.id) then
    raise exception 'wrong subtype: game event % has a meetups row', new.id using errcode = 'check_violation';
  end if;
  if new.event_type = 'meetup' and exists (select 1 from public.games where event_id = new.id) then
    raise exception 'wrong subtype: meetup event % has a games row', new.id using errcode = 'check_violation';
  end if;
  return null;
end $$;
alter function public.events_check_parent_children() owner to postgres;

-- 4e. Series occurrence uniqueness (phase 2 mechanism, inert in phase 1: it only looks at games
--     whose event_id is set, and none are until KAN-711). One start_at per series_id across
--     events-linked games; cancelled/kept slots still occupy their slot. The per-series advisory
--     lock serialises concurrent checkers; the check runs at commit, so a loser sees the winner.
create function public.events_check_series_occurrence() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  sid uuid;
  ev_id uuid;
begin
  if tg_table_name = 'games' then
    sid := new.series_id;
    ev_id := new.event_id;
    if sid is null or ev_id is null then
      return null;
    end if;
  else
    -- events.start_at changed: find the linked game
    select g.series_id, g.event_id into sid, ev_id from public.games g where g.event_id = new.id;
    if sid is null then
      return null;
    end if;
  end if;
  perform pg_advisory_xact_lock(hashtext('events_series:' || sid::text));
  if exists (
    select 1
    from public.games g
    join public.events e on e.id = g.event_id
    join public.events me on me.id = ev_id
    where g.series_id = sid
      and g.event_id is not null
      and g.event_id <> ev_id
      and e.start_at = me.start_at
  ) then
    raise exception 'series % already has an occurrence at this start_at', sid
      using errcode = 'unique_violation';
  end if;
  return null;
end $$;
alter function public.events_check_series_occurrence() owner to postgres;

revoke all on function public.events_set_search_tsv()          from public, anon, authenticated;
revoke all on function public.events_guard_type_immutable()    from public, anon, authenticated;
revoke all on function public.events_check_subtype_link()      from public, anon, authenticated;
revoke all on function public.events_check_parent_children()   from public, anon, authenticated;
revoke all on function public.events_check_series_occurrence() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Triggers on events (exactly: touch, tsv, type-immutable, exclusive check, series start_at)
-- ---------------------------------------------------------------------------
create trigger trg_events_touch before update on public.events
  for each row execute function public.touch_updated_at();
create trigger trg_events_search_tsv before insert or update of title, event_type on public.events
  for each row execute function public.events_set_search_tsv();
create trigger trg_events_type_immutable before update on public.events
  for each row execute function public.events_guard_type_immutable();
create constraint trigger trg_events_exclusive_check after insert or update of event_type on public.events
  deferrable initially deferred
  for each row execute function public.events_check_parent_children();
create constraint trigger trg_events_series_start_check after update of start_at on public.events
  deferrable initially deferred
  for each row execute function public.events_check_series_occurrence();

-- ---------------------------------------------------------------------------
-- 6. Subtype identity links (nullable: legacy rows keep NULL until KAN-711)
-- ---------------------------------------------------------------------------
alter table public.games   add column event_id uuid;
alter table public.meetups add column event_id uuid;

alter table public.games   add constraint games_event_id_key   unique (event_id);
alter table public.meetups add constraint meetups_event_id_key unique (event_id);

alter table public.games   add constraint games_event_id_fkey   foreign key (event_id)
  references public.events (id) on delete cascade deferrable initially deferred;
alter table public.meetups add constraint meetups_event_id_fkey foreign key (event_id)
  references public.events (id) on delete cascade deferrable initially deferred;

create constraint trigger trg_games_event_link_check after insert or update of event_id on public.games
  deferrable initially deferred
  for each row execute function public.events_check_subtype_link();
create constraint trigger trg_meetups_event_link_check after insert or update of event_id on public.meetups
  deferrable initially deferred
  for each row execute function public.events_check_subtype_link();
create constraint trigger trg_games_series_occurrence_check after insert or update of series_id, event_id on public.games
  deferrable initially deferred
  for each row execute function public.events_check_series_occurrence();

commit;
