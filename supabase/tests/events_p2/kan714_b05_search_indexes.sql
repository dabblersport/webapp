-- KAN-724 (KAN-714 B05): probes for 20261104100500_kan714_b05_search_filter_indexes.sql.
-- LOCAL THROWAWAY DATABASE ONLY. Runs inside BEGIN ... ROLLBACK and leaves nothing behind.
-- Build: events_p1 harness+seed, events_p2 local_harness_kan712, events_p2_kan713 local_harness_kan713,
--        KAN-710, KAN-711 (x2, backfill, validate), KAN-712 (A+B), KAN-713 (x2), KAN-718, then optionally KAN-724.
-- Run:   PGOPTIONS='-c kan724.local=on' psql -X -v ON_ERROR_STOP=1 -d <db> -f this_file.sql
--
-- Check kinds:
--   [=] parity: must PASS on the pre-image AND after the migration (shape, counts, no doubles, meetup
--       description/location matches, visibility, viewer/blocked parity, attributes).
--   [K] change: must FAIL on the pre-image and PASS after (events is read, deterministic tie-break, index used).
--   [R] rollback (only when applied): restoring the pre-image text in a savepoint leaves data hashes equal,
--       md5 equal to the pin, index gone.
-- Output: one PASS/FAIL line per check, then 'ALL PASS' (applied) or 'PRE-IMAGE OK: every [=] passes and every
-- [K] fails' (not applied).
--
-- Stand-ins: the local harness has no hashtags/squads/comments tables and only a few columns of profiles,
-- posts, venues, challenges. The unified RPC's other six sections need them to exist; they are created here,
-- empty, inside the transaction. Only the games and meetups sections are under test.

\set ON_ERROR_STOP 1
begin;

do $$ begin
  if coalesce(current_setting('kan724.local', true), '') <> 'on' then
    raise exception 'KAN-724 probes: refusing to run; set kan724.local=on (local throwaway database only)';
  end if;
end $$;

create temp table res (id text primary key, kind text, got text, want text, ord serial);

-- Stand-ins for the other sections (empty) ------------------------------------------------------------------
create table if not exists public.hashtags (id uuid primary key default gen_random_uuid());
create table if not exists public.squads (id uuid primary key default gen_random_uuid());
create table if not exists public.comments (id uuid primary key default gen_random_uuid());
alter table public.hashtags add column if not exists tag text, add column if not exists display_tag text,
  add column if not exists usage_count int, add column if not exists is_banned boolean,
  add column if not exists is_searchable boolean, add column if not exists is_approved boolean;
alter table public.squads add column if not exists name text, add column if not exists city text,
  add column if not exists logo_url text, add column if not exists search_tsv tsvector, add column if not exists is_active boolean;
alter table public.comments add column if not exists parent_activity_id uuid, add column if not exists search_tsv tsvector,
  add column if not exists is_deleted boolean, add column if not exists is_hidden_admin boolean;
alter table public.profiles add column if not exists search_tsv tsvector, add column if not exists display_name text,
  add column if not exists username text, add column if not exists avatar_url text;
alter table public.posts add column if not exists body text, add column if not exists author_display_name text,
  add column if not exists priority_score numeric, add column if not exists search_tsv tsvector,
  add column if not exists visibility text, add column if not exists is_deleted boolean,
  add column if not exists is_hidden_admin boolean, add column if not exists is_active boolean;
alter table public.venues add column if not exists name_en text, add column if not exists area text,
  add column if not exists search_tsv tsvector, add column if not exists rating numeric, add column if not exists is_active boolean;
alter table public.challenges add column if not exists status text, add column if not exists search_tsv tsvector,
  add column if not exists is_active boolean;

