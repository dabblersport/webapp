# Task 20 — Flutter: Fix broken DB refs + comments/likes/reactions + unified feed

You are planning updates to an existing Flutter app (Riverpod + GoRouter + Supabase + Freezed). The Supabase schema changed. Plan what to update — no code, no steps, just describe the target architecture.

---

## DB changes to know

- `post_comments` renamed to `comments`. FK column `post_id` renamed to `parent_activity_id`. `parent_activity_id` is a UUID referencing `public_activities.id`, so comments now work on posts, news, or any other activity type.
- `post_likes` dropped. Replaced by `likes (id, parent_activity_id, profile_id, actor_user_id, created_at)` with a UNIQUE on `(parent_activity_id, profile_id)`. `parent_activity_id` references `public_activities.id`.
- `post_reactions` renamed to `reactions`. FK column `post_id` renamed to `parent_activity_id`. Same shape as before otherwise.
- `post_reposts` kept, but FK column `original_post_id` renamed to `parent_activity_id`.
- `public_activities` is the canonical feed table. Every post, news article, comment, reaction, repost, game, meetup, follow, badge = one row. Columns: `id`, `activity_type` (post/news/repost/comment/reaction/game_create/game_join/meetup_create/meetup_join/follow/badge), `parent_activity_id`, `actor_profile_id`, `target_profile_id`, `visibility`, `sport_id`, `area_id`, `reply_count`, `reaction_count`, `like_count`, `repost_count`, `view_count`, `is_deleted`, `source_table`, `occurred_at`.
- `likes.like_count`, `reactions.reaction_count`, `comments.reply_count` on `public_activities` are kept in sync by DB triggers — read denormalised counts from `public_activities`, don't recount client-side.
- RPC `get_home_feed(p_limit int, p_cursor timestamptz)` returns a cursor-paginated union of push path (feed_items) and pull path (public_activities from high-follower users). Returns `activity_id`, `activity_type`, `actor_profile_id`, `parent_activity_id`, `occurred_at` and enough fields to render a feed card.
- RPC `rpc_add_comment(p_post_id uuid, p_author_profile_id uuid, p_body text, p_parent_comment_id uuid)` still takes `p_post_id` — internally maps to `parent_activity_id`. No signature change needed.
- Realtime publication includes: `public_activities`, `feed_items`, `likes`, `reactions`, `comments`, `posts`, `post_reposts`.

---

## Phase 1 — Fix all broken references

Search the codebase for every reference to:
- `post_comments` (table name or model class)
- `post_likes` (table name or model class)
- `post_reactions` (table name in queries — the model/class may have already been called reactions)
- Column name `post_id` used as an FK on comments, likes, or reactions queries
- Column name `original_post_id` used on reposts queries

For each reference: update the query/model to use the current table and column names. `post_id` on comments/reactions/reposts → `parent_activity_id`. `original_post_id` on reposts → `parent_activity_id`.

---

## Phase 2 — Likes

The `post_likes` table is gone. Update the like/unlike data layer to write to `likes` using `parent_activity_id`. The `likes` table accepts any `public_activities.id` as the target — posts, news, comments all share the same like path. Update: the Freezed model, the repository, and the Riverpod provider. Read `like_count` from `public_activities` (already denormalised), not from a client-side count of `likes` rows. Update `PostState` / equivalent controller state to carry `isLiked bool` and `likeCount int`.

---

## Phase 3 — Reactions

`post_reactions` → `reactions`. FK is now `parent_activity_id`. Update the Freezed model, repository, provider. Same unification as likes — reactions target `public_activities.id` so they work on posts, news, and comments. Read `reaction_count` from `public_activities`.

---

## Phase 4 — Comments

`post_comments` → `comments`. FK is `parent_activity_id`. Update the Freezed model, repository, provider. Comments now work on any `public_activities.id` target — post, news article, or a parent comment (threaded via `parent_comment_id`). The comment count is `reply_count` on `public_activities`. Use `rpc_add_comment` with the same parameter names as before (`p_post_id` maps to the target activity's id). The `v_post_comments` view is still available as a backward-compat alias for `v_comments` — both expose `post_id` as an alias for `parent_activity_id`.

---

## Phase 5 — Home screen feed

Replace the current home screen data source (whatever per-table queries power it) with the `get_home_feed` RPC. The feed returns mixed `activity_type` rows. The home feed controller should: call `get_home_feed` on load, support cursor-based pagination using `occurred_at` of the last item as the next cursor, subscribe to `feed_items` via Supabase Realtime filtered to the current user's `profile_id` so new items surface without a full reload, and mark items as seen by updating `feed_items.seen_at`. The feed must render all activity types: post, news, repost, game_create, game_join, meetup_create, meetup_join, follow, badge — each with its appropriate card widget. Fetch type-specific content (post body, game title, etc.) from the source table using the shared `id`.

---

## Phase 6 — Post screen

Update the post detail screen to: load likes from `likes` filtered by `parent_activity_id = post.id`, load reactions from `reactions` filtered by `parent_activity_id = post.id`, load comments from `comments` filtered by `parent_activity_id = post.id`. Threaded replies load from `comments` filtered by `parent_comment_id`. Likes, reactions, and comments on a comment (reply) use the same repositories — the only difference is the `parent_activity_id` value. Read counters (`like_count`, `reaction_count`, `reply_count`) from `public_activities`, not recomputed.

---

## Phase 7 — Article screen (news)

News articles now support comments and likes via the same `comments` and `likes` tables — `parent_activity_id` points to the news item's `public_activities.id`. Update the article screen to wire up the same comment section and like/reaction bar used on the post screen. The news repository should expose the article's `public_activities.id` so the interaction widgets can use it as the target.

---

## Phase 8 — Profile screens (author profile + user profile)

Both the author profile and user profile screens should show an activity feed for that profile. Query `public_activities` filtered by `actor_profile_id = <profile_id>` and `visibility = 'public'`, ordered by `occurred_at` desc. Show all activity types — not just posts. Reuse the same card widgets from the home feed. The profile activity feed is read-only (no fanout needed) — query `public_activities` directly.

---

## Summary

Plan the layer structure (models, repositories, providers, controllers, screens) for all of the above. Identify which existing files need updates vs. which are new. The goal is: one like/comment/reaction data path that works on any `public_activities` target, a home feed driven by `get_home_feed` RPC with Realtime, and post/article/profile screens all sharing the same interaction components.
