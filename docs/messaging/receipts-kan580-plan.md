# KAN-580 message receipts: technical plan (backend half)

Status: **authored, not applied, not deployed.** The UI half (state labels, icons, copy, group count format, the recipient
drawer, motion, RTL) waits until the Messaging design (Claude Design project 60c6ce9d, frames 27-30, 44, 46-48,
MESSAGING_DS_ADDITIONS.md sections 10-15) is readable by a team. Nothing here decides or guesses any of that.

Fixed architecture, unchanged: D1 holds message bodies and history; Supabase holds auth, membership, the registry and
Realtime only. The receipt table holds ids and two integers, never content.

## 1. State model

`sent < delivered < seen`, per recipient, kept as two **watermarks** per (conversation, user) in `public.msg_receipts`:
`delivered_seq`, `seen_seq`, with `seen_seq <= delivered_seq` enforced by a CHECK. For a message at seq `s` and a
recipient `r`: `seen` if `s <= r.seen_seq`, else `delivered` if `s <= r.delivered_seq`, else `sent`.

Why watermarks and not a row per message: a row per message per recipient grows with messages x members, needs the message
list in Supabase (it lives in D1), and makes "seen up to here" N writes. A watermark is one tiny row per member, matches
how reading works (opening a chat sees everything up to the newest), and cannot regress by construction.

"sent" is not stored: a message exists in D1 once the send is accepted.

## 2. Who advances it, and when

Only the recipient's own authenticated acknowledgement: `public.msg_ack_receipt(conversation, state, through_seq, mode)`,
SECURITY DEFINER, identity from `auth.uid()` only. It first passes `msg_evaluate` (current membership; a non-member,
removed member, out-of-pilot user or kill-switched mode gets nothing). A leaver is capped at `left_at_seq`. A read-only
member (finished game, block) may still acknowledge what they can read. No grant on the table to anon or authenticated;
RLS on, no policy.

Worker route (authored, not deployed): `POST /v1/conversations/{id}/receipts {state, through_seq}` -> 200
`{delivered_seq, seen_seq, advanced}`. It authorises (msg_authorize), refuses a `through_seq` above the conversation's
highest assigned seq in D1 (read only; no pre-acknowledging future messages), then forwards the caller's own bearer.
No elevated key, no D1 write, nothing logged.

When the app should call it (for the UI half): "delivered" when the message list/wake brings new seqs to the device, "seen"
when the conversation is on screen at the newest seq. That is app behaviour and belongs to the UI half.

## 3. Monotonic, idempotent, multi-device

* Never regresses: the upsert is `GREATEST(old, new)` and updates the row only when something would grow.
  `seen` raises `delivered` with it.
* Idempotent retry: an acknowledgement is by seq, so repeating it is a no-op (`advanced=false`). A send retried under the
  same client message id is already deduplicated by D1 (`UNIQUE(conversation_id, sender_id, client_key)` returns the same
  seq), so it never creates a second thing to acknowledge.
* Multi-device: the state is per user, not per device. Any device may acknowledge; the first to reach a higher seq
  advances the state once, the others see `advanced=false`. Two devices racing are serialised by the primary key upsert.

## 4. Sender's view and the denominator rule

`public.msg_receipt_summary(conversation, seqs[])` (max 100 seqs, caller must be a current member) returns for each seq:
`recipients`, `delivered_count`, `seen_count`.

**Denominator rule.** `recipients` = the DISTINCT current active members of the conversation (the same set `msg_authorize`
returns as `member_user_ids`; for a game the active roster, for a meetup the organiser and 'going' RSVPs, for a DM the two
members) **minus the sender minus any member who has blocked the sender**. Numerators are counted over that same set, so
counts can never exceed the denominator.

Membership changes:
* a member who **leaves or is removed** drops out of the denominator and the numerators from then on (counts are taken at
  read time, not frozen at send time);
* a member who **joins** counts for all history they can read (a joiner can read the whole game history), so a message's
  denominator can grow;
* a member who blocks the sender stops counting; unblocking restores them;
* **distinct recipients**: one watermark per user, so two devices or two roster rows of one user count once.

A group message is "delivered" to the sender when `delivered_count = recipients` and "seen" when `seen_count = recipients`;
a partial state shows the counts. The wording, the count format and the per-person drawer are the design's (not built).
The Worker filters the requested seqs to the caller's own messages from D1 when it exposes the summary (not part of this
change; see section 6).

## 5. Security and privacy notes

* Residual: the function cannot see D1, so a direct caller can acknowledge a seq that does not exist yet. That only
  inflates their own watermark (a message later sent could then read as delivered/seen for them early). The Worker route
  blocks it for the app's path; the effect is on the caller's own receipts only, no one else's data.
* Counts reveal how many, never who. Names stay out until the recipient drawer, which is a design-defined later change
  (a separate function returning user ids and states to the sender only).
* No Realtime payload is added. A sender learns of changes by reading the summary; a live "receipt" wake (payload keys
  limited to `type` and `conversation_id`) is a possible follow-up to avoid polling, at the cost of one wake per
  acknowledgement per member.
* The block-sender exclusion means a blocked user is never made to look unread.

## 6. Not done in this change

* The whole UI half (labels, icons, copy EN/AR, group count format, recipient drawer, motion, RTL) and its design dependency.
* A Worker route for the summary, and the per-person recipient function for the drawer.
* The live receipt wake.
* Applying the migration and deploying the Worker (needs-ops, one migration at a time on project wtncuzcskpigqpmnxwws).
* Running the probe pack: **none of `supabase/tests/messaging/receipts_probes.sql` has been run**; there is no local
  Postgres here and the SQL has not been parsed by a server. The Dart test is static; the Worker tests run against a
  stubbed RPC.

## 7. Rollback

`supabase/tests/messaging/receipts_rollback.sql` revokes execute on both functions (no drop, no delete); the table and its
watermarks stay. Removing the Worker route is a revert of the branch.
