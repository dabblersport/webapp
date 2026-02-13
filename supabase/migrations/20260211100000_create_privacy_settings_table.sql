-- ============================================================================
-- Privacy Settings Table
-- Stores per-user privacy preferences, referenced by PrivacySettingsModel
-- ============================================================================

-- 1. Create table
CREATE TABLE IF NOT EXISTS public.privacy_settings (
  user_id        UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Profile & Identity
  profile_visibility       INTEGER NOT NULL DEFAULT 0,   -- 0=public, 1=friends, 2=private
  show_real_name           BOOLEAN NOT NULL DEFAULT true,
  show_age                 BOOLEAN NOT NULL DEFAULT false,
  show_location            BOOLEAN NOT NULL DEFAULT true,
  show_phone               BOOLEAN NOT NULL DEFAULT false,
  show_email               BOOLEAN NOT NULL DEFAULT false,
  show_bio                 BOOLEAN NOT NULL DEFAULT true,
  show_profile_photo       BOOLEAN NOT NULL DEFAULT true,
  show_friends_list        BOOLEAN NOT NULL DEFAULT false,
  allow_profile_indexing   BOOLEAN NOT NULL DEFAULT true,

  -- Activity & Stats
  show_stats               BOOLEAN NOT NULL DEFAULT true,
  show_sports_profiles     BOOLEAN NOT NULL DEFAULT true,
  show_game_history        BOOLEAN NOT NULL DEFAULT true,
  show_achievements        BOOLEAN NOT NULL DEFAULT true,
  show_online_status       BOOLEAN NOT NULL DEFAULT true,
  show_activity_status     BOOLEAN NOT NULL DEFAULT true,
  show_check_ins           BOOLEAN NOT NULL DEFAULT true,
  show_posts_to_public     BOOLEAN NOT NULL DEFAULT true,

  -- Communication
  message_preference         INTEGER NOT NULL DEFAULT 0,   -- CommunicationPreference index
  game_invite_preference     INTEGER NOT NULL DEFAULT 0,
  friend_request_preference  INTEGER NOT NULL DEFAULT 0,

  -- Notifications
  allow_push_notifications   BOOLEAN NOT NULL DEFAULT true,
  allow_email_notifications  BOOLEAN NOT NULL DEFAULT true,

  -- Data & Analytics
  allow_location_tracking    BOOLEAN NOT NULL DEFAULT true,
  allow_data_analytics       BOOLEAN NOT NULL DEFAULT true,
  data_sharing_level         INTEGER NOT NULL DEFAULT 1,  -- 0=full, 1=limited, 2=minimal
  allow_game_recommendations BOOLEAN NOT NULL DEFAULT true,
  hide_from_nearby           BOOLEAN NOT NULL DEFAULT false,

  -- Security
  two_factor_enabled         BOOLEAN NOT NULL DEFAULT false,
  login_alerts               BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Enable RLS
ALTER TABLE public.privacy_settings ENABLE ROW LEVEL SECURITY;

-- 3. RLS policies — users can read/write their own row
DROP POLICY IF EXISTS "Users can view own privacy settings" ON public.privacy_settings;
CREATE POLICY "Users can view own privacy settings"
  ON public.privacy_settings FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own privacy settings" ON public.privacy_settings;
CREATE POLICY "Users can insert own privacy settings"
  ON public.privacy_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own privacy settings" ON public.privacy_settings;
CREATE POLICY "Users can update own privacy settings"
  ON public.privacy_settings FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 4. Auto-update updated_at
CREATE OR REPLACE FUNCTION public.update_privacy_settings_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_privacy_settings_updated ON public.privacy_settings;
CREATE TRIGGER trg_privacy_settings_updated
  BEFORE UPDATE ON public.privacy_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_privacy_settings_timestamp();

-- 5. Auto-create default row on user signup
CREATE OR REPLACE FUNCTION public.create_default_privacy_settings()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.privacy_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Only create trigger if it doesn't already exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_create_default_privacy_settings'
  ) THEN
    CREATE TRIGGER trg_create_default_privacy_settings
      AFTER INSERT ON auth.users
      FOR EACH ROW
      EXECUTE FUNCTION public.create_default_privacy_settings();
  END IF;
END $$;

-- 6. Backfill existing users who don't have a row yet
INSERT INTO public.privacy_settings (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM public.privacy_settings)
ON CONFLICT (user_id) DO NOTHING;
