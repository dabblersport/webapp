-- KAN-724 (KAN-714 B05, Epic KAN-708 Events P2): search / autocomplete over the shared event columns
-- reads public.events. AUTHORED, NOT APPLIED. Author: backend-4 (Min), team Ramesseum.
-- Verified only on a throwaway local PostgreSQL cluster (/tmp/kan724_pg, port 54724, stopped afterwards)
-- with supabase/tests/events_p2/kan714_b05_search_indexes.sql. Live catalogue reads were NOT available to
-- this seat (execute_sql refused by the ops guard, D-042), so the inventory below is derived from the repo
-- migrations, latest definition wins, and the change is fail-closed against the live body by an md5 pin.
--
-- ============================================================================================================
-- 1. INVENTORY: every search / autocomplete / location-search function and index over games/meetups
--    shared columns (title, start_at, end_at, sport_id, listing_visibility, join_policy, is_cancelled,
--    geo_location_id, area_id, venue_id ...). Baseline = 20260829080500_baseline_schema.sql.
--    "Latest definition" = last migration that defines it; none of these is re-defined or dropped later
--    unless a later file:line is given.
-- ------------------------------------------------------------------------------------------------------------
-- FUNCTIONS
--  #  object                                   latest definition (file:line)        action
--  F1 rpc_unified_search_sectioned(text,uuid,   baseline:16246-16337 (grants         CHANGED. games section reads
--     float8,float8,float8,int)                  36875-36877). The only one the app   events (search_tsv, title,
--                                                calls (lib/data/repositories/        start_at, listing_visibility,
--                                                search_repository_impl.dart:40)      is_cancelled) AND keeps the
--                                                                                     legacy visibility/cancel
--                                                                                     conjunct (narrow-only, KAN-713
--                                                                                     rule). meetups section keeps
--                                                                                     meetups.search_tsv for MATCH
--                                                                                     and RANK (title A + description
--                                                                                     B + location_name C; events is
--                                                                                     title-only for meetups, KAN-710
--                                                                                     :125-138) and reads title /
--                                                                                     visibility / cancel from events.
--                                                                                     Both sections: deterministic
--                                                                                     tie-break score DESC, start_at,
--                                                                                     id. Other 6 sections untouched.
--                                                                                     NOT in kan712_wrapped_rpcs (it is
--                                                                                     a reader) -> plain replace is the
--                                                                                     correct path; asserted below.
--  F2 rpc_search_entities(text,text[],text,int) baseline:15155-15302                 EXCEPTION X1, UNCHANGED. Games
--                                                                                     section reads v_game_card.sport
--                                                                                     (baseline:15255,15258,15269),
--                                                                                     a column v_game_card does not
--                                                                                     have (latest view 20261101120000
--                                                                                     :10, sport_key only). Statement
--                                                                                     runs regardless of p_scope, so
--                                                                                     every call raises 42703 today.
--                                                                                     Converting it would be a fix, not
--                                                                                     a parity port. v_game_card is
--                                                                                     KAN-720's surface.
--  F3 rpc_autocomplete_entities(text,text[],    baseline:10761-10863                 EXCEPTION X2, UNCHANGED. Games
--     text,int)                                                                       branch reads games.sport
--                                                                                     (baseline:10823-10824,10835);
--                                                                                     games has no `sport` column
--                                                                                     (baseline:22863-22908 + later
--                                                                                     ADD COLUMNs). Raises 42703
--                                                                                     whenever 'games' is in p_scope
--                                                                                     (the default). Same reasoning.
--  F4 rpc_get_nearby_games(float8,float8,int,   5-arg: 20261008160000:25; 6-arg      EXCEPTION X3, UNCHANGED. PostGIS
--     uuid,text[,numeric])                       (+p_max_price): 20261008140000:360   geo filter (st_dwithin on
--                                                                                     geo_locations); not executable on
--                                                                                     the local harness (no PostGIS),
--                                                                                     so a conversion could not be
--                                                                                     proven. Tie-break gap: ORDER BY
--                                                                                     distance, start_at (no id).
--  F5 get_nearby_games(float8,float8,float8)    baseline:7381                        EXCEPTION X3, UNCHANGED (PostGIS).
--  F6 get_nearby_games(float8,float8,int)       baseline:7421                        EXCEPTION X3, UNCHANGED (PostGIS).
--  F7 nearby_games(float8,float8,int,text,int,  baseline:9006                        EXCEPTION X3, UNCHANGED (PostGIS;
--     int)                                                                            also reads games.sport, 42703).
--  F8 getnearbygames(float8,float8,float8)      baseline:7823                        EXCEPTION X4, UNCHANGED. Dead:
--  F9 getnearbymeetups(float8,float8,float8)    baseline:7850                        reads public.geolocations /
--                                                                                     g.geolocationid, which do not
--                                                                                     exist in any migration.
--  T1 trg_games_set_search_tsv()                baseline:17824-17835                 UNCHANGED (writer of the legacy
--  T2 meetups_search_tsv_trigger()              baseline:8989-9003                   vectors; T2 stays authoritative
--  T3 events_set_search_tsv()                   20261101140000:128-138               for meetup description/location).
--  H1 _normalize_query(text), _norm_prefix(text) baseline:1310-1325, 1296-1305       UNCHANGED (callers F2/F3 only).
--  Not search: get_nearby_posts/profiles/venues, rpc_get_nearby_venues, search_areas, search_venues_with_filters,
--  rpc_profile_search, rpc_search_users, rpc_search_posts, rpc_feed_ranked, rpc_get_activity_feed,
--  rpc_recreate_suggestions: grep-checked, none text- or location-searches games/meetups shared columns.
--
-- INDEXES (games/meetups, every CREATE INDEX in the repo; none dropped later)
--  I1  idx_games_search_tsv     games GIN(search_tsv)                baseline:28625   UNCHANGED, now unused by F1.
--                                                                                     Kept: legacy column still
--                                                                                     written (phase 4 drops it).
--  I2  idx_games_title_prefix   games lower(unaccent_immutable(title)) baseline:28641 UNCHANGED (only reader F3, X2).
--  I3  idx_games_start_at / idx_games_time / idx_games_cancelled / idx_games_is_cancelled /
--      idx_games_visibility / idx_games_area / idx_games_geo  baseline:28633,28637,28605,28621,28645,28601,28613
--                                                                     UNCHANGED (read by X3 functions and others).
--  I4  idx_meetups_search_tsv   meetups GIN(search_tsv)              baseline:28753   UNCHANGED, still the driving
--                                                                                     index of F1's meetups section.
--  I5  idx_meetups_owner / idx_meetups_owner_time                    baseline:28745,28749 UNCHANGED (not search).
--  I6  events_search_tsv_idx GIN, events_title_lower_idx, events_type_start_at_idx, events_upcoming_idx,
--      events_type_vis_join_idx, events_geo_location_idx, events_area_idx   20261101140000:107-116  UNCHANGED.
--  I7  games_event_id_key / meetups_event_id_key (unique)            20261101140000:279-280  UNCHANGED; the join keys.
--  NEW events_game_public_search_tsv_idx  GIN(search_tsv) WHERE event_type='game' AND listing_visibility=
--      'public' AND is_cancelled=false. Replacement for I1 on F1's games section (exactly F1's predicate).
--
-- 2. PRECONDITIONS (section A; any failure aborts the whole transaction)
--   P1 applying role is superuser or BYPASSRLS.
--   P2 KAN-712 stage B is live: the five trg_zz_kan712_* triggers exist and are enabled, kan712_wrapped_rpcs
--      is non-empty.
--   P3 KAN-713 is in: kan713_meetup_visible(uuid) exists and the six trg_kan713_* triggers exist.
--   P4 trg_events_search_tsv exists and is enabled (events.search_tsv is maintained).
--   P5 rpc_unified_search_sectioned has exactly one overload, md5(prosrc) = fe3382197842fa66564b2f62d9b754f5
--      (the baseline text), SECURITY DEFINER, proconfig {search_path=public}. A live body that differs from
--      the reviewed pre-image refuses (T-058).
--   P6 it is NOT in kan712_wrapped_rpcs and has no *_kan712_inner twin (unwrap/rewrap not required).
--   P7 not already applied (the new index does not exist).
--   P8 shared-value parity for every linked row: games.search_tsv/title/start_at/listing_visibility/
--      is_cancelled = events'; meetups title/start_at/listing_visibility/is_cancelled = events'. Zero rows
--      may differ, otherwise the result set could change at apply.
-- 3. CHANGES (section B): one CREATE INDEX, one CREATE OR REPLACE FUNCTION (body = pg_get_functiondef of the
--    pinned pre-image with only the games and meetups sub-selects edited; signature, return type, language,
--    SECURITY DEFINER, search_path, owner and ACL unchanged; CREATE OR REPLACE keeps the ACL).
-- 4. POSTCONDITIONS (section C)
--   Q1 owner, proacl, prosecdef, proconfig, provolatile equal the captured pre-image; md5 changed; still one
--      overload; body reads public.events.
--   Q2 the new index exists and is valid.
--   Q3 LIVE OUTPUT PARITY: for up to 40 probe words taken from current event titles and meetup
--      descriptions/location names (plus NULL, '', 'a', a no-match word), the pre-image output captured in
--      section A equals the new output (each section compared as a multiset, limit 1000 so no truncation);
--      an error before must be the same SQLSTATE after.
-- 5. LOCKS: SHARE ROW EXCLUSIVE on events, games, meetups for the transaction (blocks writes, not reads);
--    lock_timeout 10s. CREATE INDEX is not CONCURRENTLY because it runs inside this transaction; events is
--    one row per game/meetup.
-- 6. ROLLBACK: commented block at the end of this file. Restores the exact pre-image text and drops only the
--    index this file created. No unwrap/rewrap (F1 is not wrapped). Data is not touched.
-- ============================================================================================================

