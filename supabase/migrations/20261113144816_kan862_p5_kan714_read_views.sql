-- KAN-862 P5 (Z01 gate G6): public.kan714_games_read and public.kan714_meetups_read stop reading
-- games.search_tsv / meetups.search_tsv, which Z01 (20261105100000_kan719_z01_remove_replaced_columns.sql) drops.
-- Re-authored from the live pg_get_viewdef (2026-11-13). Definition only: no data writes, no grant change.
-- CREATE OR REPLACE VIEW keeps owner (postgres), relacl ({postgres=arwdDxtm/postgres}) and reloptions (none).
-- Column names, order and types are unchanged (36 / 30); only the source of search_tsv moves:
--   kan714_games_read.search_tsv   <- events.search_tsv (events_set_search_tsv: to_tsvector('simple', unaccent(title)),
--                                     the same value trg_games_set_search_tsv wrote; equal on every live row)
--   kan714_meetups_read.search_tsv <- title(A) || description(B) || location_name(C), the exact expression of
--                                     meetups_search_tsv_trigger, from events.title and the retained meetups columns
--                                     description / location_name (equal on every live row; events.search_tsv is
--                                     title-only for meetups and differs, so it is not used).
-- Consumers of search_tsv: rpc_search_entities (gm.search_tsv from kan714_games_read),
-- rpc_unified_search_sectioned (m.search_tsv from kan714_meetups_read).
-- Test: supabase/tests/events_p4/kan862_p5_kan714_read_views_test.sql

DO $pre$
BEGIN
  IF md5(pg_get_viewdef('public.kan714_games_read'::regclass)) <> 'e1a3b95b4ef5754c36bdf2f868dd2340' THEN
    RAISE EXCEPTION 'KAN-862 P5: live kan714_games_read is not the recorded pre-image; re-author from pg_get_viewdef';
  END IF;
  IF md5(pg_get_viewdef('public.kan714_meetups_read'::regclass)) <> 'b2dc91ab9731af9a6196241d28c2e6a8' THEN
    RAISE EXCEPTION 'KAN-862 P5: live kan714_meetups_read is not the recorded pre-image; re-author from pg_get_viewdef';
  END IF;
END $pre$;

CREATE OR REPLACE VIEW public.kan714_games_read AS
 SELECT g.id,
    g.game_type,
    e.title,
    e.creator_profile_id,
    e.creator_user_id,
    g.venue_space_id,
    e.start_at,
    e.end_at,
    e.capacity,
    e.listing_visibility,
    e.join_policy,
    g.allow_spectators,
    (e.min_skill)::integer AS min_skill,
    (e.max_skill)::integer AS max_skill,
    g.rules,
    e.is_cancelled,
    e.cancelled_at,
    e.cancelled_reason,
    e.created_at,
    e.updated_at,
    g.squad_id,
    e.search_tsv,
    g.sport_specific_data,
    g.allows_waitlist,
    e.sport_id,
    e.geo_location_id,
    e.area_id,
    e.venue_id,
    g.sport_variant_id,
    g.bench_slots,
    e.joining_rule,
    e.cost_cover,
    g.price_aed,
    e.request_id,
    g.series_id,
    g.event_id
   FROM (games g
     JOIN events e ON (((e.id = g.event_id) AND (e.event_type = 'game'::text))));

CREATE OR REPLACE VIEW public.kan714_meetups_read AS
 SELECT m.id,
    e.creator_profile_id,
    e.creator_user_id,
    e.title,
    m.description,
    m.vibe_key,
    e.listing_visibility,
    e.join_policy AS rsvp_policy,
    e.capacity,
    e.start_at,
    e.end_at,
    e.is_cancelled,
    m.meta,
    e.created_at,
    e.updated_at,
    m.host_actor_id,
    ((setweight(to_tsvector('simple'::regconfig, COALESCE(e.title, ''::text)), 'A'::"char")
      || setweight(to_tsvector('simple'::regconfig, COALESCE(m.description, ''::text)), 'B'::"char"))
      || setweight(to_tsvector('simple'::regconfig, COALESCE(m.location_name, ''::text)), 'C'::"char")) AS search_tsv,
    e.geo_location_id,
    e.sport_id,
    e.area_id,
    e.venue_id,
    (e.min_skill)::integer AS min_skill,
    (e.max_skill)::integer AS max_skill,
    m.members_only,
    e.joining_rule,
    e.cost_cover,
    m.location_name,
    m.is_indoor,
    e.request_id,
    m.event_id
   FROM (meetups m
     JOIN events e ON (((e.id = m.event_id) AND (e.event_type = 'meetup'::text))));