-- Legacy reference: the verbatim pre-image body under another name (pg_get_functiondef of the baseline text).
CREATE OR REPLACE FUNCTION public.kan724_legacy_unified(p_query text, p_sport_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_radius_km double precision DEFAULT NULL::double precision, p_limit_per_section integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_tsquery tsquery;
  v_q       text;
BEGIN
  IF p_query IS NULL OR length(trim(p_query)) < 2 THEN
    RETURN jsonb_build_object(
      'profiles','[]'::jsonb,'games','[]'::jsonb,'venues','[]'::jsonb,
      'squads','[]'::jsonb,'posts','[]'::jsonb,'meetups','[]'::jsonb,
      'challenges','[]'::jsonb,'hashtags','[]'::jsonb);
  END IF;
  v_tsquery := plainto_tsquery('simple', unaccent(p_query));
  v_q       := '%' || lower(trim(p_query)) || '%';
  RETURN jsonb_build_object(
    'hashtags', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT h.id, h.tag AS slug, h.display_tag, h.usage_count
        FROM public.hashtags h
        WHERE lower(h.tag) LIKE v_q
          AND (h.is_banned IS NULL OR h.is_banned = false)
          AND (h.is_searchable IS NULL OR h.is_searchable = true)
          AND (h.is_approved IS NULL OR h.is_approved = true)
        ORDER BY h.usage_count DESC NULLS LAST LIMIT p_limit_per_section) t),
    'posts', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'post' AS entity_type, p.id AS entity_id, left(p.body,80) AS title,
          p.author_display_name AS subtitle, NULL::text AS image_url,
          '/post/' || p.id AS route,
          ts_rank(p.search_tsv, v_tsquery)
          + (COALESCE(p.priority_score,0) * 0.01)
          + (SELECT COUNT(*) * 0.05 FROM public.comments pc
             WHERE pc.parent_activity_id = p.id
               AND pc.search_tsv @@ v_tsquery
               AND pc.is_deleted = FALSE AND pc.is_hidden_admin = FALSE) AS score
        FROM public.posts p
        WHERE p.search_tsv @@ v_tsquery AND p.visibility = 'public'
          AND p.is_deleted = FALSE AND p.is_hidden_admin = FALSE AND p.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'profiles', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'profile' AS entity_type, p.user_id AS entity_id, p.id AS profile_id,
          p.display_name AS title, p.username AS subtitle, p.avatar_url AS image_url,
          p.persona_type AS profile_type, p.is_active, '/profile/' || p.username AS route,
          ts_rank(p.search_tsv, v_tsquery) AS score
        FROM public.profiles p WHERE p.search_tsv @@ v_tsquery
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'games', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'game' AS entity_type, g.id AS entity_id, g.title AS title,
          NULL::text AS subtitle, NULL::text AS image_url, '/game/' || g.id AS route,
          ts_rank(g.search_tsv, v_tsquery) + CASE WHEN g.start_at > NOW() THEN 0.2 ELSE 0 END AS score
        FROM public.games g
        WHERE g.search_tsv @@ v_tsquery AND g.listing_visibility = 'public' AND g.is_cancelled = FALSE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'venues', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'venue' AS entity_type, v.id AS entity_id, v.name_en AS title,
          v.area AS subtitle, NULL::text AS image_url, '/venue/' || v.id AS route,
          ts_rank(v.search_tsv, v_tsquery) + (COALESCE(v.rating,0) * 0.05) AS score
        FROM public.venues v WHERE v.search_tsv @@ v_tsquery AND v.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'squads', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'squad' AS entity_type, s.id AS entity_id, s.name AS title,
          s.city AS subtitle, s.logo_url AS image_url, '/squad/' || s.id AS route,
          ts_rank(s.search_tsv, v_tsquery) AS score
        FROM public.squads s WHERE s.search_tsv @@ v_tsquery AND s.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'meetups', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'meetup' AS entity_type, m.id AS entity_id, m.title AS title,
          m.location_name AS subtitle, NULL::text AS image_url, '/meetup/' || m.id AS route,
          ts_rank(m.search_tsv, v_tsquery) AS score
        FROM public.meetups m WHERE m.search_tsv @@ v_tsquery
          AND m.listing_visibility = 'public' AND m.is_cancelled = FALSE
        ORDER BY score DESC LIMIT p_limit_per_section) t),
    'challenges', (
      SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT 'challenge' AS entity_type, c.id AS entity_id, c.title AS title,
          c.status AS subtitle, NULL::text AS image_url, '/challenge/' || c.id AS route,
          ts_rank(c.search_tsv, v_tsquery) AS score
        FROM public.challenges c WHERE c.search_tsv @@ v_tsquery AND c.is_active = TRUE
        ORDER BY score DESC LIMIT p_limit_per_section) t)
  );