begin;
set local lock_timeout = '10s';
lock table public.events, public.games, public.meetups in share row exclusive mode;

-- A. Preconditions -------------------------------------------------------------------------------------------
create temp table kan724_pre (owner oid, acl aclitem[], secdef boolean, config text[], volatile "char", src_md5 text)
  on commit drop;
create temp table kan724_probe (q text, pre jsonb, post jsonb) on commit drop;

do $$
declare
  v_fn  regprocedure := to_regprocedure('public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)');
  v_n   bigint;
  v_md5 text;
begin
  -- P1
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'KAN-724: applying role % must be superuser or BYPASSRLS', current_user;
  end if;
  -- P2
  if (select count(*) from pg_trigger where not tgisinternal and tgenabled = 'O' and tgname in (
        'trg_zz_kan712_games_guard', 'trg_zz_kan712_meetups_guard', 'trg_zz_kan712_games_after_delete',
        'trg_zz_kan712_meetups_after_delete', 'trg_zz_kan712_events_compat_mirror')) <> 5
     or to_regclass('public.kan712_wrapped_rpcs') is null
     or not exists (select 1 from public.kan712_wrapped_rpcs) then
    raise exception 'KAN-724: KAN-712 stage B (20261103110000) is not live';
  end if;
  -- P3
  if to_regprocedure('public.kan713_meetup_visible(uuid)') is null
     or (select count(*) from pg_trigger where not tgisinternal and tgname like 'trg_kan713_%') <> 6 then
    raise exception 'KAN-724: KAN-713 (20261104100000, 20261104110000) is not applied';
  end if;
  -- P4
  if not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass
                  and tgname = 'trg_events_search_tsv' and tgenabled = 'O') then
    raise exception 'KAN-724: trg_events_search_tsv missing or disabled; events.search_tsv is not maintained';
  end if;
  -- P5
  if v_fn is null or (select count(*) from pg_proc where proname = 'rpc_unified_search_sectioned'
                       and pronamespace = 'public'::regnamespace) <> 1 then
    raise exception 'KAN-724: rpc_unified_search_sectioned: expected exactly one overload with the baseline signature';
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_fn;
  if v_md5 <> 'fe3382197842fa66564b2f62d9b754f5' then
    raise exception 'KAN-724: rpc_unified_search_sectioned live body differs from the reviewed pre-image (md5 %)', v_md5;
  end if;
  if not exists (select 1 from pg_proc where oid = v_fn and prosecdef and proconfig = array['search_path=public']) then
    raise exception 'KAN-724: rpc_unified_search_sectioned attributes differ from the pre-image (secdef/search_path)';
  end if;
  -- P6
  if exists (select 1 from public.kan712_wrapped_rpcs w where w.name = 'rpc_unified_search_sectioned')
     or exists (select 1 from pg_proc where proname = 'rpc_unified_search_sectioned_kan712_inner') then
    raise exception 'KAN-724: rpc_unified_search_sectioned is KAN-712-wrapped; use kan712_unwrap_rpc -> replace -> kan712_wrap_rpc';
  end if;
  -- P7
  if to_regclass('public.events_game_public_search_tsv_idx') is not null then
    raise exception 'KAN-724: already applied (events_game_public_search_tsv_idx exists)';
  end if;
  -- P8
  select count(*) into v_n from public.games g join public.events e on e.id = g.event_id
   where e.event_type <> 'game'
      or g.search_tsv is distinct from e.search_tsv or g.title is distinct from e.title
      or g.start_at is distinct from e.start_at or g.listing_visibility is distinct from e.listing_visibility
      or g.is_cancelled is distinct from e.is_cancelled;
  if v_n <> 0 then
    raise exception 'KAN-724: % games rows differ from events on a searched shared column', v_n;
  end if;
  select count(*) into v_n from public.meetups m join public.events e on e.id = m.event_id
   where e.event_type <> 'meetup'
      or m.title is distinct from e.title or m.start_at is distinct from e.start_at
      or m.listing_visibility is distinct from e.listing_visibility or m.is_cancelled is distinct from e.is_cancelled;
  if v_n <> 0 then
    raise exception 'KAN-724: % meetups rows differ from events on a searched shared column', v_n;
  end if;

  insert into kan724_pre select proowner, proacl, prosecdef, proconfig::text[], provolatile, md5(prosrc)
    from pg_proc where oid = v_fn;

  -- Probe words for Q3 (read-only).
  insert into kan724_probe(q)
  select w from (
    select distinct w from (
      select regexp_split_to_table(lower(coalesce(e.title, '')), '[^[:alnum:]]+') as w from public.events e
      union all
      select regexp_split_to_table(lower(coalesce(m.description, '') || ' ' || coalesce(m.location_name, '')), '[^[:alnum:]]+')
        from public.meetups m
    ) s where length(w) >= 2 order by w limit 40) t;
  insert into kan724_probe(q) values (null), (''), ('a'), ('zz_kan724_nomatch');
