# MVP 1+ — Draft launch checklist

**Status: DRAFT. Prepared by `cpo` 2026-08-29 for a negotiation with the PO. Nothing here
is decided.** Every item is either cited to a business document or flagged as an open
question. Where I have a recommendation I say so and say why; the PO overrules freely.

**Sources:** the 26-document Notion corpus (`docs/BRIEF.md` §§1–14 is its distillation) ·
`docs/PROJECT_STATE.md` for measured build state · `docs/ROADMAP.md` Wave P · Jira `KAN`.

---

## 0. The framing problem the PO has to settle first

**Dabbler is already live in two stores.** The corpus's entire launch apparatus — `13a`
sprints, `13b` runbook, `13c` store pack, `13d` beta plan, `14` checklist — was written for
a product that had not shipped. It assumes a go/no-go decision that has already been taken.

So "MVP 1+ launch checklist" is not the corpus's launch gate. It is a **retrofit gate**, and
it answers a different question:

> The app is live but not promoted. **What has to be true before we spend money pointing
> people at it, and what ships in the release after that?**

This is the distinction the corpus itself already makes and that `P-004` recorded: the
product is *shipped* but not *promotable*. I recommend the checklist be named for what it
does — **the promotion gate plus the next release** — rather than for a launch that has
already happened. If the PO wants "MVP 1+" as the label, the label is fine; the content
should still be these two things.

**Open question 0.1** — is MVP 1+ (a) the promotion gate only, (b) the next shipped release
only, or (c) both? Everything below is written as (c) and split accordingly. If the PO wants
(a), Part B drops out.

---

## PART A — The promotion gate

### A.1 Where the bar comes from

The corpus contains its own binding gate and I am not inventing one. `13b launch runbook`
§C:

> "The go/no-go gate (Section C) is binding. If a P0 criterion is red, you hold the launch.
> No exceptions, no 'we'll fix it live.'"
>
> "A held launch costs days. A broken launch costs trust, store ratings (which are hard to
> recover), and the founding-user cohort you only get once. **When in doubt, hold.**"

**The ten P0s:** P0-1 store approval · P0-2 48h production stability, zero P0 bugs · P0-3
auth works in production · P0-4 core loop (create → discover → RSVP) verified in production ·
P0-5 payments dormant · P0-6 PDPL consent + export + delete **verified in production** ·
P0-7 monitoring live · P0-8 rollback tested and executable solo · P0-9 RLS verified, no
unauthorized data access · P0-10 Arabic RTL on every screen.

Two gates sit outside `13b`: `08 GTM playbook` Part 2 §A.2 requires **verified analytics
instrumentation**, and `13d` requires the **beta exit criteria** (≥80% of 25 organisers ran
a real game; ≥60% "would use instead of WhatsApp").

**Contradiction the PO must rule on (C-launch-gate).** `14` J10 reduces the same day-of check
to one line — *"stores approved, no serious bugs, monitoring live"* — silently dropping P0-5,
P0-6, P0-8, P0-9 and P0-10. `14` is the later document and explicitly supersedes `13a`–`13c`
on auth, so the ambiguity is real. **I have judged against `13b`'s ten throughout, and I
recommend the PO ratify that** — `14` J10 drops exactly the five items that are hardest to
recover from if wrong (payments, data rights, rollback, security, bilingual integrity).

### A.2 Status against the ten, as of 2026-08-29

Build facts are `master-analyst`'s and `cto`'s, not mine — I have taken them from
`PROJECT_STATE.md` and the Jira record rather than re-measuring.

| P0 | Status | Evidence / blocker |
|---|---|---|
| P0-1 store approval | **GREEN** | Live in two stores |
| P0-2 48h stability, zero P0 bugs | **UNVERIFIED** | No one has run a 48h clean-window observation. Cannot be green while P0-7 is red |
| P0-3 auth in production | **GREEN** | Live and in use |
| P0-4 core loop in production | **AMBER** | Create → discover → RSVP is the live path. Not verified *as a gate exercise* in production. Cheap to close |
| P0-5 payments dormant | **GREEN** | No payment path ships. Depends on the App Fee ruling (§C.2) staying unbuilt |
| P0-6 PDPL export/delete verified **in production** | **RED** | KAN-52. UI wired 2026-08-29, review **failed**, back in To Do. `13b` says *in production* — code merged is not the gate |
| P0-7 monitoring live | **RED / UNOWNED** | No ticket. See open question A.4 |
| P0-8 rollback tested, executable solo | **RED / UNOWNED** | No ticket. Never rehearsed |
| P0-9 RLS verified, no unauthorized access | **RED, improving** | KAN-24/25/38/67 Done, KAN-61 CI guard Done. Still open: KAN-37, KAN-26, KAN-59, KAN-69, KAN-75, KAN-77, KAN-80, KAN-81, KAN-82, and **KAN-78 — 55 live production accounts share a known password** |
| P0-10 Arabic RTL every screen | **RED** | Language switching works (KAN-53 retracted). Per-screen RTL sweep never performed. `06` gates it on a native Arabic review by a copywriter who is not staffed |
| `08` analytics verified | **RED** | KAN-51. Emission layer built 2026-08-29, review **failed**, back in To Do |
| `13d` beta exit criteria | **NOT RUN** | See §C.5 — the highest-value item on this page |