END;
$function$;

-- Is the migration applied?
create temp table st as
select to_regclass('public.events_game_public_search_tsv_idx') is not null as applied;

-- Normaliser: each section array sorted by element text (order-free comparison for parity).
create function pg_temp.norm(j jsonb) returns jsonb language sql immutable as $f$
  select coalesce(jsonb_object_agg(k, case when jsonb_typeof(v) = 'array'
           then (select coalesce(jsonb_agg(e order by e::text), '[]'::jsonb) from jsonb_array_elements(v) e) else v end), '{}'::jsonb)
    from jsonb_each(j) s(k, v)
$f$;
create function pg_temp.ids(j jsonb, sec text) returns text language sql immutable as $f$
  select coalesce(string_agg(e->>'entity_id', ',' order by o), '') from jsonb_array_elements(j->sec) with ordinality x(e, o)
$f$;

-- Seed: a same-start_at public game pair, higher id inserted first (insertion order must not decide).
insert into public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id)
select v.id::uuid, 'Tiebreak Padel', g.creator_profile_id, g.creator_user_id, '2030-08-01 18:00+00', '2030-08-01 19:00+00', 10, 'public', 'open',
       g.sport_id, g.geo_location_id, g.area_id
  from public.games g, (values ('72400000-0000-0000-0000-0000000000b2', 1), ('72400000-0000-0000-0000-0000000000a1', 2)) v(id, o)
 where g.id = '71300000-0000-0000-0000-000000000001' order by v.o;

insert into res (id, kind, got, want)
select 'S0 seed tie pair linked to events', '=', count(*)::text, '2'
  from public.events e join public.games g on g.event_id = e.id
 where e.title = 'Tiebreak Padel' and e.start_at = '2030-08-01 18:00+00';

-- S1/S2 [=] shape ---------------------------------------------------------------------------------------------
insert into res (id, kind, got, want)
select 'S1 top-level keys', '=',
  (select string_agg(k, ',' order by k) from jsonb_object_keys(public.rpc_unified_search_sectioned('sunday')) k),
  (select string_agg(k, ',' order by k) from jsonb_object_keys(public.kan724_legacy_unified('sunday')) k);
insert into res (id, kind, got, want)
select 'S2 ' || sec || ' element keys/types', '=',
  (select string_agg(k || ':' || jsonb_typeof(v), ',' order by k) from jsonb_each(public.rpc_unified_search_sectioned(q)->sec->0) x(k, v)),
  (select string_agg(k || ':' || jsonb_typeof(v), ',' order by k) from jsonb_each(public.kan724_legacy_unified(q)->sec->0) x(k, v))
  from (values ('games', 'sunday'), ('meetups', 'morning')) t(sec, q);

-- C1/C2 [=] counts and content equal legacy; no doubled rows ---------------------------------------------------
insert into res (id, kind, got, want)
select 'C1 parity q=' || coalesce(q, 'NULL') || ' lim=' || lim, '=',
       md5(pg_temp.norm(public.rpc_unified_search_sectioned(q, null, null, null, null, lim))::text) || ' n=' ||
         (select count(*) from jsonb_each(public.rpc_unified_search_sectioned(q, null, null, null, null, lim)) s(k, v), jsonb_array_elements(v)),
       md5(pg_temp.norm(public.kan724_legacy_unified(q, null, null, null, null, lim))::text) || ' n=' ||
         (select count(*) from jsonb_each(public.kan724_legacy_unified(q, null, null, null, null, lim)) s(k, v), jsonb_array_elements(v))
  from (values ('sunday'), ('morning'), ('easy'), ('pace'), ('corniche'), ('tiebreak'), ('padel'), ('series'), ('pub'),
               ('zz_kan724_nomatch'), (null), ('a'), ('')) w(q), (values (10), (1000)) l(lim);