end $$;

do $$
declare r record; v jsonb;
begin
  for r in select ctid, q from kan724_probe loop
    begin
      v := public.rpc_unified_search_sectioned(r.q, null, null, null, null, 1000);
    exception when others then
      v := jsonb_build_object('error', sqlstate);
    end;
    update kan724_probe set pre = v where ctid = r.ctid;
  end loop;
end $$;

-- B. Changes ------------------------------------------------------------------------------------------------
create index events_game_public_search_tsv_idx on public.events using gin (search_tsv)
  where event_type = 'game' and listing_visibility = 'public' and is_cancelled = false;

CREATE OR REPLACE FUNCTION public.rpc_unified_search_sectioned(p_query text, p_sport_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_radius_km double precision DEFAULT NULL::double precision, p_limit_per_section integer DEFAULT 10)
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
        SELECT 'game' AS entity_type, e.id AS entity_id, e.title AS title,
          NULL::text AS subtitle, NULL::text AS image_url, '/game/' || e.id AS route,
          ts_rank(e.search_tsv, v_tsquery) + CASE WHEN e.start_at > NOW() THEN 0.2 ELSE 0 END AS score
        FROM public.events e
        JOIN public.games g ON g.event_id = e.id
        WHERE e.event_type = 'game' AND e.search_tsv @@ v_tsquery
          AND e.listing_visibility = 'public' AND e.is_cancelled = FALSE
          AND g.listing_visibility = 'public' AND g.is_cancelled = FALSE
        ORDER BY score DESC, e.start_at, e.id LIMIT p_limit_per_section) t),
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
        SELECT 'meetup' AS entity_type, e.id AS entity_id, e.title AS title,
          m.location_name AS subtitle, NULL::text AS image_url, '/meetup/' || e.id AS route,
          ts_rank(m.search_tsv, v_tsquery) AS score
        FROM public.meetups m
        JOIN public.events e ON e.id = m.event_id
        WHERE e.event_type = 'meetup' AND m.search_tsv @@ v_tsquery
          AND e.listing_visibility = 'public' AND e.is_cancelled = FALSE
          AND m.listing_visibility = 'public' AND m.is_cancelled = FALSE
        ORDER BY score DESC, e.start_at, e.id LIMIT p_limit_per_section) t),
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

