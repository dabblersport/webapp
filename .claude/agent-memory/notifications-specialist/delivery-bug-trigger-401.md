---
name: delivery-bug-trigger-401
description: DB-trigger-originated push notifications fail with 401 because send-push-notification rejects the anon-key caller
metadata:
  type: project
---

DB trigger fan-out to push is broken. `trg_push_on_notification_insert` calls send-push-notification with `Authorization: Bearer <vault supabase_anon_key>`, but the function does `callerClient.auth.getUser()` and returns 401 when there is no real user. An anon (or service-role) key has no user `sub`, so getUser() returns null → 401. Edge-function logs confirm repeated `POST | 401 | send-push-notification`.

**Why:** the function's user-auth guard (added for the in-app NotificationSender path, which carries a real user JWT) is incompatible with the server-trigger path (machine-to-machine, no user).

**How to apply:** when fixing, give the trigger path a separate auth lane — e.g. have the trigger send the service-role key and let the function accept a service-role caller (skip getUser + block-check for the trusted server path, since the trigger already targets the correct to_user_id), OR move token-fetch+FCM-send into the trigger's own function variant. Verify via edge-function logs that 401s stop. The in-app `NotificationSender.sendToUser` path is fine (real user JWT) — do not break it.