insert into res (id, kind, got, want)
select 'C2 no doubled entity_id q=' || q, '=',
       (select count(*) - count(distinct e->>'entity_id') from jsonb_each(public.rpc_unified_search_sectioned(q, null, null, null, null, 1000)) s(k, v),
               jsonb_array_elements(v) e where k in ('games', 'meetups'))::text, '0'
  from (values ('sunday'), ('morning'), ('tiebreak'), ('padel'), ('series')) w(q);

-- D [=] meetup description / location matches do not regress (events.search_tsv is title-only for meetups).
insert into res (id, kind, got, want) values
  ('D1 description "easy" finds Morning run', '=', pg_temp.ids(public.rpc_unified_search_sectioned('easy'), 'meetups'), '30000000-0000-0000-0000-000000000001'),
  ('D2 location "corniche" finds Morning run', '=', pg_temp.ids(public.rpc_unified_search_sectioned('corniche'), 'meetups'), '30000000-0000-0000-0000-000000000001'),
  ('D3 subtitle is meetups.location_name', '=', public.rpc_unified_search_sectioned('corniche')->'meetups'->0->>'subtitle', 'Corniche');

-- V1 [=] nothing non-public or cancelled is ever returned (checked against events AND legacy).
insert into res (id, kind, got, want)
select 'V1 no non-public/cancelled row', '=', count(*)::text, '0'
  from (values ('pub'), ('fol'), ('pri'), ('link'), ('circle'), ('hidden'), ('invite'), ('cancelled'), ('league'), ('closed'),
               ('only'), ('padel'), ('public'), ('meetup'), ('drift'), ('series'), ('sunday'), ('run')) w(q),
       jsonb_each(public.rpc_unified_search_sectioned(q, null, null, null, null, 1000)) s(k, v), jsonb_array_elements(v) e
 where k in ('games', 'meetups')
   and (exists (select 1 from public.events x where x.id = (e->>'entity_id')::uuid and (x.listing_visibility <> 'public' or x.is_cancelled))
     or exists (select 1 from public.games x where x.id = (e->>'entity_id')::uuid and (x.listing_visibility <> 'public' or x.is_cancelled))
     or exists (select 1 from public.meetups x where x.id = (e->>'entity_id')::uuid and (x.listing_visibility <> 'public' or x.is_cancelled)));

-- V2 [=] viewer parity: anon, a non-owner and a user blocked by the creator see exactly the legacy result.
create temp table v2 (who text, q text, out jsonb);
grant all on v2 to anon, authenticated;
insert into public.user_blocks (blocker_user_id, blocked_user_id)
select g.creator_user_id, '00000000-0000-0000-0000-0000000072b0' from public.games g where g.id = '71300000-0000-0000-0000-000000000001';
set local role anon;
insert into v2 select 'anon', q, public.rpc_unified_search_sectioned(q, null, null, null, null, 1000) from (values ('pub'), ('tiebreak'), ('morning')) w(q);
reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000072a0', true),
       set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000072a0","role":"authenticated"}', true);
set local role authenticated;
insert into v2 select 'non-owner', q, public.rpc_unified_search_sectioned(q, null, null, null, null, 1000) from (values ('pub'), ('tiebreak'), ('morning')) w(q);
reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000072b0', true),
       set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000072b0","role":"authenticated"}', true);
set local role authenticated;
insert into v2 select 'blocked', q, public.rpc_unified_search_sectioned(q, null, null, null, null, 1000) from (values ('pub'), ('tiebreak'), ('morning')) w(q);
reset role;
select set_config('request.jwt.claim.sub', '', true), set_config('request.jwt.claims', '', true);
insert into res (id, kind, got, want)
select 'V2 ' || who || ' q=' || q, '=', md5(pg_temp.norm(out)::text),
       md5(pg_temp.norm(public.kan724_legacy_unified(q, null, null, null, null, 1000))::text)
  from v2;

-- X1 [=] attributes, owner and ACL are the pre-image's.
insert into res (id, kind, got, want)
select 'X1 attributes/owner/acl', '=',
       concat_ws('|', prosecdef, proconfig::text, provolatile, proowner::regrole::text, proacl::text, prorettype::regtype::text),
       't|{search_path=public}|v|postgres|{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}|jsonb'
  from pg_proc where oid = 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'::regprocedure;

