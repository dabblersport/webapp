-- KAN-714 PROVENANCE: corrupt the LEGACY shared columns on games/meetups with all triggers disabled
-- (session_replication_role = replica: the KAN-712 guards, KAN-713 triggers and FK triggers do not fire),
-- leaving public.events untouched. DISPOSABLE COPY ONLY — this COMMITs.
--
-- Afterwards snapshot_kan714.sql on the corrupted copy must equal the snapshot on the uncorrupted database
-- for every repointed reader: each one must be reading public.events, not the legacy mirror.
-- On a pre-KAN-714 copy the same comparison must FAIL (observed: KAN714_CONTRACT.md section 4).
\set ON_ERROR_STOP 1
BEGIN;
DO $c$ BEGIN
  IF current_database() !~ '^k71[34][a-z]*c$' THEN
    RAISE EXCEPTION 'corrupt_legacy_kan714: refusing to run on database % (disposable copies end in c)', current_database();
  END IF;
END $c$;
SET LOCAL session_replication_role = replica;

-- Every shared column changes; events keeps the true values.
UPDATE public.games SET
  title              = coalesce(title, '') || ' #LEGACY',
  capacity           = CASE WHEN capacity <= 32 THEN capacity + 30 ELSE capacity - 30 END,
  start_at           = start_at + interval '400 days',
  end_at             = end_at + interval '400 days',
  listing_visibility = CASE listing_visibility WHEN 'public' THEN 'private' ELSE 'public' END,
  join_policy        = CASE join_policy WHEN 'open' THEN 'invite' ELSE 'open' END,
  is_cancelled       = NOT is_cancelled,
  creator_user_id    = '00000000-0000-0000-0000-0000000000a9',
  creator_profile_id = '00000000-0000-0000-0000-0000000000b2',
  min_skill          = NULL,
  max_skill          = NULL,
  sport_id           = '00000000-0000-0000-0000-0000000000e2',
  area_id            = (SELECT a.id FROM public.areas a WHERE a.id <> games.area_id ORDER BY a.id LIMIT 1),
  venue_id           = NULL,
  created_at         = created_at - interval '3 years',
  updated_at         = updated_at - interval '3 years';

UPDATE public.meetups SET
  title              = title || ' #LEGACY',
  capacity           = coalesce(capacity, 0) + 100,
  start_at           = start_at + interval '400 days',
  end_at             = end_at + interval '400 days',
  listing_visibility = CASE listing_visibility WHEN 'public' THEN 'hidden' ELSE 'public' END,
  rsvp_policy        = CASE rsvp_policy WHEN 'open' THEN 'closed' ELSE 'open' END,
  is_cancelled       = NOT is_cancelled,
  creator_user_id    = '00000000-0000-0000-0000-0000000000a9',
  creator_profile_id = '00000000-0000-0000-0000-0000000000b2',
  min_skill          = NULL,
  max_skill          = NULL,
  sport_id           = NULL,
  area_id            = NULL,
  venue_id           = NULL,
  created_at         = created_at - interval '3 years',
  updated_at         = updated_at - interval '3 years';

-- Proof the corruption happened and events was not touched.
SELECT 'CORRUPT|games_diverged=' || count(*) FILTER (WHERE g.title IS DISTINCT FROM e.title AND g.listing_visibility <> e.listing_visibility
                                                         AND g.creator_user_id <> e.creator_user_id AND g.start_at <> e.start_at)
       || '|of=' || count(*)
  FROM public.games g JOIN public.events e ON e.id = g.event_id;
SELECT 'CORRUPT|meetups_diverged=' || count(*) FILTER (WHERE m.title <> e.title AND m.listing_visibility <> e.listing_visibility
                                                         AND m.creator_user_id <> e.creator_user_id AND m.start_at <> e.start_at)
       || '|of=' || count(*)
  FROM public.meetups m JOIN public.events e ON e.id = m.event_id;
COMMIT;
