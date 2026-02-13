-- Add tags column to posts table for sport/activity tagging
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}';

-- Index for efficient tag searches (GIN index on array column)
CREATE INDEX IF NOT EXISTS idx_posts_tags ON public.posts USING GIN (tags);

COMMENT ON COLUMN public.posts.tags IS 'Array of sport/activity tags attached to the post (e.g. Football, Basketball)';
