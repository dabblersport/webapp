---
name: invoker-flip-join-trap
description: security_invoker applies the caller's RLS to every relation in a view including joins — the KAN-38 v_comments rejection, with the measured 67→48 row loss
metadata:
  type: project
---

**`security_invoker` applies the caller's RLS to EVERY relation a view touches, joins
included — not just the table you think of as primary.** An INNER JOIN whose right side is
filtered by RLS **drops the entire row**, not just the joined columns.

**Why:** caught in `backend-owner`'s KAN-37/38 migration, 2026-08-28. `v_comments` is
`comments pc JOIN profiles pr ON pr.id = pc.author_profile_id`. The brief applied T-024's
two-stage rule to `comments` and not to `profiles`, whose permissive read policy is
`profiles_select_public USING (is_active = true)`.

Measured read-only before deciding:

| | rows |
|---|---|
| `v_comments` as anon, definer (today) | 67 |
| after the flip | **48** |
| lost — author `is_active = false` | **18** |
| lost — parent activity not public | 1 |

Only **1 of 19** lost rows was the leak being closed. The brief claimed the flip "changes
nothing about which rows are visible." **Rejected that slice; approved the rest.**

**How to apply:** for any invoker flip, run the two-stage rule against every relation in the
view definition, and **prove it with a before/after row count computed read-only** rather
than reasoning about it. Recorded in `CONVENTIONS.md` §6 with these numbers.

**The product question this surfaced, still open:** should a comment by a deactivated profile
show on a public post? If `is_active=false` means banned, hiding the 18 is intended; if
dormant, it's a regression. **`cpo` decides, not `cto` and not backend.** Fix is then either
`LEFT JOIN profiles` + flip, or keep definer + revoke the read grant.

**Review pattern that worked, worth repeating:** the brief's measurements were all real and
reproduced — what was wrong was the *scope of the question asked*. Say that explicitly when
rejecting, so the agent does not read a scoping miss as carelessness. See
[[verification-lessons]].

**Migration A applied 2026-08-28** — ledger `20260828193807`,
`kan37_kan38a_definer_view_read_closure`. The approved subset, authored by `cto` after
carving out the rejected slice so the KAN-37 blocker did not wait on a product question.
Four invoker flips (`v_notifications_feed`, `v_notifications_ranked`, `v_user_reputation`,
`v_meetup_counts`), SELECT revoked on `v_game_rating` + `v_challenge_standings`,
`v_user_badges_summary` scoped to `auth.uid()`. anon-readable views **48 → 45**.

**The verification step worth reusing:** asserting `count(*) > 0` for the caller's *own*
rows under a real JWT, not only `= 0` for anon. A REVOKE-only fix cannot make that
assertion, and it is what proves the flip closed a leak without blanking the owner.

**And a regression check to run after any `CREATE OR REPLACE VIEW`:** it can silently
restore default grants. Confirmed KAN-67's posture held (0 postgres-owned views grant
write). See [[kan67-migration-facts]].

**Migration B applied 2026-08-28** — ledger `20260828194512`,
`kan38b_v_comments_leftjoin_invoker`. `LEFT JOIN profiles` + flip both views. Verified
66 / 66 / 18-null-author, exactly 1 row closed. KAN-37 and KAN-38 both In Review.

**The argument that settled it, and the one worth reusing:** `profiles.is_active` is the
**multi-persona switch**, not a ban flag (`persona_service.dart` — `switchActiveProfile` sets
one profile true and *all others false*). So the INNER JOIN version would not have hidden 18
rows once; **a comment's public visibility would drift every time its author switched
personas** — no write to the comment, no moderation action. The defect was not the row count,
it was that the row count was **not stable**. That is what moved it from a trade-off to a
defect, and it is the frame that got cpo to rule.

**Supporting check worth repeating:** the client already tolerates a null author —
`post_repository_impl.dart` `getComments` guards
`if (profile is Map && profile['display_name'] != null)` and `PostComment.authorDisplayName`
is nullable. A null author matches shipped behaviour rather than introducing new behaviour.


## Aggregates, not just row drops (2026-08-29, KAN-56)

The trap is wider than rows disappearing. `v_circle_feed` carries
`count(cm.member_profile_id) OVER (PARTITION BY c.id) AS circle_members_count` over a
**LEFT JOIN to circle_members**. Under `security_invoker`, that count is computed only
over the rows the caller can see — a non-owner member reads a
different value than the owner does. **Measured after the flip went live
(2026-08-29): true membership 2; as postgres 6 rows / count 6; as owner 6 / 6; as
non-owner member 3 / 3.** The column was never a member count — the LEFT JOIN is
never collapsed, so each post is duplicated once per member and the window returns
posts x members. Pre-existing view bug; the flip only makes the wrong number
caller-dependent, and no post is lost. I initially called this a blocker and had to
withdraw it — see [[cto-own-ruling-corrections]]. When reviewing a flip, check every joined relation that feeds
an aggregate or window function, and require the verification to assert the *value*,
not just the row count. See [[jwt-profile-id-claim-trap]].
