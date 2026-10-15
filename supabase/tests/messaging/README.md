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
carry details either. Other report types are unchanged. Rollback is the block in the migration's header
comment. Before apply the executor ran the SELECT-only count in the migration header.

Status: the migration is APPLIED live (Alpha f171cd63, operations report
`cdispatch-f03cefc8-3727-41bb-84b9-1bae89007851`). P11 and P12 passed there. The direct-insert checks
passed when run as `service_role`, and an UPDATE adding details to a message report was refused with
23514. The probes P13-P17 in `probes.sql` were corrected afterwards to match and are AUTHORED, NOT RUN
in their corrected form.

Who can write: `authenticated` holds SELECT only on `moderation_reports` (an insert fails with 42501);
only `postgres` and `service_role` insert directly. Client reports go through `report_content`
(P17 asserts the refusal). The `mr_self_insert` policy is not the reachable path and was not changed.

Open observation (not changed here): `report_content` stays executable by `anon` and PUBLIC. It refuses
a NULL `auth.uid()` with `auth_required`, so an anonymous call fails, but the grant itself is unchanged.

## KAN-541: msg_notify (Realtime R1)

`20261013160600_kan541_msg_notify.sql` adds `public.msg_notify(conversation, seq, mode default 'allowlist')`:
after the Worker stores a message, the sender calls it and each current active member (not blockers of the
sender, not leavers, not removed) gets a metadata-only wake-up on their private `user:<uid>` topic through
`realtime.send(..., 'msg', topic, true)`. Payload: `type`, `conversation_id`, `seq`, nothing else. AUTHORED, NOT
APPLIED. `notify_realtime_send_check.sql` is a read-only check for Memphis (signature, owner and privileges of
`realtime.send`), `notify_probes.sql` N1-N6 are AUTHORED, NOT RUN, and `notify_rollback.sql` only revokes.

KAN-545 (Realtime R5): the live proof runner and its unit tests are in `realtime/` (see `realtime/README.md`).

## KAN-547: the Messages list (msg_my_conversations, last_activity_at)

`20261013160800_kan547_msg_my_conversations.sql` adds `msg_conversations.last_activity_at` (with an index), re-issues
`msg_notify` with one added statement that stamps it, and adds `public.msg_my_conversations(p_limit int default 50)`:
the signed-in user's own game chats, newest activity first, with game title, sport name, start and end time, the
caller's state (send, read-only, left; kicked and removed are excluded) and `last_activity_at`. No content, no
member lists. AUTHORED, NOT APPLIED. New files: `my_conversations_probes.sql` (M1-M10, AUTHORED, NOT RUN, all
BEGIN..ROLLBACK) and `my_conversations_rollback.sql` (revoke plus the previous `msg_notify`).

## KAN-560: direct messages (DMs), mute and the daily new-DM cap

`20261013160900_kan560_msg_dm_conversations.sql` (one transaction) lets `msg_conversations` hold `kind = 'dm'` (the old
kind check is re-added with `'game'` and `'dm'`, `game_id` becomes nullable, and a pairing check ties `game_id` to the
kind), adds `msg_dm_pairs` (one row per pair, identifiers only) and `msg_conversation_members.muted_at`, and
re-issues `msg_evaluate` (a DM branch only), `msg_authorize` (DM member list only) and `msg_notify` (muted members skipped,
DM recipients). New app functions: `msg_start_dm(other)` and `msg_set_muted(conversation, muted)`; two internal helpers
carry no grant. Age comes from `profiles.age`; deleted or banned from `auth.users`. A DM with a block in either direction
is read-only for both (reason `blocked`), a banned or deleted counterpart makes it read-only (reason `suspended`).
AUTHORED, NOT APPLIED. New files: `dm_probes.sql` (D1-D13, AUTHORED, NOT RUN, all BEGIN..ROLLBACK) and `dm_rollback.sql`
(refuses when any DM exists). The Worker's mapping of the two read-only reasons and listing DMs in the Messages list are
later tickets.

## KAN-555: DM rows in the Messages list (msg_my_conversations v2)

`20261013161000_kan555_msg_my_conversations_dm.sql` makes `msg_my_conversations` return DM conversations together with
game chats, newest activity first. It keeps every KAN-547 column and rule and adds `kind`, `counterpart_user_id`,
`counterpart_name`, `counterpart_avatar` (public profile only, NULL for game rows) and `muted` (the caller's own flag).
A DM is listed for its starter at once and for the other member only once a message exists; a block in either direction
or a deleted or banned counterpart makes it read-only. Because PostgreSQL cannot change a function's result columns with
CREATE OR REPLACE, v1 is renamed to `msg_my_conversations_v1` (EXECUTE revoked) and the new function takes the name; nothing
is removed. AUTHORED, NOT APPLIED. New files: `my_conversations_dm_probes.sql` (L1-L8, AUTHORED, NOT RUN, all
BEGIN..ROLLBACK) and `my_conversations_dm_rollback.sql` (swaps the names back).

## KAN-551: msg_list_message_reports (launch M1a)

Status: **AUTHORED, NOT APPLIED, NOT RUN.** Nothing here was applied or executed.

Apply order: after every file above, `supabase/migrations/20261013161100_kan551_msg_report_list.sql`
(one function, `public.msg_list_message_reports(p_limit int default 50)`).

- Admin only via `public.is_admin()`; a non-admin gets `P0001 forbidden` (the `admin_resolve_report`
  pattern); anon has no EXECUTE. Returns report id, reason, created_at, status, target message id and
  `conversation_id`, which is always NULL: reports persist only the message id and the registry holds no
  messages. No details, snapshot, names or text. Clamp 1..100, newest first.
- Notifications: `notify_admins_of_report` is read, not changed (ids, target type and enum reason only).
- Probes: `msg_report_list_probes.sql` L1-L7. Rollback: `msg_report_list_rollback.sql` (revoke only; an
  apply needing approval).

Hold-back note: the function is independent of the Worker and can be held back alone; holding it back
leaves the KAN-513 Worker read as the only moderation surface.

**PR text needs the L7 counts-only comparison** (is_admin() users, app_admins rows, and the two
differences). It was NOT run here; whoever runs the probe fills those four numbers in. A mismatch
means some admins are notified but cannot list, or can list but are not notified.