**Reading:** five red, one amber, two unverified. **The gate does not open, and nothing here
argues for opening it early.**

### A.3 What I would put on the gate, and what I would take off

**On the gate (my recommendation):** P0-2, P0-4, P0-6, P0-7, P0-8, P0-9, P0-10, `08`
analytics. Eight items.

**Off the gate — argued, not assumed:**

- **`13d` beta exit criteria.** Not a gate item; a *prerequisite to knowing whether the gate
  is worth passing*. Sequenced ahead of it in §C.5 instead.
- **KAN-57 (keystore password).** Already ruled off by `P-013` — the keystore file was never
  committed, so the password alone signs nothing, and promotion does not worsen a static
  nine-month-old exposure. It stays HIGH in the normal queue. **I flag that the reasoning
  covers the key and not the reuse:** if that string is also an email, Play Console, Apple or
  Supabase password, rotating the upload key closes nothing. That is a PO item, not an
  engineering one, and it is in no ticket.
- **KAN-29 / KAN-30.** Explicitly out (`ROADMAP` Wave P), and my framing on both is now
  posted to the tickets.

### A.4 The two unowned P0s — the gap I most want the PO to look at

**P0-7 (monitoring) and P0-8 (rollback) have no ticket, no owner, and no evidence anyone has
attempted them.** They are the only two P0s in that position. They are also the two that
determine whether a promotion *failure* is recoverable:

- Without P0-7, P0-2 ("48h, zero P0 bugs") is unfalsifiable — you cannot count bugs you
  cannot see.
- Without P0-8, the correct response to a bad promotion is unavailable. `13b`'s own logic —
  *"a broken launch costs trust and store ratings, which are hard to recover"* — is entirely
  about the recovery path.

**Recommendation: these two are the first tickets cut out of this negotiation.** They are
cheap relative to everything else on the gate and they are what makes the rest of the gate
measurable. Owner is `cto`'s to assign; I am flagging the hole, not scoping the fix.

---

## PART B — What ships in the next release

`13b`'s ten are correctness and compliance gates. They say nothing about what the product
*does* next. That is Part B, and it is much more genuinely open.

### B.1 What the corpus has already committed to Phase 1A

Settled by `docs/BRIEF.md` §5, re-verified for this draft. **These are not open questions.**

| Area | Committed position | Citation |
|---|---|---|
| Gamification | **In scope**, at 3 tiers (Bronze/Silver/Gold + streaks). 15-tier is Stage 2 | `05` slide 4 · `11 v2` §F.3 · `13a` Sprint 11 · `14` D52–D54 |
| Messaging / in-app chat | **Out of Phase 1A.** Whether ever in scope is NOT ESTABLISHED | `14` has no chat story · `11 v2` §F.3 defers Organiser Community Channel to Stage 2 · `11b` B.14 = Phase 1B |
| Venue booking | **Out.** Venue *submission* ships; *booking* does not | `PROJECT_STATE.md` · KAN-55 |
| Payments | **Dormant by gate** (P0-5) | `13b` §C |
| Cricket | Supported as a sport (107 code references). The *wedge* is absent | KAN-54 |

### B.2 The candidate list for MVP 1+, ordered by my reading of leverage

Presented for negotiation. I have not decided any of these.

1. **Close the promotion gate (Part A).** Not a feature, but it is the release's spine. Every
   item below is worth less until the gate opens, because none of it is measurable.
2. **Rewards: cut to the committed 3-tier surface.** KAN-29. My framing is posted. Removes
   19,560 LOC, 65 hardcoded colours, 18 empty catches and 3 user-visible "Coming Soon"
   dashboards — and lands the product *on* the committed scope rather than beside it.
