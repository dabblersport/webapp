-- Add media, GIF, and location support to post_comments
ALTER TABLE public.post_comments
  ADD COLUMN IF NOT EXISTS image_url   TEXT,
  ADD COLUMN IF NOT EXISTS gif_url     TEXT,
  ADD COLUMN IF NOT EXISTS location_name TEXT,
  ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION;

-- Index for quick lookup of comments with media (optional, for moderation/feed)
CREATE INDEX IF NOT EXISTS idx_post_comments_has_media
  ON public.post_comments (post_id)
  WHERE image_url IS NOT NULL OR gif_url IS NOT NULL;