-- K4 [K] deterministic tie-break under equal score and equal start_at: (start_at, id).
insert into res (id, kind, got, want)
select 'K4a tie limit 1 -> lower id', 'K', pg_temp.ids(public.rpc_unified_search_sectioned('tiebreak', null, null, null, null, 1), 'games'),
       '72400000-0000-0000-0000-0000000000a1';
insert into res (id, kind, got, want)
select 'K4b tie limit 2 -> [lower, higher], 5 runs', 'K',
       (select string_agg(distinct pg_temp.ids(public.rpc_unified_search_sectioned('tiebreak', null, null, null, null, 2), 'games'), ' / ')
          from generate_series(1, 5)),
       '72400000-0000-0000-0000-0000000000a1,72400000-0000-0000-0000-0000000000b2';

-- K5 [K] the body reads public.events.
insert into res (id, kind, got, want)
select 'K5 body reads public.events', 'K', (prosrc like '%FROM public.events e%')::text, 'true'
  from pg_proc where proname = 'rpc_unified_search_sectioned';

-- I1 [K] EXPLAIN before/after at volume: 3000 filler public games are inserted and analysed inside an undone
-- subtransaction (a ~20-row harness plans everything as a scan of the smallest index, which proves nothing).
-- Natural plans (no enable_* overrides) for the legacy games predicate and the new events predicate are printed.
do $$
declare l text; pre text := ''; post text := ''; q tsquery := plainto_tsquery('simple', 'tiebreak');
begin
  set constraints all immediate;
  begin
    insert into public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                              sport_id, geo_location_id, area_id)
    select gen_random_uuid(), 'Filler game ' || n, g.creator_profile_id, g.creator_user_id, g.start_at + make_interval(hours => n),
           g.end_at + make_interval(hours => n), 10, 'public', 'open', g.sport_id, g.geo_location_id, g.area_id
      from public.games g, generate_series(1, 3000) n where g.id = '71300000-0000-0000-0000-000000000001';
    analyze public.events; analyze public.games;
    for l in execute format($x$explain select g.id from public.games g
       where g.search_tsv @@ %L::tsquery and g.listing_visibility = 'public' and g.is_cancelled = false$x$, q) loop
      pre := pre || l || E'\n';
    end loop;
    for l in execute format($x$explain select e.id from public.events e join public.games g on g.event_id = e.id
       where e.event_type = 'game' and e.search_tsv @@ %L::tsquery and e.listing_visibility = 'public' and e.is_cancelled = false
         and g.listing_visibility = 'public' and g.is_cancelled = false$x$, q) loop
      post := post || l || E'\n';
    end loop;
    raise exception using errcode = 'P0001', message = 'kan724_undo';
  exception when others then
    if sqlerrm <> 'kan724_undo' then post := 'ERR ' || sqlstate || ' ' || sqlerrm; end if;
  end;
  raise notice E'EXPLAIN legacy games section (pre-image shape, 3000+ games):\n%', pre;
  raise notice E'EXPLAIN events games section (new shape, 3000+ events):\n%', post;
  insert into res (id, kind, got, want) values
    ('I1 events games search uses events_game_public_search_tsv_idx', 'K', (post like '%events_game_public_search_tsv_idx%')::text, 'true');
end $$;

