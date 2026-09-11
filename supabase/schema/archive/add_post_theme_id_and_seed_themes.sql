-- =============================================================================
-- Migration: Add post_theme_id to posts + seed system themes
-- =============================================================================

-- STEP 1: Add column
ALTER TABLE public.posts
ADD COLUMN IF NOT EXISTS post_theme_id uuid NULL;

-- STEP 2: Add foreign key
ALTER TABLE public.posts
ADD CONSTRAINT posts_post_theme_id_fkey
FOREIGN KEY (post_theme_id)
REFERENCES public.post_themes (id)
ON DELETE SET NULL;

-- STEP 3: Seed default system themes
INSERT INTO public.post_themes (
  name,
  background_type,
  background_color,
  gradient_start,
  gradient_end,
  font_style,
  is_system
)
VALUES
  ('System Default', 'color', '#1E1E1E', null, null, 'bold', true),
  ('Announcement',  'gradient', null, '#FF7A18', '#FFB347', 'bold', true),
  ('News',          'gradient', null, '#2193b0', '#6dd5ed', 'regular', true);

-- STEP 4: Update create_system_post to auto-assign a system theme
-- (Apply this change to the existing create_system_post function body)
--
-- DECLARE v_theme_id uuid;
--
-- SELECT id INTO v_theme_id
-- FROM public.post_themes
-- WHERE is_system = true
-- ORDER BY created_at ASC
-- LIMIT 1;
--
-- Then include in the INSERT: post_theme_id = v_theme_id
