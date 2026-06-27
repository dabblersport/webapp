---
name: edge-functions
description: send-push-notification & broadcast-notification edge functions — FCM HTTP v1, auth model, secrets
metadata:
  type: reference
---

Deployed notification edge functions (project wtncuzcskpigqpmnxwws, Firebase project 'dabblersportapp'):
- `send-push-notification` (verify_jwt=true): body {user_id,title,body?,data?,platforms?}. Requires authenticated USER (callerClient.auth.getUser()); enforces user_blocks both ways unless self; reads fcm_tokens for user_id (service role) optionally filtered by platform; sends per-token via FCM HTTP v1. Falls back body=title. Does NOT clean up invalid tokens (TODO in code). Called from client via NotificationSender (lib/services/notifications/notification_sender.dart) AND from DB trigger trg_push_on_notification_insert.
- `broadcast-notification` (verify_jwt=true): requireAdmin (auth.getUser + rpc is_admin); sends to FCM topic (default 'announcements'). No client call site found in lib (admin-only).
- `detect-country` (verify_jwt=false): unrelated, healthy (200s).

FCM auth: both build a Google OAuth2 JWT from FIREBASE_SERVICE_ACCOUNT secret, scope firebase.messaging. Secrets needed: FIREBASE_SERVICE_ACCOUNT, FIREBASE_PROJECT_ID, SUPABASE_SERVICE_ROLE_KEY (send only). Repo copies live in supabase/functions/<name>/index.ts.

Topics: mobile client subscribes to 'announcements' and platform-name topic (push_notification_service_mobile.dart).