-- C. Postconditions -----------------------------------------------------------------------------------------
do $$
declare
  v_fn regprocedure := to_regprocedure('public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)');
  p    record;
  r    record;
  v    jsonb;
  v_bad int := 0;
begin
  select * into p from kan724_pre;
  -- Q1
  if (select count(*) from pg_proc where proname = 'rpc_unified_search_sectioned' and pronamespace = 'public'::regnamespace) <> 1
     or not exists (select 1 from pg_proc where oid = v_fn
                     and proowner = p.owner and proacl is not distinct from p.acl and prosecdef = p.secdef
                     and proconfig::text[] is not distinct from p.config and provolatile = p.volatile
                     and md5(prosrc) <> p.src_md5 and prosrc like '%FROM public.events e%') then
    raise exception 'KAN-724 Q1: function attributes/ACL changed or body not replaced';
  end if;
  -- Q2
  if not exists (select 1 from pg_index where indexrelid = 'public.events_game_public_search_tsv_idx'::regclass
                  and indisvalid and indisready) then
    raise exception 'KAN-724 Q2: events_game_public_search_tsv_idx missing or invalid';
  end if;
  -- Q3
  for r in select ctid, q from kan724_probe loop
    begin
      v := public.rpc_unified_search_sectioned(r.q, null, null, null, null, 1000);
    exception when others then
      v := jsonb_build_object('error', sqlstate);
    end;
    update kan724_probe set post = v where ctid = r.ctid;
  end loop;
  select count(*) into v_bad from kan724_probe x
   where (select coalesce(jsonb_object_agg(k, case when jsonb_typeof(val) = 'array'
                    then (select coalesce(jsonb_agg(e order by e::text), '[]'::jsonb) from jsonb_array_elements(val) e)
                    else val end), '{}'::jsonb) from jsonb_each(x.pre) s(k, val))
     is distinct from
         (select coalesce(jsonb_object_agg(k, case when jsonb_typeof(val) = 'array'
                    then (select coalesce(jsonb_agg(e order by e::text), '[]'::jsonb) from jsonb_array_elements(val) e)
                    else val end), '{}'::jsonb) from jsonb_each(x.post) s(k, val));
  if v_bad <> 0 then
    raise exception 'KAN-724 Q3: % probe queries return a different result after the change', v_bad;
  end if;
  raise notice 'KAN-724 applied: Q1-Q3 ok, % probe queries identical', (select count(*) from kan724_probe);