3. **The promise-gap sweep.** KAN-45, KAN-46, KAN-47, KAN-48, KAN-49. Five live surfaces that
   lie to the user — a Message button to a placeholder, settings screens that say "saved!"
   and write nothing, screens showing **fabricated AED transactions and fake friend
   suggestions**. Against `01`'s Permanent Truths this is the worst category of defect on the
   board, and KAN-49 is arguably a promotion blocker in its own right. **Open question B.2a:
   should KAN-49 be escalated onto the Part A gate?** My inclination is yes; I have not done
   it unilaterally because it changes a gate the PO ratifies.
4. **The cricket wedge.** KAN-54. `07` recommends cricket-first; the competitive surface that
   makes it a wedge (CricClubs, Playtomic, Strava absent) is not built. This is the largest
   *strategic* gap on the board and it is a PO decision, not an engineering one.
5. **P0-10 Arabic RTL sweep.** On the gate, but also real product work, and `06` blocks it on
   an unstaffed Arabic copywriter — a hiring decision, not a sprint.

### B.3 What I recommend explicitly *stays out*

Chat · venue booking · payments · the 15-tier rewards engine · the layered-architecture
migration (KAN-30 — and per my comment there, that is `cto`'s call and should not sit between
now and the gate) · mass deletion of the 69,612 unreachable lines (`ROADMAP` Wave P: riskiest
operation in the repo, zero coverage on live paths).

---

## PART C — Open questions for the negotiation

Ordered so the answers unblock each other. **1–4 are the corpus contradictions that make
"on track" meaningless until settled** — they are `docs/BRIEF.md` §14 questions 1–4, restated
here in launch terms rather than repeated.

### C.1 Which financial model is the plan? (C1)
`00`/`02`/`03` say ~$1.5M Year 1 on 50K MAU. `12c` says $82K base / $28K conservative.
**13–27× apart.** Until one is marked superseded, no promotion budget can be sized and no
success criterion for MVP 1+ can be written. **This is the question that most directly
blocks writing a real checklist**, because "did MVP 1+ work?" has no answer without it.

### C.2 Does the App Fee stand? (C4 — constitutional)
`12b` charges free players AED 1.3 per transaction and takes 80% of the organiser uplift out
of what a player pays. `01` Permanent Truth 1, `02`'s governing sentence and `04`
Non-Negotiable 1 all say Dabbler does not take money from players — and `04` Art. 33.1 says
no officer may waive a Non-Negotiable. **This must be settled before any pricing is built**,
and it interacts with P0-5: "payments dormant" is easy to hold while the ruling is open, and
becomes contested the moment it is not.

### C.3 Is "the world's first" retired? (C2)
`07d` §4.18 issued the correction in May; `00`, `03` and `05` still carry the claim and `06b`
§2.2 holds it up as the model of correct voice. This is a **store-listing and promotion-copy
question**, so it lands in MVP 1+ directly: any acquisition spend puts that sentence in front
of people.

### C.4 Which north star — "games confirmed" or CSAU? (C5)
Both are written as overruling. **This determines what the analytics layer emits first**
(KAN-51), so it is a dependency of the `08` analytics gate, not a philosophical question.

### C.5 Did the 25-organiser beta run? (G7) — **my highest-value ask**
`13d`'s key question: *"would you use this instead of WhatsApp?"* Exit bar: ≥80% of 25
organisers ran a real game, ≥60% yes.

If it never ran, **running it is worth more than every engineering item on this page.** The
promotion gate tells you the product will not embarrass you; the beta tells you whether
pointing money at it is worth doing. Spending `08`'s budget against loops the product cannot
measure buys users and learns nothing — and spending it against a product no organiser
prefers to WhatsApp buys nothing at all.

**Recommendation: sequence the beta in parallel with closing Part A, not after it.** They
block on different things — the beta blocks on organiser recruitment, the gate on engineering.

### C.6 What is the runway, in months? (G1)
The corpus does not contain it. `08`'s Path-C pivot trigger depends on it. Without it, "how
much of the gate do we close before we spend" cannot be answered on anything but instinct.

### C.7 Does the `13b` ten or the `14` J10 one-liner own the gate?
Restated from §A.1. **Recommendation: ratify `13b`'s ten**, and record it as a numbered
decision so this is not re-litigated.

### C.8 The keystore password reuse (from `P-013`'s residue)
Not a checklist item — an immediate PO action, and in no ticket. If that string is reused on
email, Play Console, Apple or Supabase, the upload-key rotation closes nothing.

