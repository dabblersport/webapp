-- KAN-592 rollback (AUTHORED, NOT RUN; an APPLY that Operations runs). Drops only the two columns this ticket added.
-- Posts keep every other column; posts written since lose their recorded posting city (they render as legacy Dubai).
ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_posted_from_city_not_blank;
ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_posted_from_area_not_blank;
ALTER TABLE public.posts DROP COLUMN IF EXISTS posted_from_city;
ALTER TABLE public.posts DROP COLUMN IF EXISTS posted_from_area;