end $$;

commit;

-- ============================================================================================================
-- ROLLBACK (run as postgres, one transaction). Restores the exact pre-image (pg_get_functiondef of the
-- baseline body, md5(prosrc) fe3382197842fa66564b2f62d9b754f5) and drops only the index this file created.
-- No unwrap/rewrap: rpc_unified_search_sectioned is not a KAN-712 wrapped RPC. CREATE OR REPLACE keeps the
-- owner and ACL. No data is touched (verified: per-table md5 hashes equal before/after, test R1).
-- ------------------------------------------------------------------------------------------------------------
-- begin;
-- set local lock_timeout = '10s';
-- do $$ begin
--   if to_regclass('public.events_game_public_search_tsv_idx') is null then
--     raise exception 'KAN-724 rollback: not applied';
--   end if;
-- end $$;
-- CREATE OR REPLACE FUNCTION public.rpc_unified_search_sectioned(p_query text, p_sport_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_radius_km double precision DEFAULT NULL::double precision, p_limit_per_section integer DEFAULT 10)
--  RETURNS jsonb
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
-- DECLARE
--   v_tsquery tsquery;
--   v_q       text;
-- BEGIN
--   IF p_query IS NULL OR length(trim(p_query)) < 2 THEN
--     RETURN jsonb_build_object(
--       'profiles','[]'::jsonb,'games','[]'::jsonb,'venues','[]'::jsonb,
--       'squads','[]'::jsonb,'posts','[]'::jsonb,'meetups','[]'::jsonb,
--       'challenges','[]'::jsonb,'hashtags','[]'::jsonb);
--   END IF;
--   v_tsquery := plainto_tsquery('simple', unaccent(p_query));
--   v_q       := '%' || lower(trim(p_query)) || '%';
--   RETURN jsonb_build_object(
--     'hashtags', (
--       SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
--         SELECT h.id, h.tag AS slug, h.display_tag, h.usage_count
--         FROM public.hashtags h
--         WHERE lower(h.tag) LIKE v_q
--           AND (h.is_banned IS NULL OR h.is_banned = false)
--           AND (h.is_searchable IS NULL OR h.is_searchable = true)
--           AND (h.is_approved IS NULL OR h.is_approved = true)
--         ORDER BY h.usage_count DESC NULLS LAST LIMIT p_limit_per_section) t),
--     'posts', (
--       SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
--         SELECT 'post' AS entity_type, p.id AS entity_id, left(p.body,80) AS title,
--           p.author_display_name AS subtitle, NULL::text AS image_url,
--           '/post/' || p.id AS route,
--           ts_rank(p.search_tsv, v_tsquery)
--           + (COALESCE(p.priority_score,0) * 0.01)
--           + (SELECT COUNT(*) * 0.05 FROM public.comments pc
--              WHERE pc.parent_activity_id = p.id
--                AND pc.search_tsv @@ v_tsquery
--                AND pc.is_deleted = FALSE AND pc.is_hidden_admin = FALSE) AS score
--         FROM public.posts p
--         WHERE p.search_tsv @@ v_tsquery AND p.visibility = 'public'
--           AND p.is_deleted = FALSE AND p.is_hidden_admin = FALSE AND p.is_active = TRUE
--         ORDER BY score DESC LIMIT p_limit_per_section) t),
--     'profiles', (
--       SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
--         SELECT 'profile' AS entity_type, p.user_id AS entity_id, p.id AS profile_id,
--           p.display_name AS title, p.username AS subtitle, p.avatar_url AS image_url,
--           p.persona_type AS profile_type, p.is_active, '/profile/' || p.username AS route,
--           ts_rank(p.search_tsv, v_tsquery) AS score
--         FROM public.profiles p WHERE p.search_tsv @@ v_tsquery
--         ORDER BY score DESC LIMIT p_limit_per_section) t),
--     'games', (
--       SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
--         SELECT 'game' AS entity_type, g.id AS entity_id, g.title AS title,
--           NULL::text AS subtitle, NULL::text AS image_url, '/game/' || g.id AS route,
--           ts_rank(g.search_tsv, v_tsquery) + CASE WHEN g.start_at > NOW() THEN 0.2 ELSE 0 END AS score
--         FROM public.games g
--         WHERE g.search_tsv @@ v_tsquery AND g.listing_visibility = 'public' AND g.is_cancelled = FALSE
--         ORDER BY score DESC LIMIT p_limit_per_section) t),
--     'venues', (
--       SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
--         SELECT 'venue' AS entity_type, v.id AS entity_id, v.name_en AS title,
--           v.area AS subtitle, NULL::text AS image_url, '/venue/' || v.id AS route,
--           ts_rank(v.search_tsv, v_tsquery) + (COALESCE(v.rating,0) * 0.05) AS score
--         FROM public.venues v WHERE v.search_tsv @@ v_tsquery AND v.is_active = TRUE
--         ORDER BY score DESC LIMIT p_limit_per_section) t),
--     'squads', (
--       SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
--         SELECT 'squad' AS entity_type, s.id AS entity_id, s.name AS title,
--           s.city AS subtitle, s.logo_url AS image_url, '/squad/' || s.id AS route,
--           ts_rank(s.search_tsv, v_tsquery) AS score
--         FROM public.squads s WHERE s.search_tsv @@ v_tsquery AND s.is_active = TRUE
--         ORDER BY score DESC LIMIT p_limit_per_section) t),
--     'meetups', (
--       SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
--         SELECT 'meetup' AS entity_type, m.id AS entity_id, m.title AS title,
--           m.location_name AS subtitle, NULL::text AS image_url, '/meetup/' || m.id AS route,
--           ts_rank(m.search_tsv, v_tsquery) AS score
--         FROM public.meetups m WHERE m.search_tsv @@ v_tsquery
--           AND m.listing_visibility = 'public' AND m.is_cancelled = FALSE
--         ORDER BY score DESC LIMIT p_limit_per_section) t),
--     'challenges', (
--       SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
--         SELECT 'challenge' AS entity_type, c.id AS entity_id, c.title AS title,
--           c.status AS subtitle, NULL::text AS image_url, '/challenge/' || c.id AS route,
--           ts_rank(c.search_tsv, v_tsquery) AS score
--         FROM public.challenges c WHERE c.search_tsv @@ v_tsquery AND c.is_active = TRUE
--         ORDER BY score DESC LIMIT p_limit_per_section) t)
--   );
-- END;
-- $function$;
-- drop index public.events_game_public_search_tsv_idx;
-- do $$ begin
--   if (select md5(prosrc) from pg_proc where oid = to_regprocedure('public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'))
--      <> 'fe3382197842fa66564b2f62d9b754f5' then
--     raise exception 'KAN-724 rollback: pre-image not restored';
--   end if;
-- end $$;
-- commit;
