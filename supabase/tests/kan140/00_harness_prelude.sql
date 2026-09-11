-- Local-only harness prelude (NOT part of the migration). Same shape as
-- supabase/tests/kan128/00_harness_prelude.sql -- see that file's comment for
-- why. Base image: supabase/postgres:15.8.1.060 -- ships the supabase roles,
-- the auth schema, auth.users and auth.uid() already.
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
