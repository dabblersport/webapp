<!-- ============================================================
FILE STATUS: AWAITING PO INPUT
Structure drafted. Only PO-stated facts are filled in; everything
else is marked NEEDS PO INPUT rather than inferred from the code.
Delete this banner when the PO has answered §8.
============================================================ -->

# docs/BRIEF.md — Project Brief

> **INTERNAL ONLY. NEVER PUBLISHED.** Commercial and strategic objectives that must not
> appear in the app, the store listings, or any public artifact.

**Owner:** master-analyst (write, **from PO input**) · all agents (read)
**Purpose:** Why Dabbler exists and what winning looks like. An agent that does not know
what the product is for makes locally-correct, globally-wrong decisions.

---

## WHY THIS FILE IS MOSTLY EMPTY

Every other document in `docs/` was filled from measurement — the tree, the database, the
git history. **This one cannot be**, and filling it that way would be actively harmful.

The codebase is a year old and has been rebuilt at least twice. It contains 20,545 lines of
unreachable rewards code, a complete second architecture nothing routes to, 62 feature flags
describing features that already ship, and six routes that say "Coming Soon". **Inferring
product intent from that would encode abandoned strategy as current truth** — and because
this file sits above `ROADMAP.md` in the precedence order, every future scoping decision
would inherit the error.

So: what the PO has actually said is written down. Everything else is a question in §8.

---

## 1. WHAT DABBLER IS