---

## PART D — What happens to this document

This is a draft for a conversation, not a commitment. After the negotiation:

- Rulings become numbered `P-nnn` entries in `docs/DECISIONS.md`, naming any corpus document
  they supersede.
- The agreed gate and release scope go into `docs/ROADMAP.md` as a named wave.
- `docs/BRIEF.md` §14 shrinks by however many of C.1–C.6 get answered.
- This file is then superseded and should be deleted rather than left to rot beside the
  documents that carry the decisions.

**Writing to the Notion corpus is the PO's, never mine.** Where a ruling makes a Notion
document stale, the decision entry names the page.

---
---

# PART E — Reconciliation with the PO's Notion checklist

Added 2026-08-29 at the PO's request. Source: **"Updated checklist"**
(`399d4c6dd86d8021b719c4df6330006e`, last edited 2026-07-18) and its parent **"Checklist"**
(`37dd4c6dd86d8039a4ddcfe48d12822c`). Both sit under **Dabbler**, not under Business docs.

**Correction to my own record first:** these are a v1/v2 pair I had not read. My corpus map
listed doc `14` at a third id (`37dd4c6dd86d800da6b5d8ced2e424d3`). My "26 documents, study
complete" claim was true of the Business docs corpus and **not** of the Checklist tree. The
v2 is the live one and supersedes both.

## E.1 The scope verdict — the PO's read is right, but the reason matters

**CONFIRMED: overbuilt for MVP.** ~157 items across five personas. But "too long" is the
less useful half of the diagnosis. The list is **wide in the wrong dimension and thin in the
one that decides whether shipping is safe**:

| | Items | Comment |
|---|---|---|
| Sport-specific integrations (D42–D51) | 10 | CricClubs, Playtomic, Strava, women-only, pace-matching |
| League engine (E17–E20) | 4 | Create league, fixtures, standings, full season |
| Organiser payments UI (E5, E8, E10, E13, E14) | 5 | For a system G1–G5 requires to be **off** |
| Venue CMS (F5–F9) | 5 | Claim, manage, post classes, respond to reviews |
| Game day beyond reminders (D36–D41) | 6 | Check-in, results, MVP vote, recap, photos, prayer times |
| **Arabic RTL** | **3** | `13b` **P0-10** — a binding launch gate |
| **Monitoring** | **2** | `13b` **P0-7** |
| **Rollback** | **0** | `13b` **P0-8** — absent entirely |
| **Security / RLS** | **0** | `13b` **P0-9** — absent entirely |
| **Analytics instrumentation** | **0** | `08` Part 2 §A.2 gate — absent entirely |

Thirty items of feature breadth that no committed document places in Phase 1A, against five
lines covering the five gates that decide whether promotion is recoverable.

## E.2 The checkmarks are claims, not evidence — and four are already disproved

42 items are `[x]`, self-reported and dated **2026-07-18**. This week's work disproved
several of them:

| Item | Marked | Reality |
|---|---|---|
| B14 "I can sign out" | `[x]` | KAN-58 — logout cleared nothing and never revoked the FCM token. Fixed **2026-08-29** |
| B7–B12 onboarding | `[x]` | KAN-83 — the onboarding back button hit a GoRouter error page on a launch-critical path. Fixed **2026-08-29** |
| D27 followers / following | `[x]` | KAN-85 — `RealFriendsScreen` was fully functional and **unreachable**, no nav item. Fixed **2026-08-29** |
| D33 report a post / block a user | `[x]` | KAN-68 — safety blocklist **fails open twice over**. Still **To Do** |
| ~~**D9 "I can delete my account"**~~ | `[x]` | ~~Apple rejected Build 174~~ — **THIS WAS MY ERROR. See `P-021`.** Deletion is live, unflagged, and a genuine hard delete. I repeated the checklist's own HTML header as if it were evidence. The real record is a **build 170** rejection, root-caused to an RPC FK violation and fixed by migration `20260701170909` |

**The point still stands on the other four, and it cost me the fifth.** The boxes record
*intent to have built*, not *verified behaviour* — B14, B7–B12, D27 and D33 all prove it.
**But D9 proves it against me**: I read a document's header as evidence, exactly the error the
boxes themselves commit. Verified before finalising, at the PO's insistence. **Recommendation
unchanged: treat every `[x]` as unverified until re-tested — and treat my own claims the same
way.**

## E.3 The v1 → v2 diff contains a live App Store risk

**v2 deleted the entire GUEST section (A1–A7, 7 items) — while v2's own I8 still requires
reviewer notes explaining "where to find guest mode."**

