---
name: edge-functions
description: send-push-notification & broadcast-notification edge functions — FCM HTTP v1, auth model, secrets
metadata:
  type: reference
---

Deployed notification edge functions (project wtncuzcskpigqpmnxwws, Firebase project 'dabblersportapp'):
- `send-push-notification` (verify_jwt=true): body {user_id,title,body?,data?,platforms?}. Dual auth lanes: (1) trusted trigger lane via `x-trigger-secret` header validated against RPC get_push_trigger_secret() with constant-time compare — used by DB trigger trg_push_on_notification_insert; (2) per-user lane via auth.getUser(), enforces user_blocks both ways unless self. Reads fcm_tokens for user_id (service role) optionally filtered by platform; sends per-token via FCM HTTP v1. Falls back body=title. PRUNES invalid tokens (404/UNREGISTERED/INVALID_ARGUMENT → batch delete from fcm_tokens; transient 5xx NOT pruned). The client-side NotificationSender helper was DELETED 2026-07-11 (dead code, zero callers) — push is entirely server-trigger-driven now.
- `broadcast-notification` (verify_jwt=true, v7 since 2026-07-11): requireAdmin (auth.getUser + rpc is_admin); sends to FCM topic (default 'announcements'), THEN persists in-app rows via service-role RPC `rpc_broadcast_inapp_notification(p_title,p_body,p_route)` — one `notifications` row per active profile with kind `system.announcement` (default_channels={inapp} ONLY, deliberately, so the per-row push trigger does not double-send). Response includes in_app_rows count. Persistence failure is logged but does not fail the request.
- `detect-country` (verify_jwt=false): unrelated, healthy (200s).

FCM auth: both build a Google OAuth2 JWT from FIREBASE_SERVICE_ACCOUNT secret, scope firebase.messaging. Secrets needed: FIREBASE_SERVICE_ACCOUNT, FIREBASE_PROJECT_ID, SUPABASE_SERVICE_ROLE_KEY (both functions now — broadcast uses it for the persistence RPC). Repo copies live in supabase/functions/<name>/index.ts.

Topics: mobile client subscribes to 'announcements' and platform-name topic (push_notification_service_mobile.dart).
