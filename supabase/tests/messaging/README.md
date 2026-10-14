# KAN-505 — Messaging T8: registry, permissions, allowlist, per-user topic policy

**Status: AUTHORED, NOT RUN. Nothing here has been applied to any database and no probe
has been executed.** Target project `wtncuzcskpigqpmnxwws`, on a non-production branch
first. Applying is governed by G-002 (owning backend seat + PEER review); `rollback.sql`
is itself an apply and needs CEO approval.

## Apply order

| # | File | What it does |
|---|---|---|
| 1 | `supabase/migrations/20261013150000_kan505_msg_registry.sql` | `msg_conversations` (one per game) and `msg_conversation_members` (keyed to `game_roster`, holds `left_at_seq`). Identifiers only — no message text column. RLS on, no policy, revoked from anon/authenticated; service_role only. |
| 2 | `supabase/migrations/20261013150100_kan505_msg_access_allowlist.sql` | `msg_access_allowlist` pilot cohort (D19). RLS on, service_role only. |
| 3 | `supabase/migrations/20261013150200_kan505_msg_functions.sql` | `msg_evaluate` (internal), `msg_can_read`, `msg_can_send` (service_role only) and `msg_authorize` (authenticated + service_role). SECURITY DEFINER, `search_path 'public','pg_temp'`, revoked from PUBLIC and anon. |
| 4 | `supabase/migrations/20261013150300_kan505_msg_realtime_user_topic_policy.sql` | SELECT policy on `realtime.messages`: `realtime.topic() = 'user:' \|\| auth.uid()::text`. |

**Hold-back note:** file 4 is separate so it can be held back. It changes Realtime
authorisation project-wide for private channels and should be applied only together with
the T9 public-access test in non-prod. D27 ("Allow public access" off) is not part of
this ticket.

## Decisions taken in the SQL

- **Access mode** (`off | allowlist | all`) lives in the Worker and is passed as
  `msg_authorize(conversation, p_access_mode)`. Default `allowlist`; unknown value or
  `off` → `messaging_off` (fails closed).
- **Reasons:** the T7 contract was not found in the repo; names follow the KAN-496 report:
  `not_authenticated`, `messaging_off`, `not_in_pilot`, `not_member` (also for guessed ids),
  `removed` (kicked / other non-active), and on allowed reads `game_ended` / `game_cancelled`
  and `left` (read up to `left_at_seq`; a missing value means 0).
- **Lifecycle (D5):** derived from `games.end_at` / `games.is_cancelled` at call time. No
  timer, no trigger.
- **Blocks (D4):** read from `user_blocks` only. Game chat: both stay members and may send;
  the blocker's blocked ids come back as `hidden_sender_ids`. The direct-chat rule (hide both
  ways, neither sends) belongs to 1:1 conversations, which this registry does not yet allow
  (`kind = 'game'` only).

## Probes

`probes.sql` — P1–P10, each `READ-ONLY` or `WRITE-IN-TRANSACTION-ROLLBACK`, each ending in
`rollback;`. Requires non-prod test accounts passed as psql variables (listed in the file
header). Every `pass_*` column must be true. **Not run.** Writes to `game_roster` and
`games` inside a transaction may fire existing triggers on those tables; run on a branch.

## Rollback

`rollback.sql` removes nothing: it revokes every grant and alters the Realtime policy to
`using (false)`.

## Reason contract

These reason names are the contract for client tickets (KAN-509 and after). Clients match
on the exact string; renaming one is a breaking change. Meanings as implemented in
`20261013150200_kan505_msg_functions.sql` (`msg_evaluate`):

| Reason | Meaning |
|---|---|
| `not_authenticated` | `auth.uid()` is null (absent, forged or expired token); denied, no user id. |
| `messaging_off` | Access mode is `off`, null or any value other than `allowlist`/`all`; denied (fails closed). |
| `not_in_pilot` | Mode is `allowlist` and the caller is not in `msg_access_allowlist`; denied. |
| `not_member` | Unknown conversation id, or the caller has no roster row for its game (includes spectators and guessed ids); denied. |
| `removed` | Roster status is `kicked` or any other status that is neither `active` nor `left`; denied. |
| `game_ended` | Active member, the game has ended (`end_at` passed) and is not cancelled; allowed action `read`. |
| `game_cancelled` | Active member, the game is cancelled (even if also past `end_at`: cancelled wins); allowed action `read`. |
| `left` | Member with roster status `left`; allowed action `read` up to `left_at_seq` (missing means 0). |

An active member of a game that is neither ended nor cancelled gets allowed action `send`
with a null reason.

## KAN-530: no free text in a message report

`20261013160400_kan530_msg_no_free_text_in_message_reports.sql` makes `report_content` discard `p_details` for
target type `message` (details stored and audited as NULL) and adds one `NOT VALID` CHECK on
`moderation_reports` (`target_type <> 'message' OR details IS NULL`) so a direct insert or update cannot
carry details either. Other report types are unchanged. AUTHORED, NOT APPLIED; probes P11-P15 are
AUTHORED, NOT RUN; rollback is the block in the migration's header comment. Before apply the executor
runs the SELECT-only count in the migration header.