-- K1-K3 [K] events is the authority for title / cancel / visibility. Diverge events only (compat mirror off,
-- inside a subtransaction that is undone), as phase 4 will once legacy columns stop being written.
do $$
declare r1 text; r2 text; r3 text;
begin
  set constraints all immediate;   -- flush the seed's deferred trigger events so the ALTER is allowed
  begin
    alter table public.events disable trigger trg_zz_kan712_events_compat_mirror;
    update public.events set title = 'Kan724zebra' where id = '10000000-0000-0000-0000-000000000001';
    update public.events set is_cancelled = true where id = '71300000-0000-0000-0000-000000000001';
    update public.events set listing_visibility = 'hidden' where id = '30000000-0000-0000-0000-000000000001';
    r1 := pg_temp.ids(public.rpc_unified_search_sectioned('kan724zebra'), 'games');
    r2 := pg_temp.ids(public.rpc_unified_search_sectioned('pub', null, null, null, null, 1000), 'games');
    r3 := pg_temp.ids(public.rpc_unified_search_sectioned('easy'), 'meetups');
    raise exception using errcode = 'P0001', message = 'kan724_undo';
  exception when others then
    if sqlerrm <> 'kan724_undo' then r1 := 'ERR ' || sqlstate || ' ' || sqlerrm; r2 := r1; r3 := r1; end if;
  end;
  insert into res (id, kind, got, want) values
    ('K1 events title is searched', 'K', r1, '10000000-0000-0000-0000-000000000001'),
    ('K2 events.is_cancelled excludes G-pub', 'K', case when r2 like 'ERR%' then r2 else (position('71300000-0000-0000-0000-000000000001' in coalesce(r2, '')) = 0)::text end, 'true'),
    ('K3 events visibility hidden excludes Morning run', 'K', coalesce(r3, ''), '');
end $$;

-- R1 [R] rollback in a savepoint (only when applied): restore the verbatim pre-image text and drop the index.
create temp table hashes (t text, h text, phase text);
create function pg_temp.datahash() returns table (t text, h text) language sql as $f$
  select 'events', md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.events x
  union all select 'games', md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.games x
  union all select 'meetups', md5(coalesce(string_agg(x::text, '|' order by x.id), '')) from public.meetups x
$f$;
do $$
declare v_def text; r text; v_after jsonb;
begin
  if not (select applied from st) then
    insert into res (id, kind, got, want) values ('R1 rollback (not applied: skipped)', 'R', 'skip', 'skip');
    return;
  end if;
  insert into hashes select d.t, d.h, 'before' from pg_temp.datahash() d;
  begin
    v_def := replace(pg_get_functiondef('public.kan724_legacy_unified'::regproc),
                     'FUNCTION public.kan724_legacy_unified(', 'FUNCTION public.rpc_unified_search_sectioned(');
    execute v_def;
    drop index public.events_game_public_search_tsv_idx;
    select jsonb_object_agg(d.t, d.h) into v_after from pg_temp.datahash() d;   -- survives the undo below
    select concat_ws('|', md5(prosrc), to_regclass('public.events_game_public_search_tsv_idx') is null, proacl::text)
      into r from pg_proc where proname = 'rpc_unified_search_sectioned';
    raise exception using errcode = 'P0001', message = 'kan724_undo';
  exception when others then
    if sqlerrm <> 'kan724_undo' then r := 'ERR ' || sqlstate || ' ' || sqlerrm; end if;
  end;
  insert into res (id, kind, got, want) values
    ('R1 rollback restores pin, drops index, keeps acl', 'R', r,
     'fe3382197842fa66564b2f62d9b754f5|t|{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}');
  insert into res (id, kind, got, want)
  select 'R2 data hash ' || b.t || ' unchanged by rollback', 'R', coalesce(v_after->>b.t, 'missing'), b.h
    from hashes b where b.phase = 'before';
end $$;

-- Report --------------------------------------------------------------------------------------------------
\pset format unaligned
\pset tuples_only on
select case when got is not distinct from want then 'PASS ' else 'FAIL ' end || '[' || kind || '] ' || id ||
       case when got is distinct from want then '  got=' || coalesce(got, 'NULL') || ' want=' || coalesce(want, 'NULL') else '' end
  from res order by ord;
select case
  when (select applied from st) and not exists (select 1 from res where got is distinct from want)
    then 'ALL PASS (' || (select count(*) from res) || ' checks, migration applied)'
  when not (select applied from st)
       and not exists (select 1 from res where kind in ('=', 'R') and got is distinct from want)
       and not exists (select 1 from res where kind = 'K' and got is not distinct from want)
    then 'PRE-IMAGE OK: every [=] passes and every [K] fails (' || (select count(*) from res where kind = 'K') || ' K checks)'
  else 'NOT PASS'
end;

rollback;
