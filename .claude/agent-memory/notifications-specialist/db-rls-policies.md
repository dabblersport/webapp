---
name: db-rls-policies
description: RLS policies on notifications/fcm_tokens/notification_settings — all per-user; notifications INSERT blocked
metadata:
  type: reference
---

All three notification tables have RLS enabled and isolate rows per auth.uid(). No cross-user leakage found.

`notifications`:
- n_self_read (SELECT) using to_user_id=auth.uid()
- "Users can read own notifications" (SELECT) using to_user_id=auth.uid()  ← DUPLICATE of n_self_read
- n_self_update (UPDATE) using+check to_user_id=auth.uid()
- n_self_delete (DELETE) using to_user_id=auth.uid()
- n_block_insert (INSERT) WITH CHECK false  ← clients CANNOT insert; rows are created only by SECURITY DEFINER trigger functions / service role. The dead legacy datasource's createNotification() (plain insert) would always fail RLS.

`fcm_tokens`: four policies (select/insert/update/delete) each auth.uid()=user_id. Correct.

`notification_settings`: ns_self_ins (insert check), ns_self_rw (select), ns_self_upd (update using+check). Correct.

Gap: duplicate SELECT policy on notifications is harmless but redundant.
