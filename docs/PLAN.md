# docs/PLAN.md — The Plan

**Owner:** the assistant (this session), assembled from `cpo`/`cto`/`master-analyst`'s
work — written 2026-08-28. **One page. What happens, in order, who does it, what "done"
means.** Everything here is backed by evidence in `ROADMAP.md`, `DECISIONS.md` and
`PROJECT_STATE.md` — this file does not re-argue any of it, only sequences it.

**Update this file, don't grow it.** When a step closes, mark it and move the date
forward. This is the one page you should be able to open and know where things stand
without reading anything else.

---

## THE QUESTION THIS PLAN ANSWERS

Dabbler is live on both stores, not promoted. **What has to happen before it's safe to
promote, in what order, and who does each piece?**

---

## RIGHT NOW — waiting on you, nothing else can start

Three decisions. Nothing below moves until these are made.

| # | Decision | Why it blocks everything |
|---|---|---|
| **1** | **Apply KAN-67** — decided 2026-08-28: **`cto` applies it**, under `G-002`'s standing authority, not you by hand | This is the single highest-severity item on the board and the safest to apply: zero client references, cannot blank a screen. `cto` posts verification results back to the ticket after |
| **2** | **Hire a backend owner** — `CONTRACT.md` names the seat as vacant, not contested | Unblocks B1a/B1b and the 30 zero-policy tables. Without this seat, nobody may even *author* most of the remaining SQL |
| **3** | **Hire a Flutter feature agent** | Unblocks B2, B4, B5, and half of the logout fix. 23 of 25 code slices are currently owned by nobody |

**The SQL for #1 — final, verified, and posted as a comment on KAN-67 (2026-08-28).**
Copy it from the ticket, not from here. It is one pasteable block plus a five-step
verification block, and the plain-English brief above it says what it does and does not
touch.

**The draft that used to sit here was wrong and has been removed** — it named
`post_drafts` and `user_reputation`, neither of which exists (the real base tables are
`content_drafts` and `user_reputation_aggregate`), and it prescribed `FORCE ROW LEVEL
SECURITY`, which `T-025` demonstrated remediates nothing here because `postgres` carries
`rolbypassrls = true`. **Do not paste SQL for this from any file. The KAN-67 comment is
the only signed-off copy.**

**Nothing below can be worked by an agent until #2 and #3 land.** Production writes are
still closed to every agent except `cto`, and only under `G-002`'s four conditions
(authored+posted first, verified live, schema/privilege/definition only, verified+posted-back
after) — decision 019 otherwise stands.

---

## THE ORDER, ONCE STAFFED

```
  #1 (cto, under G-002, today) ──> KAN-67 applied ──> anon write path closed
                                          │
  #2 backend owner hired ──────────────────┼──> B1b (the wider read sweep)
                                          │
  #3 Flutter agent hired ──> KAN-58 (logout) ──> B4 (Message button) ──> KAN-59 (push scope)
                                          │
                                          └──> B2, B5 ──> NEXT MONTH, not this one
```

| Step | What | Owner | Needs | Ticket |
|---|---|---|---|---|
| 1 | Revoke the anon write grants + `ALTER DEFAULT PRIVILEGES` (no FORCE RLS — `T-025`) | `cto` authors **and applies**, under `G-002` | Nothing — can happen today | KAN-67 |
| 2 | Wider definer-view read sweep (49 views) | backend owner | Hire #2 | KAN-37, KAN-38 |
| 3 | Logout teardown (FCM revocation, cache clear) | Flutter agent | Hire #3 | KAN-58 |
| 4 | Hide/fix the Message button (dead route → live UI) | Flutter agent | Hire #3 | KAN-45 |
| 5 | Push-notification authorization scope | notifications-specialist | **Nothing — can start today**, `CONTRACT.md:117` already grants this | KAN-59 |
| 6 | PDPL data export (2,092 LOC, disconnected) | Flutter agent | Hire #3 | KAN-52 |
| 7 | Analytics emission layer (build, not wire) | Flutter agent | Hire #3 | KAN-51 |

**Step 5 needs nobody hired and can start immediately** — say the word and I'll dispatch
`notifications-specialist` today, independent of everything else on this page.

**Steps 6 and 7 are explicitly next month, not this one** — both need the Flutter hire
and both are larger than a week. Consequence, stated plainly: **the acquisition-spend
budget does not unlock this month**, because it's defined by numbers step 7 makes the
product finally emit.

---

## WHAT THIS BUYS YOU

**When steps 1–5 close:** the four things capable of harming a real user today are shut.
Not promotable yet — B2 and B5 still gate promotion — but the destructive/live-harm class
is closed.

**When steps 6–7 also close:** the full six-item promotion gate clears, and the decision
to promote returns to you with nothing red on it.

---

## OUT OF SCOPE THIS MONTH, ON PURPOSE

Not neglect — `cto`'s ruling (`T-010`): these don't harm a user, only embarrass, and
fixing them now would spend the month's only Flutter capacity on the wrong things.

- 140 oversized files, 317 hardcoded colours across 43 files, 3 competing error-handling
  conventions *(the old 143/233 pair was stale; both corrected 2026-08-27 — 140 per `T-010`,
  317 per `PROJECT_STATE.md` STYLE-01, which carries the exact command and exclusions. Quote
  the figure from there, not from here.)*
- 69,612 lines of unreachable code (the `rewards` and clean-arch stacks)
- The full 49-view invoker conversion (narrowed to a policy-carrying subset only — see
  `DECISIONS.md` T-024, converting the rest would blank the app)

---

## SEPARATE FROM THE GATE — needs you, no agent can do it

| Item | What | When |
|---|---|---|
| **Android signing key rotation** | Public 9 months; the code fix exists uncommitted, rotation itself needs Play Console | Whenever you have 30 minutes — not gating promotion |
| **Password reuse check** | The exposed password may be reused elsewhere — email, Supabase, Apple ID | 5 minutes, only you can check |
| **`BRIEF.md` §14** | 6 business questions — revenue model (13–27× discrepancy), the App Fee vs. a non-waivable non-negotiable, whether the 25-organiser beta ran, runway | Whenever — doesn't block the security gate |
| **Cricket wedge / venue partner pack** | Two product calls, not engineering | Whenever |

---

## Changelog

| Date | Change |
|---|---|
| 2026-08-28 | Created. Assembles the reconciled output of the multi-agent negotiation into one actionable page — the negotiation itself is recorded in `ROADMAP.md` §Wave P and `DECISIONS.md` T-016–T-024, P-004–P-018. |
| 2026-08-28 | PO granted `cto` standing production-apply authority under four conditions (`DECISIONS.md` `G-002`), after directly asking the assistant to apply KAN-67 and the assistant declining and routing the authority question back to the PO. Step 1 above reassigned from "PO applies" to "`cto` applies". |
