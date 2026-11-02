-- KAN-671: Recurring games B1 (CTO ruling T-099). AUTHORED, NOT APPLIED. Team Habu.
--
-- Additive only: one new table (game_series) and one nullable column on games (series_id).
-- Occurrences stay ordinary games rows; existing rows keep series_id = NULL, nothing is rewritten.
-- Rollback: supabase/tests/game_series/rollback.sql. Probes: supabase/tests/game_series/probes.sql.
--
-- READ PATH (finding, see supabase/tests/game_series/GAME_SERIES.md): public.games has RLS enabled and
-- NO policy (baseline 20260829080500 ENABLE ROW LEVEL SECURITY, no CREATE POLICY ... ON games anywhere
-- in supabase/migrations). Reads go through SECURITY DEFINER RPCs and views owned by postgres, not
-- through row policies. This migration therefore does not touch games RLS at all and gives
-- game_series its own owner-only SELECT policy, which does not depend on games.

CREATE TABLE IF NOT EXISTS public.game_series (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  creator_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  creator_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sport_id uuid NOT NULL REFERENCES public.sports(id),
  venue_id uuid REFERENCES public.venues(id) ON DELETE SET NULL,
  venue_space_id uuid REFERENCES public.venue_spaces(id) ON DELETE SET NULL,
  geo_location_id uuid NOT NULL REFERENCES public.geo_locations(id),
  area_id uuid NOT NULL REFERENCES public.areas(id),
  -- Template fields: copied onto each materialised games row.
  title text,
  game_type text NOT NULL DEFAULT 'casual'
    CHECK (game_type IN ('pickup', 'training', 'league', 'hosted', 'casual')),
  capacity integer NOT NULL CHECK (capacity >= 2 AND capacity <= 64),
  listing_visibility text NOT NULL DEFAULT 'public'
    CHECK (listing_visibility IN ('public', 'followers', 'private')),
  join_policy text NOT NULL DEFAULT 'open'
    CHECK (join_policy IN ('open', 'request', 'invite', 'link', 'circle', 'squad', 'closed')),
  start_time_local time NOT NULL,
  duration_minutes integer NOT NULL CHECK (duration_minutes > 0 AND duration_minutes <= 1440),
  -- RFC 5545 recurrence, weekly or biweekly only for v1.
  rrule text NOT NULL
    CHECK (rrule ~ '^FREQ=WEEKLY(;INTERVAL=[12])?(;BYDAY=(MO|TU|WE|TH|FR|SA|SU)(,(MO|TU|WE|TH|FR|SA|SU))*)?$'),
  timezone text NOT NULL,
  starts_on date NOT NULL,
  ends_on date,
  occurrences_ahead integer NOT NULL DEFAULT 4 CHECK (occurrences_ahead >= 1 AND occurrences_ahead <= 12),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'ended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id),
  CONSTRAINT game_series_dates_check CHECK (ends_on IS NULL OR ends_on >= starts_on)
);

COMMENT ON TABLE public.game_series IS 'KAN-671 / T-099: a recurring-game template. Upcoming occurrences are ordinary games rows with games.series_id = this id.';

CREATE INDEX IF NOT EXISTS game_series_creator_user_id_idx ON public.game_series (creator_user_id);

ALTER TABLE public.game_series ENABLE ROW LEVEL SECURITY;

-- Owner reads their own series. No insert/update/delete policy and no write grant: series are
-- written by SECURITY DEFINER RPCs in the follow-up stories, as with games.
CREATE POLICY game_series_select_owner
  ON public.game_series FOR SELECT TO authenticated
  USING (creator_user_id = (SELECT auth.uid()));

REVOKE ALL ON public.game_series FROM PUBLIC, anon;
REVOKE ALL ON public.game_series FROM authenticated;
GRANT SELECT ON public.game_series TO authenticated;
GRANT ALL ON public.game_series TO service_role;

-- Nullable link from a game to its series. Existing rows stay NULL. SET NULL keeps a game alive
-- if its series row is ever removed.
ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS series_id uuid REFERENCES public.game_series(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.games.series_id IS 'KAN-671 / T-099: the recurring series this game was materialised from; NULL for one-off games.';

CREATE INDEX IF NOT EXISTS games_series_id_idx ON public.games (series_id) WHERE series_id IS NOT NULL;
