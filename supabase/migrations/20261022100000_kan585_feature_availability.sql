-- KAN-585: remote feature availability per service region.
-- AUTHORED, NOT APPLIED. Team Habu.
--
-- Maps stable feature ids to the KAN-584 service regions plus 'Global'.
-- Read-only for signed-in accounts; edited only by service_role / migration.
-- The app reads it through get_feature_availability(), which resolves the
-- caller's region from public.account_service_region (never GPS/IP) and falls
-- back to 'Global' when the account has no row.

CREATE TABLE IF NOT EXISTS public.feature_availability (
  feature_id text NOT NULL
    CHECK (feature_id ~ '^[a-z][a-z0-9_]{1,63}$'),
  region text NOT NULL
    CHECK (region IN ('Egypt', 'Morocco', 'Qatar', 'Saudi Arabia',
                      'United Arab Emirates', 'Global')),
  enabled boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (feature_id, region)
);

ALTER TABLE public.feature_availability ENABLE ROW LEVEL SECURITY;

CREATE POLICY feature_availability_select_authenticated
  ON public.feature_availability FOR SELECT TO authenticated
  USING (true);

REVOKE ALL ON public.feature_availability FROM PUBLIC, anon;
GRANT SELECT ON public.feature_availability TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.feature_availability FROM authenticated;
GRANT ALL ON public.feature_availability TO service_role;

CREATE OR REPLACE FUNCTION public.get_feature_availability()
RETURNS TABLE (feature_id text, enabled boolean)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $fn$
  SELECT fa.feature_id, fa.enabled
  FROM public.feature_availability fa
  WHERE fa.region = COALESCE(
    (SELECT asr.region FROM public.account_service_region asr
     WHERE asr.user_id = auth.uid()),
    'Global')
  ORDER BY fa.feature_id;
$fn$;

REVOKE EXECUTE ON FUNCTION public.get_feature_availability() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_feature_availability() TO authenticated;

INSERT INTO public.feature_availability (feature_id, region, enabled) VALUES
  ('meetups', 'Egypt', true),
  ('meetups', 'Morocco', true),
  ('meetups', 'Qatar', true),
  ('meetups', 'Saudi Arabia', true),
  ('meetups', 'United Arab Emirates', true),
  ('meetups', 'Global', true),
  ('favourites', 'Egypt', true),
  ('favourites', 'Morocco', true),
  ('favourites', 'Qatar', true),
  ('favourites', 'Saudi Arabia', true),
  ('favourites', 'United Arab Emirates', true),
  ('favourites', 'Global', true),
  ('game_browsing', 'Egypt', true),
  ('game_browsing', 'Morocco', true),
  ('game_browsing', 'Qatar', true),
  ('game_browsing', 'Saudi Arabia', true),
  ('game_browsing', 'United Arab Emirates', true),
  ('game_browsing', 'Global', true),
  ('player_game_creation', 'Egypt', true),
  ('player_game_creation', 'Morocco', true),
  ('player_game_creation', 'Qatar', true),
  ('player_game_creation', 'Saudi Arabia', true),
  ('player_game_creation', 'United Arab Emirates', true),
  ('player_game_creation', 'Global', true),
  ('organiser_game_creation', 'Egypt', true),
  ('organiser_game_creation', 'Morocco', true),
  ('organiser_game_creation', 'Qatar', true),
  ('organiser_game_creation', 'Saudi Arabia', true),
  ('organiser_game_creation', 'United Arab Emirates', true),
  ('organiser_game_creation', 'Global', true),
  ('player_game_joining', 'Egypt', true),
  ('player_game_joining', 'Morocco', true),
  ('player_game_joining', 'Qatar', true),
  ('player_game_joining', 'Saudi Arabia', true),
  ('player_game_joining', 'United Arab Emirates', true),
  ('player_game_joining', 'Global', true),
  ('organiser_game_joining', 'Egypt', true),
  ('organiser_game_joining', 'Morocco', true),
  ('organiser_game_joining', 'Qatar', true),
  ('organiser_game_joining', 'Saudi Arabia', true),
  ('organiser_game_joining', 'United Arab Emirates', true),
  ('organiser_game_joining', 'Global', true),
  ('social_feed', 'Egypt', true),
  ('social_feed', 'Morocco', true),
  ('social_feed', 'Qatar', true),
  ('social_feed', 'Saudi Arabia', true),
  ('social_feed', 'United Arab Emirates', true),
  ('social_feed', 'Global', true),
  ('messaging', 'Egypt', true),
  ('messaging', 'Morocco', true),
  ('messaging', 'Qatar', true),
  ('messaging', 'Saudi Arabia', true),
  ('messaging', 'United Arab Emirates', true),
  ('messaging', 'Global', true),
  ('messaging_game_chat', 'Egypt', true),
  ('messaging_game_chat', 'Morocco', true),
  ('messaging_game_chat', 'Qatar', true),
  ('messaging_game_chat', 'Saudi Arabia', true),
  ('messaging_game_chat', 'United Arab Emirates', true),
  ('messaging_game_chat', 'Global', true),
  ('messaging_direct', 'Egypt', true),
  ('messaging_direct', 'Morocco', true),
  ('messaging_direct', 'Qatar', true),
  ('messaging_direct', 'Saudi Arabia', true),
  ('messaging_direct', 'United Arab Emirates', true),
  ('messaging_direct', 'Global', true),
  ('messaging_reporting', 'Egypt', true),
  ('messaging_reporting', 'Morocco', true),
  ('messaging_reporting', 'Qatar', true),
  ('messaging_reporting', 'Saudi Arabia', true),
  ('messaging_reporting', 'United Arab Emirates', true),
  ('messaging_reporting', 'Global', true),
  ('messaging_realtime', 'Egypt', true),
  ('messaging_realtime', 'Morocco', true),
  ('messaging_realtime', 'Qatar', true),
  ('messaging_realtime', 'Saudi Arabia', true),
  ('messaging_realtime', 'United Arab Emirates', true),
  ('messaging_realtime', 'Global', true),
  ('notifications', 'Egypt', true),
  ('notifications', 'Morocco', true),
  ('notifications', 'Qatar', true),
  ('notifications', 'Saudi Arabia', true),
  ('notifications', 'United Arab Emirates', true),
  ('notifications', 'Global', true),
  ('multi_sport', 'Egypt', true),
  ('multi_sport', 'Morocco', true),
  ('multi_sport', 'Qatar', true),
  ('multi_sport', 'Saudi Arabia', true),
  ('multi_sport', 'United Arab Emirates', true),
  ('multi_sport', 'Global', true),
  ('organiser_profile', 'Egypt', true),
  ('organiser_profile', 'Morocco', true),
  ('organiser_profile', 'Qatar', true),
  ('organiser_profile', 'Saudi Arabia', true),
  ('organiser_profile', 'United Arab Emirates', true),
  ('organiser_profile', 'Global', true),
  ('venues_booking', 'Egypt', true),
  ('venues_booking', 'Morocco', true),
  ('venues_booking', 'Qatar', true),
  ('venues_booking', 'Saudi Arabia', true),
  ('venues_booking', 'United Arab Emirates', true),
  ('venues_booking', 'Global', true),
  ('booking_flow', 'Egypt', true),
  ('booking_flow', 'Morocco', true),
  ('booking_flow', 'Qatar', true),
  ('booking_flow', 'Saudi Arabia', true),
  ('booking_flow', 'United Arab Emirates', true),
  ('booking_flow', 'Global', true)
ON CONFLICT (feature_id, region) DO NOTHING;
