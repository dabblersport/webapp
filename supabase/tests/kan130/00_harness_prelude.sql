-- KAN-130 probe pack — local-only harness prelude. NOT part of the migration.
--
-- Base image: supabase/postgres:15.8.1.060, which already ships the supabase
-- roles, the auth schema, auth.users and auth.uid(). The harness loads the LIVE
-- public schema of wtncuzcskpigqpmnxwws on top of that (see run.sh), so this
-- file supplies only what a `--schema public` dump cannot carry:
--
--   (a) the extensions the public schema depends on (a schema-only dump of
--       public excludes extension DDL);
--   (b) the auth.* tables public has foreign keys or views onto;
--   (c) a fallback storage.objects, because delete_my_account deletes from it
--       and P5 executes that function end to end.
--
-- (c) is normally a NO-OP: supabase/postgres ships the storage schema and
-- storage.objects already, so the `if not exists` below skips and P5 runs
-- against the real table, guard included. The definition is kept as a fallback
-- for an image that does not ship it -- in which case P5's pass is weaker
-- (it proves delete_my_account REACHES and REMOVES the wallet row, but does not
-- exercise Supabase's storage delete guard) and this comment is the declaration
-- of that, rather than a silent difference.

create extension if not exists citext with schema public;
create extension if not exists pg_trgm with schema public;
create extension if not exists postgis with schema public;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema public;
create extension if not exists unaccent with schema public;

create table if not exists auth.identities (id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade, provider text, identity_data jsonb, created_at timestamptz default now(), updated_at timestamptz default now(), last_sign_in_at timestamptz);
create table if not exists auth.sessions (id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade, created_at timestamptz default now(), updated_at timestamptz default now(), ip inet, user_agent text, not_after timestamptz);
create table if not exists auth.mfa_factors (id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade, status text, factor_type text, friendly_name text, created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists auth.mfa_challenges (id uuid primary key default gen_random_uuid(), factor_id uuid, created_at timestamptz default now(), verified_at timestamptz, ip_address inet);
create table if not exists auth.mfa_amr_claims (id uuid primary key default gen_random_uuid(), session_id uuid, authentication_method text, created_at timestamptz default now(), updated_at timestamptz default now());
grant usage on schema auth to anon, authenticated, service_role, postgres;

create schema if not exists storage;
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text,
  name text,
  owner uuid,
  created_at timestamptz default now()
);
grant usage on schema storage to anon, authenticated, service_role, postgres;
