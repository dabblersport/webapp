# Messaging live migrations — KAN-565 (O1)

Project `wtncuzcskpigqpmnxwws` only. Ordered `execute_sql`, comments stripped, each statement once, never `apply_migration`. Counts and pass/fail only; no ids, no content.

Status at 2026-10-17: **PARTIAL — stopped at file 2 of 6 (KAN-560).**

| # | File | State | Read-back |
|---|------|-------|-----------|
| 1 | `20261013160800_kan547_msg_my_conversations.sql` | APPLIED (6 statements, each once) | `last_activity_at` column 1, index 1, `msg_my_conversations(int)` 1; `msg_notify` body stamps `last_activity_at`; EXECUTE: anon false / authenticated true on both functions |
| 2 | `20261013160900_kan560_msg_dm_conversations.sql` | NOT APPLIED — refused by the SQL hook | n/a |
| 3 | `20261013161000_kan555_msg_my_conversations_dm.sql` | not started (needs 2) | |
| 4 | `20261013161100_kan551_msg_report_list.sql` | not started | |
| 5 | `20261015120000_kan561_msg_dm_exists.sql` | not started | |
| 6 | `20261017120000_kan563_msg_game_conversation.sql` | not started | |

## Why it stopped
The SQL hook refused section 1 of the KAN-560 file (the two DROP-like statements the CEO approved for this ticket) with: "outside the CEO's Messaging approval (supabase-messaging-approval): test data, no DROP". The hook's approval record does not carry the ticket's exception. Nothing was worked around and no part of KAN-560 was applied, so the live schema has no half-applied DM migration.

## Notes
- The ticket names the sixth file `20261015130000_kan563_msg_game_conversation.sql`; on Alpha it is `20261017120000_kan563_msg_game_conversation.sql`.
- Live pre-check: `app_admins` 0 rows, two `is_admin` overloads. The L7 probe (file 4 onward) has not run.
- KAN-560's helper `msg_user_unavailable` reads `auth.users` inside its body; the hook has refused `auth.users` reads before, so it may be a second refusal.
- Probes: none run yet (they need files 2-6).
