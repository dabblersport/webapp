-- KAN-592 probes (read-only; run after the migration is applied).
-- P1: both columns exist and are nullable text. Expect 2 rows.
SELECT column_name, data_type, is_nullable FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'posts' AND column_name IN ('posted_from_city', 'posted_from_area');
-- P2: old rows were not rewritten. Expect 0.
SELECT count(*) FROM public.posts WHERE posted_from_city IS NOT NULL AND created_at < '2026-10-21';
-- P3: no blank city. Expect 0.
SELECT count(*) FROM public.posts WHERE posted_from_city IS NOT NULL AND btrim(posted_from_city) = '';
-- P4: tagged places are untouched by the migration. Expect the same count as before applying.
SELECT count(*) FROM public.posts WHERE location_name IS NOT NULL;
