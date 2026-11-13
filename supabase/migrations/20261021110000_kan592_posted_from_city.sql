-- KAN-592: a post records WHERE ITS AUTHOR POSTED FROM, separate from the place the post is about.
--
-- STATUS: AUTHORED, NOT APPLIED. Nothing here was run against any database. Operations applies it
-- (execute_sql only, never apply_migration, test data only; rollback in supabase/tests/kan592_posted_from/rollback.sql).
--
-- What it does (additive only, nothing is rewritten or dropped):
--   1. posts.posted_from_city  text  -- the author's posting city, set by the app on every new post.
--   2. posts.posted_from_area  text  -- the author's area when one is known; NULL otherwise, never invented.
--
-- Legacy marker. A row with posted_from_city IS NULL is a LEGACY post (written before this column existed, or by
-- an older client). The app shows such a row as "Dubai" (CEO ruling). Old rows are NOT backfilled, so the marker
-- stays reliable: NULL means "never recorded", and a post that was about an Abu Dhabi venue keeps its own
-- location_name tag untouched. The venue / place tag lives in location_name / venue_id / geo_* and is never
-- read as the posting city.
-- Non-circle posts are inserted directly into public.posts, so these columns need no function change. The circle
-- path (create_post RPC) is followed by an UPDATE of the author's own row by the app.

ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS posted_from_city text;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS posted_from_area text;

COMMENT ON COLUMN public.posts.posted_from_city IS 'KAN-592: city the author posted from. NULL = legacy row (rendered as Dubai). Independent of location_name / venue_id (the place the post is about).';
COMMENT ON COLUMN public.posts.posted_from_area IS 'KAN-592: area the author posted from, when known. NULL = not known; never defaulted.';

-- Blank strings are not a city: NULL stays the only "not recorded" value. NOT VALID so old rows are never scanned.
ALTER TABLE public.posts ADD CONSTRAINT posts_posted_from_city_not_blank CHECK (posted_from_city IS NULL OR btrim(posted_from_city) <> '') NOT VALID;
ALTER TABLE public.posts ADD CONSTRAINT posts_posted_from_area_not_blank CHECK (posted_from_area IS NULL OR btrim(posted_from_area) <> '') NOT VALID;
