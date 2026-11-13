-- KAN-926: minimum supported app build per platform; clients below min_build are forced to update.
-- Read by anon and authenticated (the gate runs before sign-in). Written only by SQL / service_role.
-- Applied live 2026-11-13 as version 20261113050426 (20261113100000 is taken by kan718_game_write_helpers).
-- ios store_url is null: the numeric App Store id is not in the repo.
CREATE TABLE public.app_min_versions (
  platform   text PRIMARY KEY CHECK (platform IN ('web', 'ios', 'android')),
  min_build  integer NOT NULL CHECK (min_build >= 0),
  store_url  text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_min_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_min_versions_select ON public.app_min_versions
  FOR SELECT TO anon, authenticated USING (true);

REVOKE ALL ON public.app_min_versions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.app_min_versions TO anon, authenticated;
GRANT ALL ON public.app_min_versions TO service_role;

CREATE TRIGGER trg_app_min_versions_touch_updated_at
  BEFORE UPDATE ON public.app_min_versions
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

INSERT INTO public.app_min_versions (platform, min_build, store_url) VALUES
  ('web',     0, NULL),
  ('ios',     0, NULL),
  ('android', 0, 'https://play.google.com/store/apps/details?id=com.dabbler.dabblerapp');