**PO-stated** (`CLAUDE.md`, the PO's own words):

> Dabbler is a Flutter social gaming platform for discovering, joining, and organizing
> sporting events.

**NEEDS PO INPUT** — the three-sentence version for someone who has never seen it. In
particular: is the centre of gravity *discovery* (find a game near me), *organisation*
(run my recurring game), or *the social layer* (my sports circle)? The codebase invests
heavily in all three, which is a symptom rather than an answer.

## 2. WHO IT IS FOR

Three archetypes are **structural in the system** — `player`, `host`/`organiser` and venue
roles exist as tables, with `rpc_act_as` for switching between them and triggers enforcing
persona rules. That establishes the model exists; **it does not establish which archetype
the product is actually for.**

| Archetype | What they need | Status |
|---|---|---|
| Player | | **NEEDS PO INPUT** |
| Organiser | | **NEEDS PO INPUT** |
| Venue | | **NEEDS PO INPUT** |

**The question that matters:** are these equal citizens, or is one primary and the others
supporting? The flags `enablePlayerGameCreation` and `enableOrganiserGameJoining` carry
comments asserting that players *cannot* create and organisers *cannot* join — while both
values are set to `true`. Somebody once had a clear model of who does what. **NEEDS PO
INPUT** on which half is current.

## 3. THE PROBLEM IT SOLVES

**NEEDS PO INPUT.** Stated as the problem, not the feature list.

The useful form is a sentence about a person's day that is worse without Dabbler. Not
"users can browse nearby games" — something closer to *"you moved to a new city and there is
no way to find a five-a-side that will actually have ten people at it."*

The feature list is already documented in `PROJECT_STATE.md`. What is missing is the
sentence the features are meant to answer.

## 4. SUCCESS CRITERIA

**NEEDS PO INPUT.** Measurable and time-bound.

Two things are worth knowing before this is answered:

- **There is currently no way to measure anything.** `AnalyticsService` has 18 methods and
  every one is an empty body. The backend for it already exists (`rpc_track_event`,
  `analytics_events` with policies) — the client sends nothing. Any success criterion
  involving user behaviour is unmeasurable until that is wired (KAN-34 / ROADMAP Wave 3).
- **Whatever the criteria are, they should name the instrument.** A criterion nobody can
  compute is indistinguishable from not having one.

## 5. NON-GOALS

**NEEDS PO INPUT** — and this is the section I would push hardest to get answered.

The audit found the cost of not having it: 113 feature flags, 62 of which describe things
that already ship and 38 of which describe things nobody has decided to build. A written
non-goal is what lets an agent — or the PO at 1am — say *no, that is not what this is*
without re-litigating it.

Candidate non-goals the codebase raises but **cannot answer**. Each is a real fork:

| Question | Why it is open |
|---|---|
| Is Dabbler a **payments/booking** product? | `wallets`, `payouts`, `payment_intents`, `venue_bookings` all exist with policies; the `payments` slice has zero importers |
| Is it a **messaging** product? | `messaging` gates three routes that all render "Coming Soon"; nothing is built |
| Is it a **gamification** product? | `rewards` is 20,545 LOC, unreachable, and its flag is the only one set to `false` |
| Is it a **venue marketplace**? | Venue submission and approval ships end to end; venue *booking* does not |
| Is it **competitive** (leagues, challenges) or **casual**? | `challenges`, `challenge_fixtures`, `challenge_stages` exist server-side with no client |

**Answering "no" to any of these is more valuable right now than answering "yes"**, because
a "no" retires code, flags, and tables that currently cost attention on every audit.

## 6. CONSTRAINTS

**Verified facts** — these are observed constraints, not inferred intent:

| Constraint | Detail |
|---|---|
| Platforms | iOS, Android, Web — all three actively shipped |
| Store compliance | Apple App Review is a live gate. EULA acceptance and UGC report/block were built for Guideline 1.2 (`c5a83e9`) |
| Languages | English + Arabic, 489 keys each, RTL supported |
| Auth | Passwordless by design — OTP only, password optional (decision 002) |
| Backend | Single Supabase project, `wtncuzcskpigqpmnxwws` |
| Web hosting | Cloudflare Pages; `main` → app.dabbler.pro, `Canary` → canary.dabbler.pro |
| Team | The PO, plus four agents. **No other human contributors in the git history** |

**NEEDS PO INPUT:** budget · runway · target launch or growth dates · whether the
single-maintainer constraint is permanent (it is the strongest argument for aggressive
scope-cutting, and the roadmap should reflect it either way).

## 7. WHAT WOULD MEAN THIS FAILED

**NEEDS PO INPUT.**

Worth answering separately from §4. Success criteria describe the target; this describes the
outcome that would mean stopping. A project with no stated failure condition tends not to
have one.

---

## 8. THE QUESTIONS — answerable in one exchange

Ordered by how much they unblock. **1, 2 and 5 are the ones that change what gets built
next**; the rest can follow.

1. **In one sentence: whose problem does Dabbler solve, and what is that problem?**
   Not the feature list — the situation that is worse without it.

2. **Which archetype is primary — player, organiser, or venue?** And is the other-two
   relationship "supporting" or "equal"? This settles the flag contradiction in §2.

3. **Pick the centre of gravity:** discovery, organisation, or the social layer. If the
   honest answer is "all three", say so — it is a valid answer with real cost, and it should
   be a written decision rather than a default.

4. **What does a good week look like in numbers?** Even roughly. It determines whether
   wiring analytics is urgent or not.

5. **Say "no" to at least two of the five forks in §5.** Payments, messaging, gamification,
   venue marketplace, competitive leagues. Each "no" retires code and flags immediately.

6. **Is the single-maintainer constraint permanent for the next 6–12 months?**

7. **What outcome would make you stop?**

**On the two blocking rulings elsewhere:** KAN-29 (rewards) and KAN-30 (clean-architecture
stack) are technically separable from this file, but question 5 largely answers KAN-29. If
gamification is a non-goal, rewards is cut and 19,560 lines go with it.

---

## 9. HOW THIS FILE GETS FINISHED

The PO answers §8 — in prose, in any order, however briefly. master-analyst transcribes the
answers into §§1–7, records anything that reads as a ruling in `DECISIONS.md`, and deletes
the banner at the top.

**Nothing in §§1–7 is filled by anyone reading the code.** That is the rule this file exists
under, and the reason it is the last document in the system rather than the first.