Either guest browsing exists and is now untested, or it does not and I8 promises the reviewer
a mode that is not there. **This app has already been rejected once under Guideline 5.1.1.**
That guideline is precisely about requiring registration for non-account-based features.

Two smaller drifts: v1 B11 assigns four roles (adds **Host**), v2 assigns three. v1 D25/D27
model **friends** (bidirectional, accept requests), v2 models **following** (unidirectional) —
v2 matches the app.

## E.4 THE TRIMMED LIST — ~30 items

Everything not listed here is either done, cut, or not MVP.

### Re-verify — doc says done, evidence says otherwise (5)
1. B14 — sign out, incl. FCM revoke and store teardown *(KAN-58 closed today)*
2. B7–B12 — full onboarding run, including back navigation *(KAN-83 closed today)*
3. D27 — followers / following reachable *(KAN-85 closed today)*
4. **B19–B21 / D9 — account deletion end-to-end on a physical device.** The rejection reason.
   The doc's own note demands it before resubmission
5. D33 — report / block actually blocks *(KAN-68 still open — fails open)*

### Gate items — genuinely open (9)
6. D8 — data export completes **in production** *(KAN-52, P0-6; review failed 2026-08-29)*
7. G1–G5 — collapse to one check: no payment path reachable, no IAP declared *(P0-5)*
8. H1 + H2 — Arabic RTL on every screen, no English leakage *(P0-10)*
9. H9 — privacy policy and terms reachable in-app, both languages
10. J6 + J7 — crash reporting live, alerts reach a phone *(P0-7 — **UNOWNED**)*
11. J9 — paid tier, backups, **restore tested** *(T-30 gate — **UNOWNED**)*
12. **Rollback rehearsed and executable solo** *(P0-8 — **not in the checklist at all**)*
13. **Security sweep** *(P0-9 — **not in the checklist at all**. KAN-78 first: 55 live
    production accounts share a known password)*
14. **One real analytics event observable in the destination** *(`08` gate — **not in the
    checklist at all**. KAN-51, review failed 2026-08-29)*

### Organiser minimum — the beta cannot run without it (6)
**E is 0/20 checked.** J3 requires each of 25 organisers to run a real game through the app.
That is impossible while the organiser persona is entirely unverified. This is the sharpest
finding in the reconciliation: **the highest-value action on the board depends on the one
persona nobody has tested.**

15. E1 — become an organiser
16. E2 + E3 — dual role held, and switchable
17. E4 — create an organised game
18. E7 — approve / add / remove from roster
19. E9 — announce to everyone in the game
20. E12 — dashboard, minimal (games + rosters; **not** earnings or targets)

### Core loop gaps that matter (7)
21. D21 + D22 — public/private and **invite link**. The WhatsApp-replacement mechanic; without
    it J4's question cannot fairly be asked
22. D34 + D35 — day-before and hours-before reminders. The actual value being substituted for
    a WhatsApp group
23. D11b — filter by date
24. D18 — search *(route fixed by KAN-84; the rest unverified)*
25. D5 — privacy settings actually persist and are reflected *(KAN-28 territory)*
26. D7 — notification preferences actually suppress *(KAN-28 territory)*
27. D16 — waitlist and auto-promotion *(lowest confidence of this group; cut if the beta
    shows games are not filling)*

### Flag, do not cut (1)
28. **C1 — the socialiser destination.** B11 is checked (onboarding assigns the role) while
    C1–C7 are 0/7 (the destination is unverified). **Assigning a user a role whose landing
    surface nobody has tested is a defect, not a scope decision.** Verify C1 alone; C2–C7 can
    wait.

### Resubmission (1)
29. I8 — reviewer notes: deletion path, payments-dormant, demo account, **and the guest-mode
    contradiction in E.3 resolved before the notes are written**

## E.5 What to cut — ~40 items

