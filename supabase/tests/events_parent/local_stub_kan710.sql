-- KAN-710 local stub baseline. LOCAL DISPOSABLE POSTGRES ONLY, never live, not a migration.
-- Minimal shapes of the tables/functions 20261101140000 references, taken from the repo baseline
-- migration (columns reduced to what the migration and probes touch). Seeds 2 games + 1 meetup.
create extension if not exists unaccent;
do $$ begin
  create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin
  create role authenticated nologin; exception when duplicate_object then null; end $$;
do $$ begin
  create role service_role nologin bypassrls; exception when duplicate_object then null; end $$;
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;

create schema if not exists auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;

create function public.touch_updated_at() returns trigger language plpgsql as
$$ begin new.updated_at = now(); return new; end $$;
create function public.unaccent_immutable(text) returns text language sql immutable as
$$ select public.unaccent('public.unaccent', $1) $$;

create table public.profiles   (id uuid primary key default gen_random_uuid());
create table public.sports     (id uuid primary key default gen_random_uuid());
create table public.areas      (id uuid primary key default gen_random_uuid());
create table public.geo_locations (id uuid primary key default gen_random_uuid());
create table public.venues     (id uuid primary key default gen_random_uuid());

create table public.games (
  id uuid primary key default gen_random_uuid(),
  creator_profile_id uuid not null references public.profiles(id) on delete restrict,
  creator_user_id uuid not null,
  title text, start_at timestamptz not null, end_at timestamptz, capacity integer,
  sport_id uuid, area_id uuid, geo_location_id uuid, series_id uuid,
  updated_at timestamptz not null default now());
create table public.meetups (
  id uuid primary key default gen_random_uuid(),
  creator_profile_id uuid not null references public.profiles(id),
  creator_user_id uuid not null,
  title text, start_at timestamptz not null, end_at timestamptz, capacity integer,
  updated_at timestamptz not null default now());
alter table public.meetups force row level security;
alter table public.meetups enable row level security;

insert into public.profiles default values;
insert into public.sports default values;
insert into public.areas default values;
insert into public.geo_locations default values;
insert into public.games (id,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
select 'aaaaaaaa-0000-0000-0000-000000000001', p.id, gen_random_uuid(), 'Game one', now()+interval '1 day', now()+interval '1 day 1 hour', 10,
       (select id from public.sports), (select id from public.areas), (select id from public.geo_locations) from public.profiles p;
insert into public.games (id,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,sport_id,area_id,geo_location_id)
select 'aaaaaaaa-0000-0000-0000-000000000002', p.id, gen_random_uuid(), 'Game two', now()+interval '2 day', now()+interval '2 day 1 hour', 10,
       (select id from public.sports), (select id from public.areas), (select id from public.geo_locations) from public.profiles p;
insert into public.meetups (id,creator_profile_id,creator_user_id,title,start_at)
select 'bbbbbbbb-0000-0000-0000-000000000001', p.id, gen_random_uuid(), 'Meetup one', now()+interval '3 day' from public.profiles p;
