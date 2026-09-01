---
name: mvp1-is-player-only
description: MVP 1 is a player-only app closing on stability (P-020..P-024); what is in, what moved to MVP 1+, and the beta being deleted rather than deferred
metadata:
  type: project
---

**MVP 1 = player-only, closing on stability, not surface.** Ruled by the PO 2026-08-29,
recorded as `P-020`–`P-024` in `docs/DECISIONS.md`. Final list: Part G of
`docs/briefs/MVP1-PLUS-LAUNCH-CHECKLIST-DRAFT.md`.

**In MVP 1 (7 items):** auth verified in production · **authorization** verified in production
(KAN-78 leads — 55 prod accounts share `SeedBot!2025`) · re-verify 4 disproved surfaces ·
flip `enablePayments` to false · remove the reachable fabricated social surface · the
promise-gap tickets · one deletion smoke check.

**MVP 1+:** monitoring (leads) · rollback · analytics · organiser · Arabic RTL · PDPL export
(deferred, NOT cancelled) · messaging · gamification · cricket wedge · venue booking ·
payments + the `04` App Fee ruling · financial model.

**Why it matters:** anything touching organiser, venue, payments, messaging or Arabic is MVP 1+
**by decision**. Do not re-litigate per-ticket.

**The beta is DELETED, not deferred** (`P-022`). I had ranked it the highest-value action
available and was overruled. Consequence to carry: *"would you use this instead of WhatsApp?"*
was the only committed instrument for testing the substitution thesis; retiring it removes the
mechanism, not the question, and no document now specifies a replacement.

**Monitoring deferral has a stated cost:** P0-2 and the crash-free target become
*unmeasurable*. "Stable" for MVP 1 rests on manual QA alone — coherent pre-promotion, not
coherent once spend starts.

Related: [[mvp1-plus-gate-prep]], [[launch-gate-is-13b]], [[stay-in-evidence-domain]],
[[corpus-map]].