| Cut | Why |
|---|---|
| D42–D51 sport-specific (10) | **This is the cricket wedge (KAN-54), not a test list.** A PO strategy decision, not QA. Removing them from the checklist does not decide the wedge — it stops the wedge masquerading as 10 test items |
| E17–E20 leagues (4) | A league engine is not an MVP by any reading of the corpus |
| E5, E8, E10, E13, E14 payments UI (5) | Payments are dormant by G1–G5. Building organiser payment surfaces to exercise in test mode, for a feature that must be off, is the clearest waste on the list |
| F5–F9 venue CMS (5) | KAN-55: there is no venue admin surface, no per-venue page, no analytics dashboard. **F1–F4 and F10 stay** — index, view, suggest, and "coming soon" not being a broken button |
| D36–D41 game day (6) | Check-in, results, MVP vote, recap card, photos, prayer times — a second product |
| D52–D54 achievements (3) | `11 v2` §F.3 commits the 3-tier surface only; check-in already ships. Not a gate item. See KAN-29 |
| D12 map · D24 chat · D26 contacts (3) | Already marked NOT MVP in v2. Keep them cut |
| C2–C7 socialiser (6) | Deferred, but **C1 is not** — see item 28 |
| I1–I7, I9–I14 store submission (13) | **Already achieved. The app is live in two stores.** The section is spent. Only I8 survives, for the pending re-review |

## E.6 Overlap and conflict with Parts A–C

**Overlaps — the same requirement under two names.** Do not run these twice:

| Checklist | Part A |
|---|---|
| H1 / H2 | P0-10 Arabic RTL |
| J6 / J7 | P0-7 monitoring |
| J9 | T-30 backups + restore |
| G1–G5 | P0-5 payments dormant |
| D8 | P0-6 PDPL |
| J12 smoke test | P0-4 core loop in production |
| J14 crash-free ≥98% | P0-2 48h stability |
| J1–J5 | `13d` beta = question **C.5** |

**Conflicts — five, and the first is the one to settle:**

1. **This document *is* the weaker gate.** Its J10 — *"stores approved, no serious bugs,
   monitoring live"* — is verbatim the one-liner I asked the PO to rule against in **Q4**.
   **Working this checklist means adopting `14` J10 by default**, and silently dropping
   payments-dormant, data rights, rollback, security and bilingual integrity. If the PO
   ratifies `13b`'s ten, J10 must be rewritten, not just re-ticked.
2. **No security section.** P0-9 has no representation anywhere in 157 items.
3. **No analytics item.** The `08` acquisition-spend gate has no representation.
4. **No rollback item.** P0-8 has no representation.
5. **The calendar is spent.** I14 "submit by ~Aug 20", approval "by Aug 28", "Launch Day
   (Sept 1)". Today is 2026-08-29 and the app is already live. Section I is history, and
   J.3 describes a day that has passed.

**One contradiction retired.** My `corpus-contradictions` C9 recorded "OTP killed by `14`
while the app still ships it." **That was my error.** v2 distinguishes them cleanly: **email
OTP is kept** (B3, primary sign-up); **phone/SMS OTP is removed** (B15, Twilio cost). Not a
contradiction. C9 is withdrawn.

---
---

# PART F — PO rulings, 2026-08-29, and the re-derived split

Seven direct rulings. Recorded here; they become numbered `P-nnn` entries in
`docs/DECISIONS.md` once this round closes. **Two overrule me — noted as overrules, not as
agreement.**

| # | Ruling | Effect |
|---|---|---|
| 1 | **Auth + authorization must be verified in production before promoting** | **New named requirement.** Promoted from a vague stability wish to a closure criterion |
| 2 | **Payments entirely out of MVP 1** — not "dormant", not discussed | G1–G5 collapse to one QA check. **Q3 (App Fee) deferred** |
| 3 | **Monitoring out of MVP 1** | **OVERRULES my P0-7 recommendation.** Deferred, not solved |
| 4 | **No gamification in MVP 1** — QA verifies the surface is clean | Changes KAN-29 from a scope cut to a QA check. **See F.2 — conflict** |
| 5 | **Messaging deferred to MVP 1+** | Confirms `14`/`11 v2`; now explicitly scheduled rather than merely absent |
| 6 | **Venue booking out of MVP 1** | Confirms KAN-55 |
| 7 | **Financial model is post-MVP-1** | **Q2 deferred.** MVP 1 closure does not wait on it |

## F.1 Consequences I am obliged to state once, then drop

**Ruling 3 (monitoring deferred) removes the ability to evidence stability.** Not an argument
to reverse it — the PO owns the call — but the consequence must be on the record:

- `13b` **P0-2** ("48h in production, zero P0 bugs") becomes **unmeasurable**. It cannot be
  passed or failed; it can only be asserted.
- `14` **J14** ("crash-free rate above 98%") becomes unmeasurable for the same reason.
- **"Stable" for MVP 1 therefore rests on manual QA only.** That is a coherent position for a
  pre-promotion product. It stops being coherent the moment acquisition spend starts, because
  the first signal of a crash loop becomes a store rating rather than an alert.

