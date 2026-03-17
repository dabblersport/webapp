-- Allows hashtag-only body text in posts.
-- Run this migration if product behavior should match Twitter-like hashtag posts.

alter table if exists public.posts
drop constraint if exists posts_body_has_non_hashtag_word;

-- Optional replacement constraint:
-- body can be null/empty or contain any non-whitespace character.
-- Uncomment if you still want a minimal body shape check.
-- alter table public.posts
-- add constraint posts_body_has_content
-- check (body is null or length(trim(body)) > 0);
