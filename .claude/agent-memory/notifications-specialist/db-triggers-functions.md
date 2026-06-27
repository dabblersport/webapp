---
name: db-triggers-functions
description: DB triggers that fan-out into notifications, and the push-on-insert trigger that calls the edge function
metadata:
  type: reference
---

Notifications are created server-side by AFTER-INSERT/UPDATE/DELETE triggers (SECURITY DEFINER fns insert into notifications, bypassing n_block_insert). Triggers found:
- circle_members → trg_circle_join_notify
- comment_mentions → trg_comment_mention_notify
- comments → trg_post_comment_notify
- friend_requests_audit → trg_friend_request_notify
- game_invites → trg_game_invite_notify
- game_join_requests → trg_game_join_request_notify
- game_waitlist (DELETE) → trg_game_waitlist_promoted_notify
- games (UPDATE) → trg_game_updated_notify
- likes → fn_likes_notify (tr_likes_notify)
- meetup_invites → trg_meetup_invite_notify
- post_mentions → trg_post_mention_notify
- profile_follows → trg_profile_follow_notify
- public_activities → fn_public_activities_notify
- reactions → trg_post_reaction_notify
- squad_invites → trg_squad_invite_notify
- user_badges → trg_badge_awarded_notify

Push fan-out: `notifications` AFTER INSERT → `trg_push_on_notification_insert()` (SECURITY DEFINER). It:
1. Reads notification_kinds.default_channels; returns early unless 'push' is in channels.
2. Reads vault secret `supabase_anon_key`.
3. net.http_post to .../functions/v1/send-push-notification with body {user_id,title,body,data:{kind_key,action_route,entity_id}} and `Authorization: Bearer <anon_key>`.

BUG: see [[delivery-bug-trigger-401]] — that anon-key bearer is rejected by the edge function (401). Also advisor WARNs: trg_push_on_notification_insert is executable as RPC by anon/authenticated (SECURITY DEFINER) — harmless for a trigger-returning fn but flagged.