**Recorded, deferred to MVP 1+, and not re-argued.** It should be the first item of MVP 1+,
before any spend.

**Ruling 2 (payments out) does not retire the `04` question.** Deferring Q3 is right — the App
Fee cannot conflict with a Non-Negotiable while no payment exists. But `04` Art. 33.1 still
forbids waiving it, so **the ruling must land before payments are *built*, not before they are
*launched*.** Flagged so it is not discovered late.

## F.2 Ruling 4 has a conflict with the live build

**"No gamification in MVP 1" and the shipped app disagree.**

`docs/PROJECT_STATE.md` puts **daily check-in at ~985 LOC of live, reachable code** —
`check_in_providers.dart`, `check_in_controller.dart`, `early_bird_check_in_modal.dart`,
`check_in_progress_indicator.dart` — reached from `main_navigation_screen.dart:15-16` and
`profile_check_in_widget.dart:2-3`. Streaks and check-in rewards **are** gamification, and
they are the one part of the rewards slice that is not dead.

So QA cannot simply "verify nothing is exposed" — something is. This is a decision, not a
test result. **See question 2.**

## F.3 MVP 1 — the re-derived closure list

Everything the rulings removed is gone. What remains is small.

### Locked (the PO's own requirement)
1. **Auth verified in production** — Google · Apple · email OTP · session persistence ·
   sign-out incl. FCM revoke *(KAN-58, closed today)*
2. **Authorization verified in production** — this is `13b` **P0-9**, and it is the honest
   content of "confirm it's solid". **KAN-78 first: 55 live production accounts share a known
   password `SeedBot!2025`.** Auth cannot be called verified while that is true. Then the
   remaining anon/RLS queue: KAN-26, 37, 56, 59, 68, 69, 75, 77, 80, 81, 82

### Re-verify — marked done, disproved this week (5)
3. Sign out *(KAN-58)* · 4. Full onboarding incl. back nav *(KAN-83)* · 5. Following reachable
*(KAN-85)* · 6. **Account deletion end-to-end on a physical device** — the Apple 5.1.1(v)
rejection reason · 7. Report/block actually blocks *(KAN-68, fails open, still To Do)*

### Clean-surface QA (2, cheap)
8. No payment surface reachable anywhere *(replaces all of G1–G5)*
9. No gamification surface exposed — **pending question 2**

### Open — not ruled on, and I will not assume (5)
10. Arabic RTL *(P0-10)* — **question 3**
11. PDPL export *(P0-6, KAN-52)* — **question 4**
12. The promise gap, KAN-45/46/47/48/49 — **question 5**
13. Organiser persona, 0/20 — **question 1, the one that sizes everything**
14. Socialiser destination C1 — B11 assigns the role, C1–C7 untested

### Cut from MVP 1 by ruling
Payments UI · monitoring · messaging · venue booking · gamification build · financial model

## F.4 MVP 1+ — the candidate list

Now genuinely populated, in my recommended order:

