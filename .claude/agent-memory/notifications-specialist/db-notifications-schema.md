---
name: db-notifications-schema
description: Exact schema of public.notifications + notification_kinds lookup, notify_priority enum, indexes, FKs
metadata:
  type: reference
---

`public.notifications` (constant `SupabaseConfig.notificationsTable = 'notifications'`). Columns:
- id uuid PK default gen_random_uuid()
- to_user_id uuid NOT NULL → FK auth.users(id) ON DELETE CASCADE  (NOTE: column is `to_user_id`, NOT `user_id`)
- kind_key text NOT NULL → FK notification_kinds(key) ON UPDATE CASCADE  (NOTE: type column is `kind_key`, NOT `type`)
- title text NOT NULL
- body text NULL
- action_route text NULL
- context jsonb NOT NULL default '{}'  (client model maps this to `payload`)
- priority notify_priority NOT NULL default 'normal'
- created_at timestamptz NOT NULL default now()
- is_read boolean NOT NULL default false
- read_at timestamptz NULL
- ai_score numeric NULL default 1
- rank_score numeric NULL
- clicked_at timestamptz NULL
- interaction_count int NULL default 0

Enum `notify_priority`: low, normal, high, urgent.

Lookup table `notification_kinds(key, default_channels text[], ...)` — kind_key FK target; `default_channels` drives whether push fires (push trigger checks `'push' = ANY(default_channels)`).

Indexes on notifications:
- notifications_pkey (id)
- idx_notifications_user_time (to_user_id, created_at DESC)
- idx_notifications_unread (to_user_id, is_read) WHERE is_read=false
- idx_notifications_post_like_unique UNIQUE (to_user_id, kind_key, context->>'liker_user_id', context->>'post_id') WHERE kind_key='social.post_liked'

Views: v_notifications_feed (plain order by created_at), v_notifications_ranked (computed_rank formula), v_unread_counts (auth.uid scoped), v_activity_inbox (unread join). NO `v_notifications` view exists (legacy stream over it was removed). App reads the base `notifications` table directly, not these views.