1. **Monitoring + alerting** *(ruling 3 defers it here — it should lead, before any spend)*
2. **Rollback rehearsal** *(P0-8, still unowned, never in the PO's checklist)*
3. **Analytics emission** *(KAN-51 — the `08` acquisition-spend gate; nothing is measurable
   without it)*
4. **Messaging** *(ruling 5)*
5. **Gamification** — the 3-tier surface `11 v2` §F.3 commits *(KAN-29)*
6. **The cricket wedge** *(KAN-54 — the strategic gap, not a test list)*
7. Venue booking · payments + the `04` App Fee ruling · the financial-model reconciliation

**Items 1–3 are the promotion gate.** MVP 1 can close without them; **money cannot be spent
without them.** That distinction is the whole point of the two-list split.

---
---

# PART G — FINAL: the MVP 1 closure list

**This part supersedes Parts A–F wherever they disagree.** Rulings recorded as `P-020`
through `P-024` in `docs/DECISIONS.md`. Two items were re-verified against the repo before
finalising, at the PO's insistence; **both corrected me** (`P-021`, `P-023`, `P-024`).

**MVP 1 is a player-only app, closing on stability, not surface.**

## G.1 The list — 7 items

### 1. Auth verified in production *(the PO's named requirement)*
Google · Apple · email OTP · session persistence · sign-out including FCM revoke and store
teardown *(KAN-58, closed 2026-08-29)*.

### 2. Authorization verified in production *(the honest content of "confirm it's solid")*
This is `13b` **P0-9**. **KAN-78 leads: 55 live production accounts share the known password
`SeedBot!2025`.** Auth cannot be called verified while that is true. Then the remaining
anon/RLS queue: KAN-26, 37, 56, 59, 69, 75, 77, 80, 81, 82.

### 3. Re-verify four surfaces marked done and disproved this week
Sign out *(KAN-58)* · full onboarding including back navigation *(KAN-83)* · following
reachable *(KAN-85)* · report/block actually blocks *(KAN-68 — **still open**, fails open
twice over: locale predicate never matches, RLS returns zero terms)*.

### 4. Flip `FeatureFlags.enablePayments` to `false`
`feature_flags.dart:139` is `true`. Under `P-020` payments are out of MVP 1 **entirely**, so a
live payments flag contradicts the PO's own ruling — and it is the guard that currently lets
`/transactions` render. One line; it neutralises item 5's financial half outright.

### 5. Remove the reachable fabricated social surface *(`P-023`)*
`social_search_screen.dart:616-645,709` — invented trending hashtags with fake engagement
counts and a hardcoded *"127 active in 5 km"*, **reachable from the top bar and main nav**.
Also `social_onboarding_friends_screen.dart:27-68` (5 invented people, a **simulated** contacts
permission and a "Contacts synced successfully!" that syncs nothing) and
`transactions_screen.dart:52-108` — both deep-link-only, and both cheap to delete while here.

### 6. The remaining promise-gap items
KAN-45 *(Message button → placeholder)* · KAN-46 *(`onboardingPersonaSelection` is a redirect
target with no registered route — drops users on the error page)* · KAN-47 *(two settings
screens say "saved!" and write nothing)* · KAN-48 *(onboarding can set `onboard=true` with
persona and sport rows missing; failures swallowed)*. **KAN-46 and KAN-48 are auth/onboarding
integrity and belong with item 1.**

### 7. One smoke check: account deletion end-to-end on a device *(`P-021`)*
**Not a work item.** Deletion is live, unflagged and a genuine hard delete. But nothing has
ever exercised `delete_my_account` against the live database and there is no test. One run.

## G.2 Explicitly NOT in MVP 1

Organiser persona · Arabic RTL · PDPL export *(deferred, **not cancelled** — the feature stays
on the roadmap)* · gamification *(already hidden; **no work needed** — see `P-024`)* ·
monitoring · messaging · venue booking · payments · financial model · **the beta (deleted,
not deferred)**.

**Gamification needs no ticket.** `P-024`: check-in is already invisible behind
`FeatureFlags.enableRewards = false`. The PO's premise that it "no longer stores to the
database" is false — the write path is fully intact and one `const` edit from live — but the
*ruling* holds, and nothing needs doing for MVP 1.

## G.3 MVP 1+ — the candidate list

1. **Monitoring + alerting** — `P-020` defers it here; it should **lead**, because until it
   exists "stable" cannot be evidenced, only asserted
2. **Rollback rehearsal** — P0-8, still unowned, never in the PO's checklist
3. **Analytics emission** — KAN-51, the `08` acquisition-spend gate
4. **Organiser persona** — 0/20 verified; the largest single block
5. **Arabic RTL** — the per-screen sweep, plus the native review `06` gates on an unstaffed
   copywriter
6. **PDPL data export** — KAN-52, deferred not cancelled
7. **Messaging**
8. **Gamification** — the 3-tier surface `11 v2` §F.3 commits *(KAN-29)*
9. **The cricket wedge** — KAN-54, the strategic gap
10. Venue booking · payments + the `04` App Fee ruling · the financial-model reconciliation

**Items 1–3 are the promotion gate. MVP 1 closes without them; money cannot be spent without
them.** That is the whole point of the split.

## G.4 The two things I got wrong, kept visible on purpose

1. **`P-021`** — I claimed Apple rejected Build 174 for account deletion and the app was
   awaiting re-review. **Wrong.** I repeated an HTML comment inside the Notion checklist as
   evidence. The real record is a build **170** rejection, root-caused to an RPC foreign-key
   violation, fixed by migration `20260701170909` and folded into the baseline.
2. **`P-023`** — I carried KAN-49's *"invented AED transactions"* headline. **Wrong in both
   directions.** Venue prices are real; the fabricated data that actually reaches users is
   **social**, not financial.

Both were caught because the PO pushed back and asked for verification rather than accepting
the framing. **The standing rule holds and I broke it twice: judge from the corpus, take code
facts from `master-analyst`/`cto`, never from my own reading of a document's self-description.**
