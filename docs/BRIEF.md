# docs/BRIEF.md — Project Brief

> **INTERNAL ONLY. NEVER PUBLISHED.** Commercial and strategic objectives that must not
> appear in the app, the store listings, or any public artifact.

**Owner:** `cpo` (write) · all agents (read)
**Source of record:** the 26-document business corpus under the Notion page
**Business docs** (`3c9d4c6dd86d80c08d66fd95416b23e4`). Reconciled against
`docs/PROJECT_STATE.md` (audit of 2026-08-26/27, `master-analyst`).
**Filled:** 2026-08-27 · **Precedence inside the corpus:** `00 executive summary` →
`02 monetization architecture` → `03 investment memorandum` → everything else.

---

## 0. THE VERDICT — is the business ready for a commercial launch?

**No. Not on any reading of the corpus, and the corpus itself is the strongest witness
against it.**

Doc `13b` writes the bar down and makes it binding:

> "The go/no-go gate (Section C) is binding. If a P0 criterion is red, you hold the launch.
> No exceptions, no 'we'll fix it live.'"
> — *13b launch runbook and day-0 operations*

Four of its ten P0 criteria are red against measured build state, and a fifth condition
that the GTM playbook makes a launch gate — analytics instrumentation — is red as well.
Separately, the product the corpus sells is not the product that shipped: the launch sport
has no launch feature in it.

**The distinction that matters.** The app is already live on both stores. It is not
*promotable*. Nothing here argues for pulling it; everything here argues against spending
the $250K acquisition budget or sending the venue pack until §10's blockers close.

The full analysis is §§10–13. §§1–7 are the brief proper.

> **CORRECTION, 2026-08-27.** Three code claims in the first version of §10 were wrong and
> have been fixed below: **B3 is retracted in full** (Arabic switching works), **B5's count
> was wrong** (4 empty methods, not 18 — the finding survives and its scope shrinks), and
> **B6 is restated** (no cricket *wedge*, not no cricket *feature*). **B2 was understated in
> my favour** — the file is 2,092 lines, not ~1,500. All three errors were code
> measurements I took directly instead of from `PROJECT_STATE.md` or from `cto`. The lesson
> is in `docs/LEARN.md`; the corpus findings — which cite documents I read — are unchanged.
> **The verdict is unchanged: B1 and B2 carry it on their own.**

---

## 1. WHAT DABBLER IS

**Committed, `00 executive summary`:**

> "Dabbler is the global coordination, identity, and discovery layer for amateur sport.
> Players find games, build verified athletic identities, and progress through measurable
> history. Venues fill courts. Federations discover hidden talent. Sponsors reach authentic
> athletes. … One platform. Five integrated layers."

The five layers, per `03 investment memorandum` §4.2 and `05 pitch deck` slide 4:
**Game Lifecycle · Sports Identity · Gamification Engine · Social Layer · Venue Layer.**
`03` §4.2 is explicit that no one layer is the product: *"most competitors operate one or
two of these layers. Dabbler operates all five. Integration is not a feature — it is the
unit of competition."*

**The centre of gravity — the corpus does answer this.** `master-analyst` left it open
because the codebase invests in discovery, organisation and the social layer equally. The
corpus does not:

| Layer | Its stated job |
|---|---|
| **Coordination** | The revenue-bearing centre. `02` Part X: *"The metric that overrules all others — the North Star — is: **Games confirmed.**"* |
| **Belonging** | The promise, and the acquisition mechanism. `01` Part IV: *"Belong. Then play. … The sport is the medium. The belonging is the product."* |
| **Identity** | The long-term asset, not the launch value. `02` Layer 2 activates Year 2–3. |

So: **organisation is the centre of gravity, belonging is the pitch, identity is the moat.**
Discovery is a means to the first, not an end.

**Note the brand constraint.** `01` Part IX and `06b` §2.3 permanently retire the words
"revolutionary", "disruptive", "game-changing", "world-class", "next-generation", and
`06a` §1.13 bans framing Dabbler as "the Airbnb of X" or "the Tinder of Y". These bind
store copy and marketing.

## 2. WHO IT IS FOR

**Three commercial audiences and one philosophical one** — `03` §4.3:

> "The commercial audiences are: **players** (free, the network), **venues** (paying, the
> marketplace), and **institutions** (paying, the infrastructure — sponsors, federations,
> governments, brands). … The philosophical audience is the **Hidden Talent**."

They are **not equal citizens.** The hierarchy is stated:

| Archetype | Role | Citation |
|---|---|---|
| **Player** | The network. Free forever. Never the customer. | `02` Part I: *"The players are the asset. The ecosystem is the customer."* |
| **Organiser** | The **wedge** — the distribution engine and the primary paying persona. | `01` Part VI: *"Every Organizer Dabbler converts is worth twenty regular users."* `13d` A.1: *"The beta cohort is **Organisers, not Players** — because Organisers are the distribution engine (each brings 20–50 players) and the primary paying persona."* |
| **Venue** | The **first customer**. Pillar 1, first revenue. | `02` Pillar 1: *"The first dollar Dabbler ever earns comes from here."* |
| Socialiser | Community density only. | `11 v2` B.1: *"EXCLUDED from financial model."* |
| Guest | Browse-only, no account. Store-compliance requirement. | `14` A1–A7 |

**This retires the flag contradiction in the codebase.** `enablePlayerGameCreation` and
`enableOrganiserGameJoining` carry comments asserting players cannot create and organisers
cannot join, while both values are `true`. The corpus settles it — **the values are right
and the comments are wrong**:

> `11 v2` B.1 — Player: *"Can Create: ✅ **Casual games only**"*. Organiser: *"Can Create:
> ✅ Organised games + leagues"*. *"A single user account can hold up to **2 simultaneous
> profiles** (Player + Organiser)."*
> `14` E2: *"As an organiser, I can keep my player profile too."*

A player creates **casual** games (no fee, no uplift, off-platform payment). An organiser
creates **organised** games (in-app payment, uplift). Both can join. The rule is about
*game type*, never about *access*.

**Launch persona focus** — `13d` B.1, the 25-organiser beta: Cricket 8 · Football 6 ·
Padel 5 · Indoor Fitness 3 · Running 3.

## 3. THE PROBLEM IT SOLVES

**Committed, `02` Part II / `03` Part II — four named failures:**

1. **Coordination.** *"In every major city on Earth, the same pattern repeats: a group chat,
   a flurry of messages, a partial commitment, a venue booked too late or double-booked, a
   game that falls apart, and a player who shows up to an empty pitch."* (`03` §2.1)
2. **Recognition.** *"A player who has been the best left-back in his Sunday league for six
   years has nothing to show for it. … no history that survives the deletion of a WhatsApp
   group."* (`03` §2.1)
3. **Talent discovery.** *"A 19-year-old in a small Egyptian city with elite footballing
   instincts has, in practice, almost no probability of being seen by a European scout."*
4. **Capital allocation.** Sports-facility investment made without an amateur demand signal.

**The sentence about a person's day**, from `01` Part III: *"The expat who lands in a new
city and watches her group chat go quiet."*

**Who the actual incumbent is** — this is the operative competitive fact and it is
load-bearing for product decisions:

> "**The actual incumbent for amateur sports coordination in MENA is WhatsApp.** … The
> opportunity is not 'build something WhatsApp users switch to.' It is 'build something
> WhatsApp users **add to**.'" — `07 competitor analysis`, research briefing §5

That is why `10 marketing psychology` §A.3 makes WhatsApp share-out a product requirement,
not a nice-to-have: *"every Dabbler event must share natively into WhatsApp groups"*, with
a trip-wire — *"If WhatsApp share-out is < 25% of new signups, the product has not earned
cultural fit. … Pre-Series A, this must be fixed. Engineering priority."*

## 4. SUCCESS CRITERIA

The corpus contains **two complete, time-bound, mutually incompatible sets.** Both are
reproduced. Choosing between them is a PO ruling (§13, Q1) — I do not pick silently.

**Set A — the institutional plan** (`03` §9.2, echoed in `00`, `02` Part VII, `05` slide 11):

| Gate | Criteria |
|---|---|
| Month 6 | *"30+ active venue partnerships · 25,000+ monthly active users · 5,000+ games confirmed and played through the platform monthly · 40%+ monthly retention … · First-game time … under 7 days"* |
| Month 12 | *"75+ active venue partnerships · 80,000+ monthly active users · Booking commission revenue run-rate of AED 350K+/month · LTV/CAC ratio above 4x"* |
| Month 24 | *"200,000+ monthly active users · First major brand sponsorship contracted (target: AED 500K+) · Player Premium … conversion rate above 5%"* |

**Set B — the operating plan** (`07d` §4.9/§4.23, `08` Part 2 §B–D, `12c`):

| Gate | Criteria |
|---|---|
| Month 3 | *"10,000-15,000 cumulative downloads · 1,500-3,000 MAU · 60% MAU from cricket · 5-7 cricket leagues"* |
| Month 6 | *"25,000-50,000 cumulative downloads · 5,000-10,000 MAU · 10+ active cricket leagues"* |
| Month 9 | *"50,000-100,000 cumulative downloads · 10,000-20,000 MAU · Seed round closed: $1.5-3M at $8-12M post-money"* |
| Month 36 | *"75,000+ MAU across UAE and Egypt · 150,000+ verified player profiles · Material revenue ($5-15M ARR)"* |

Set A's Month-6 MAU target is **10× Set B's Month-9 target.** Set A's Month-12 revenue
run-rate (AED 350K/month ≈ $1.1M/yr) is **~13× `12c`'s base Year-1 total of $82K.**

**The north star is also contested.** `02` Part X and `01` Truth 7 both name **"Games
confirmed"** as the metric that overrules all others. `08` Part 2 §H.1 names **"Cross-sport
active users (CSAU): Users active in 2+ sport lanes per month"** as the north star. Two
documents each claim the overruling position.

**None of it is currently computable.** See §10, Blocker 5.

## 5. NON-GOALS

`master-analyst` listed five open forks. **The corpus answers four of them, and the answers
are the opposite of what the codebase implies.**

| Fork | Corpus verdict | Citation |
|---|---|---|
| **Payments / booking** | **IN SCOPE — but deferred to Phase 1B (Month 9).** Not a non-goal; a not-yet. | `11 v2` F.3: *"Venue booking flow (deferred to Stage 1B Month 9)"*. `13a` Appendix C: *"In-app venue booking (the booking suite) — Phase 1B"*, *"Booking infrastructure is explicitly OUT"* of the 90-day plan. `12b` A.2: *"M11: Venue Booking commission (after 2-month grace)"* |
| **Gamification** | **IN SCOPE, at 3 tiers.** Named as one of the five product layers. The 15-tier system is Stage 2. | `05` slide 4: *"GAMIFICATION ENGINE Progression, recognition, status"*. `11 v2` F.3: *"15-tier achievement system (defer to Stage 2 with light **3-tier MVP**)"*. `13a` Sprint 11 gate: *"✅ 3-tier achievements"*. `14` D52–D54 |
| **Venue marketplace** | **IN SCOPE. It is Pillar 1 and the first revenue line.** | `02` Pillar 1, *"Activation: Day One"* |
| **Competitive leagues** | **IN SCOPE at launch.** | `14` E17–E20: *"create a league and invite teams"*, *"standings update automatically"*, *"run a full season"*. `11b` B.10 features 291/292/294/295/300 = Phase 1A |
| **Messaging / in-app chat** | **OUT of Phase 1A.** No launch checklist story exists for it. Whether it is ever in scope is **NOT ESTABLISHED**. | `14` has no chat user story in any persona section. `11 v2` F.3 defers the *"Organiser Community Channel"* to Stage 2. `11b` B.14 messaging features 439/446 = Phase 1B |

**Consequence for the two blocking rulings elsewhere:**

- **KAN-29 (rewards, 20,545 LOC unreachable).** Gamification is *not* a non-goal — so the
  slice cannot simply be buried. But the committed launch scope is a **3-tier**
  Bronze/Silver/Gold achievement surface plus streaks (`14` D52–D54), which
  `PROJECT_STATE.md` puts at ~985 LOC of live check-in code. The 15-tier system, the
  achievement analytics dashboards and the 7 orphaned dashboard classes are **Stage 2
  scope at the earliest**, and three of those dashboards render literal "Coming Soon".
  My recommendation to the PO: keep the 3-tier surface, cut everything above it, and
  revisit at Stage 2 rather than carrying 19,560 lines against a Month-12+ feature.
- **KAN-30 (clean-architecture stack).** The corpus is silent on internal architecture.
  **NOT ESTABLISHED** — this is the CTO's call, not mine.

**Non-goals the corpus does state outright**, and which bind absolutely:

> `01` Permanent Truth 4 / `04` Non-Negotiable 4: *"Dabbler will never become a sports
> betting platform. Not under any partnership. Not in any market. Not via any subsidiary."*
> `12b` I.3: *"No gambling, betting, stakes / No prediction markets / No fantasy with
> monetary outcomes / Tournament prizes are sponsor-funded (not stake-pooled)."*
> `08` Part 2 §I.2: *"**Day-0 strip: no prediction/cash-prize features**"* — the moment an
> entry fee meets a prize, UAE **GCGRA** classifies it as commercial gaming.
> `Sport Reference` §F excludes mind sports, esports and poker for the same reason.

## 6. CONSTRAINTS

**From the corpus:**

| Constraint | Detail |
|---|---|
| **Launch market** | UAE, **Dubai-first**. `08` Part 1. *"The UAE is not the destination. It is the proof."* (`05` slide 4) |
| **Launch date** | **September 1, 2026.** `11 v2`: *"The MVP ships September 1, 2026."* `13a`, `13b`, `13c`, `13d` all build to it |
| **Team** | Solo founder. `08` Part 1: *"**Founder-only operation.** No co-founder, no early hires."* First non-founder hire Month 10–12 |
| **Budget** | `08` Part 1: *"**Sub-$250K total launch budget** across 9 months."* `14`: *"the budget is **$0**"* — see §11, contradiction C11 |
| **Languages** | Arabic + English **at parity from launch**. `06e` §5.3: *"Bilingual at parity. … Not 'Arabic version coming soon.'"* `06b` §2.5: *"Arabic Dabbler is not English Dabbler in Arabic"* — must be *"written or reviewed by a native Arabic copywriter"* |
| **Regulatory** | UAE **PDPL** (consent, export, deletion, 14-day data-subject SLA); **GCGRA** no-gaming; VAT 5% UAE included in displayed prices; wallet float above AED 50K requires a **Central Bank SVF licence** at *"AED 200-400K"* (`12b` I.1) |
| **Cultural** | Ramadan-aware scheduling (post-iftar 8pm–2am), prayer-time-aware notifications, women-only mode (`Sport Reference`: *"52% of UAE operators offer women-only services"*) |
| **Ethical** | The seven **Permanent Truths** (`01` Part XII), re-stated as the seven **Non-Negotiables** (`04` Art. 32). `01`: *"reviewed never."* |

**Verified from the repo** (`PROJECT_STATE.md`, `CLAUDE.md`): iOS + Android + Web all
shipped; passwordless OTP auth; single Supabase project `wtncuzcskpigqpmnxwws`; Cloudflare
Pages `main` → app.dabbler.pro, `Canary` → canary.dabbler.pro; no human contributor other
than the PO in the git history.

**NEEDS PO INPUT — runway.** Neither financial document states a runway in months, a cash
balance, or a closing-cash line. `12c` F.3 says only: *"provides **substantial runway** —
the capital extends rather than merely sustains."* For a solo founder deciding whether to
commit $250K to a launch, this is the single most important number the corpus does not have.

## 7. WHAT WOULD MEAN THIS FAILED

**The corpus answers this well.** Three independent falsification sets:

**Path C — Pivot** (`08` Part 2 §J.2). Triggered if **any** of:

> "MAU below 5,000 at Month 9 · Seed not closed by Month 9 + 30 days · Cricket-first wedge
> failed (less than 6 active leagues) · Multi-sport thesis failed (CSAU below 15% of MAU) ·
> Major partnership failure (ECB explicitly declined) · Cash reserves below 90 days at
> current burn"

**Thesis falsification** (`03` §9.2–9.3):

> "Sub-15% conversion from signup to first game indicates a product-market fit failure ·
> Venue churn above 25% per quarter … · CAC above AED 100 per active user with no
> improvement trajectory indicates positioning failure"
> Decision Point 3 (Month 24): *"If the company remains single-layer, the empire thesis is
> falsified and the company is repositioned as a regional marketplace."*

**Marketing trip-wires** (`10` §I.2): Cricket Captain D30 < 50% → *"consider pivoting wedge
to padel"*. WhatsApp share-out < 25% of new signups → *"the product has not earned cultural
fit"*. Influencer ROI < 3:1.

**The corpus's own probability estimate** (`07d` §4.9): *"**Dabbler fails to achieve
meaningful traction — 25-35%**"*, against *"Dabbler wins UAE cricket coordination layer —
40-55%"*.

**And the failure mode the corpus names for itself** — `07d` §4.24, Failure Mode 5:

> "**Strategic Drift.** Sport sequencing hedged ('we'll do all three equally') … **Root
> cause:** Documents 1-6 + this competitor analysis treated as reference material rather
> than operational doctrine."

That is the failure currently in progress. See §11.

---

# THE LAUNCH-READINESS GAP ANALYSIS

*Sections 8–13 are the assessment. §§1–7 above are the settled brief.*

## 8. Method

26 documents read via the Notion MCP (read-only), reconciled against
`docs/PROJECT_STATE.md` — the measured build state, owned by `master-analyst`, which I read
rather than re-measured. Where I needed a fact the audit did not carry, I ran a
read-only `grep` over `lib/` and `supabase/` and say so at the point of use.

Every finding below cites a document. **A gap I cannot point at is an opinion, and it is
not in this file.**

## 9. What we have actually committed to

The short version, so the rest of this section has a baseline:

- **Positioning.** Amateur Sports Infrastructure — coordination + identity + recognition +
  discovery, integrated. Launch UAE.
- **Monetization.** *"Free for players. Paid by the ecosystem around them."* Seven pillars
  across three layers; venue partnership first, identity second, infrastructure third.
- **GTM.** Cricket-first wedge inside the Dubai Cricket Council ecosystem, solo founder,
  sub-$250K, September 2026, organic loops over paid acquisition (*"the network is the
  marketing"*), 25 captain wedges, 25-organiser beta.
- **Venue model.** Three tiers — Pilot (free, 3 months) → Standard (revenue share 5–15%) →
  Premium. Dabbler *pays* strategic leagues a sponsorship (`$15–30K/year`) and *charges*
  venues a listing fee plus commission.
- **Subscriptions.** Free tier permanent and genuinely useful; Player Pro AED 29/mo,
  Organiser Pro AED 99/mo, Venue Basic AED 99/mo, Verified Venue Pro AED 299/mo, Corporate
  AED 7.5–25K/yr. **All activate at Phase 1B (Month 9) — during Phase 1A everything is
  free for everyone** (`12a` A.3).

## 10. The blockers — what stops promotion

Ranked by whether they block, not by effort. **B3 is retracted** — the numbering is kept so
that KAN-51…KAN-55 and the entries in `DECISIONS.md` still resolve.

| | Blocker | Gate it fails | Status | Ticket |
|---|---|---|---|---|
| **B1** | Unauthenticated cross-tenant data leak | `13b` P0-9 | stands | KAN-36/37/38 |
| **B2** | PDPL data export unreachable — 2,092 LOC, zero importers | `13b` P0-6, `14` D8 | stands | KAN-52 |
| ~~B3~~ | ~~Cannot switch to Arabic~~ | — | **RETRACTED — false** | KAN-53 closed |
| **B4** | "Message" button on every profile → "Coming Soon" | `14` H6 | stands | KAN-45 |
| **B5** | Analytics sink is 4 empty methods — the app emits nothing | `08` Part 2 §A.2 | stands, **rescoped** | KAN-51 |
| **B6** | No cricket **wedge** (integrations absent; the sport is supported) | — | stands, **restated** | KAN-54 |
| **B7** | Venue pack contracts deliverables that do not exist | — | stands | KAN-55 |

**Four blockers plus two holds.** B1 and B2 carry the verdict on their own: a live product
leaking personal data to unauthenticated callers, and a legally-required data-subject right
that exists as 2,092 lines of unreachable code.

### B1 — An unauthenticated cross-tenant data leak. `13b` P0-9 is red.

The gate: `13b` P0-9 — *"No critical security gap | RLS verified; no unauthorized data
access; secrets not exposed."* `13b` T-30 requires *"run the anon-key probe to confirm no
unauthorized read/write."*

The measurement, `PROJECT_STATE.md` §1.1:

> `public.v_notifications_feed` and `v_notifications_ranked` are `SECURITY DEFINER` views
> over `notifications` with **no `WHERE to_user_id = auth.uid()`**. Queried as the `anon`
> role — the key that ships inside the public web bundle — they return **609 rows across 49
> distinct recipients**, exposing `to_user_id`, `title`, `body`, `action_route`, `context`.
> No login required.

Also anon-readable: `v_mod_queue_open` (9 open moderation tickets) and `v_safety_overview`.
Of 71 views, 49 are `SECURITY DEFINER` and **19 are anon-readable with no uid predicate** —
5 confirmed leaking, **12 never examined.**

This is not only a P0. It falsifies a written sales promise:

> "Dabbler is **PDPL-compliant** — explicit consent flows, data subject rights, encryption,
> breach reporting." — `09 venue partner deck`, §G.1 Objection 7

Sending that pack today is representing a compliance posture the database contradicts.
Owner: `cto`. This is the only blocker where I would hold everything else until it closes.

### B2 — PDPL data export is not reachable. `13b` P0-6 red; `14` D8 is a self-declared blocker.

`14` names its own top-five blockers; D8 and D9 are two of them:

> "**D8** — data export · **D9** — in-app account deletion *(store-required)*"
> "**Why D8/D9 matter**: App stores **require** in-app account deletion. PDPL requires data
> export. These are not optional."

Deletion works (`PROJECT_STATE.md` flow 5). Export does not. `lib/features/profile/services/
data_export_service.dart` is **2,092 LOC** (verified 2026-08-27 — I had understated this at
~1,500) and `grep` over `lib/` returns **zero importers**
outside the file itself; `PROJECT_STATE.md` PROV-01 lists `dataExportServiceProvider` among
the 113 providers referenced only by their own declaration.

This also breaches a commitment made to institutional partners, not just to regulators:

> "**Right 3: The Right to Portability.** Every player has the right to take their Dabbler
> identity … The identity is the player's, not the platform's." — `04` Art. 11
> `04` Art. 10.1: *"These rights are reflected in Dabbler's terms of service."*

### ~~B3 — Arabic is at parity in the strings and not in the product~~ — **RETRACTED**

**This was wrong, and it was ranked a promotion blocker. Language switching works.**

Verified 2026-08-27:

- `lib/features/profile/presentation/screens/settings/settings_screen.dart:104` renders a
  **Language** row; `:1064` opens `_showLanguagePicker()`; `:1091` reads and writes
  **`localeProvider`** — the real provider that `lib/main.dart:254` watches and `:268`
  passes into the app as `locale:`. The picker is the live path and it works.
- `lib/core/providers/locale_provider.dart` also resolves the device locale on the first
  frame (`_deviceLocale()`), so an Arabic device gets Arabic before any user action.
- `lib/app/app_router.dart:1287` separately routes `/settings/language` to
  `LanguageSelectionScreen` — 226 lines, **no "Coming Soon" text**.

**Where my error came from, precisely.** `PROJECT_STATE.md` WIRE-10 attributes the
placeholder at `app_router.dart:590` to the path `/settings/language`. It does not belong
to that path — line 590 belongs to **`/language_selection`**, a separate orphaned route
that nothing navigates to. I repeated the record's attribution and then escalated it to a
blocker on my own authority without opening the screen. **`PROJECT_STATE.md` WIRE-10 needs
correcting** — that is `master-analyst`'s record, not mine.

**Residual, and it is cleanup rather than a gate:** three language surfaces exist, two of
them unreferenced (`/language_selection` placeholder, `/settings/language` →
`LanguageSelectionScreen`, and the live settings picker), and `LanguageSelectionScreen`
talks to `MockLocalizationService` rather than `localeProvider` — harmless only because
both persist to the same `mock_language` key. Belongs to the dead-route sweep (KAN-32),
not to the promotion gate.

**What survives from this section.** `06e` §5.3 (*"Bilingual at parity … Not 'Arabic
version coming soon'"*) still binds, and `13b` P0-10 still requires *"Arabic RTL verified
on **every screen**"* — which is a QA sweep nobody has run, not a broken switcher. And
`06b` §2.5 / `13d` G.3 still require a **native Arabic copywriter** to sign off the copy,
who is not staffed (§11, C11). Neither is a blocker on the evidence I have; both are open.

### B4 — The most visible surface in the app is a dead button.

`PROJECT_STATE.md` §16a, flagged CRITICAL:

> `user_profile_screen.dart:1094` renders a **"Message"** button on the routed
> `UserProfileScreen`. … That route resolves to `_PlaceholderScreen(title: 'Chat: …')` at
> `lib/app/app_router.dart:1617` — a construction icon and the words "Coming Soon".
> **This is the single most visible broken promise in the app. It is on the profile of
> every other user.**

Against `14` H6 (*"No broken links or dead buttons anywhere"*), `14` F10 (*"Any feature that
isn't live yet … must show an honest 'coming soon' label, never a dead/broken button —
stores reject broken flows"*), and `13c`'s pre-submission list (*"No dead/placeholder
buttons"*).

**Re-verified 2026-08-27, and narrowed.** `master-analyst` corrected WIRE-09 to say all
seven placeholder routes are unreachable — *"Zero navigation sites"* for all six owning
constants. **That is right for five of them and wrong for `socialChat`**, which is the one
this blocker rests on. Checked directly:

- `lib/features/profile/presentation/screens/profile/user_profile_screen.dart:1475` —
  `context.push('${RoutePaths.socialChat}/$userId')`. **One live navigation site.**
- The Message button at `:1093` is rendered unconditionally (`onPressed: () =>
  _sendMessage(context)`), on a screen routed at `app_router.dart:1463`.
- The route at `app_router.dart:1607` carries a guard —
  `if (!FeatureFlags.messaging) return RoutePaths.home;` — but
  **`FeatureFlags.messaging = true`** (`feature_flags.dart:53`), so the guard does not fire
  and the user lands on `_PlaceholderScreen(title: 'Chat: …')`.

So the honest figure is **7 placeholder routes · 1 reachable in-app · 6 orphans · all 7
URL-reachable** — and the reachable one sits on the profile of every other user.
**B4 stands.**

**A further correction, from `master-analyst` and verified here.** I first described
`socialMessages` and `socialNotifications` as guarded *and* unreferenced — "belt and
braces". They are not. `socialNotifications` (`:1580`) tests `FeatureFlags.notifications`
and `socialMessages` (`:1594`) tests `FeatureFlags.messaging`, and **both flags are `true`**
(`feature_flags.dart:53-54`). **No placeholder route in the app sits behind a closed flag.**
Those two are unreachable for exactly the reason the unguarded three are — nothing links
them. The guards are decorative. On a web build, where any registered route is reachable by
typing the URL, all seven behave like `socialChat` the moment anyone arrives at them.

**The generalisation, which matters beyond these routes.** A feature flag in this codebase
is not evidence that a feature is gated. `enableRewards = false` is the only flag in the
file actually holding anything back. Alongside `enablePlayerGameCreation` /
`enableOrganiserGameJoining` — where the values contradict their own comments (§2) — and
`venuesBooking = true` carrying the comment *"venues remain read-only"*, the pattern is
consistent: **flags here describe intent, not enforcement.** Any product decision that
assumes "it's behind a flag, so users can't reach it" needs the flag's value checked, and
then whether anything reads it at all — `PROJECT_STATE.md` FLAG-01 puts that at 10 of 113.

Two smaller defects found on the same path, for whoever takes the fix: `_sendMessage`
wraps the push in `isBlocked.whenData(...)`, so while that provider is loading or errored
**the button does nothing at all**; and the placeholder title calls
`conversationId.substring(0, 8)`, which throws on any id shorter than 8 characters.

The wider count from `PROJECT_STATE.md`, which I am **citing rather than asserting**: 12
live user-visible "coming soon" strings, 30 live `UnimplementedError`s, and one worse than
all of them — **`/transactions` displays fabricated AED amounts on a live route** (INV-05,
KAN-49). A product about to be promoted must not show a user invented money. *These figures
are `master-analyst`'s and have not been independently re-verified by me; check
`INDEX.md` §11b before quoting them onward.*

### B5 — Nothing is measurable. The GTM playbook cannot be executed.

The gate is in the GTM playbook's own T-14 list:

> "Analytics instrumentation verified (**PostHog/Mixpanel firing on key events**)"
> — `08` Part 2 §A.2

**The measured state — corrected 2026-08-27.** My first version said *"18 empty method
bodies"*, quoting `PROJECT_STATE.md` WIRE-11. That number is wrong, and the truth makes
this **sharper as a finding and smaller as a ticket**:

`lib/core/services/analytics/analytics_service.dart` is 226 lines with 16
`TODO: implement` comments, but only **four methods are actually empty** — the static sink:
`trackEvent` (`:10`), `trackScreen` (`:14`), `setUser` (`:21`), `reset` (`:25`).

**The other ~14 tracking methods are fully written.** `trackGameCreated`, `trackGameJoined`,
`trackGameSearch`, `trackCheckIn` and the rest each build a well-formed property map and
call `trackEvent(...)`. The event names, the properties and the call sites all exist.

> **One empty four-method sink silently discards every event the app already produces.**

The force of the finding is unchanged — `main.dart:78` calls `trackEvent` into a no-op, so
**the app emits nothing**. But KAN-51 is *wiring a provider into four methods*, not building
instrumentation: the instrumentation is already there.

What this makes uncomputable, in one list: **"Games confirmed"** (`02`'s north star and
`01` Truth 7's stated optimisation target) · **CSAU** (`08`'s north star) · every Month
3/6/9 target in `08` §B–D · every `03` §9.2 falsification condition · D7/D30 retention ·
activation rate · the WhatsApp share-out trip-wire · the k-factor targets · the Path-C
pivot triggers · the `12a` Month-12/15 price-elasticity checkpoints.

**This is the blocker I would rank first for *promotion* specifically.** B1 is the more
serious defect, but B5 is the one that makes spending the acquisition budget pointless:
`08` commits $200–225K across nine months against loops whose health is defined entirely
by numbers the product does not emit. Money spent now buys users and learns nothing.

### B6 — The launch sport has no launch **wedge**. *(restated 2026-08-27)*

> **Correction.** My first version said *"no cricket feature in the product"*. That
> overstated it. **Cricket is a supported sport** — 107 references across `sports_config.dart`,
> `sport_id_mapping.dart`, `sport_filters_config.dart`, `feature_flags.dart`,
> `game_creation_viewmodel.dart` and the explore/filter surfaces. A user can create, find
> and join a cricket game today. What is absent is the **cricket-specific wedge** the GTM
> plan is built on. The strategic conclusion is unchanged.

The corpus is unusually emphatic here:

> "**The cricket-first sequencing is the single most important strategic recommendation in
> this document.**" — `07d` §4.18
> "Cricket is the primary launch sport" — `08` Part 1
> `13a` Sprint 7 go/no-go gate: *"✅ **CricClubs deep-link works** · ✅ League creation +
> standings · ✅ Find-a-4th matches players · ✅ ELO rating computes · ✅ Playtomic
> deep-link opens."*
> `13a` Sprint 8 gate: *"✅ **Strava OAuth + sync**"*
> `14` D42/D45/D50 test stories for all three.

A read-only `grep` over `lib/` and `supabase/` for each named Stage-1 integration and
sport-specific requirement:

| Named in the corpus | Occurrences in `lib/` + `supabase/` |
|---|---:|
| CricClubs (cricket scoring — the wedge's core integration) | **0** |
| Playtomic (padel booking deep-link) | **0** |
| Strava (running lane's whole channel) | **0** |
| `find_a_4th` / find-a-fourth (padel matchmaker) | **0** |
| Women-only mode (KSA trip-wire; 52% of UAE fitness operators) | **0** |
| Ramadan mode / prayer-time-aware notifications (`14` D41) | **0** |
| Organiser uplift / App Fee / `paymentsLive` | **0** |

For contrast, and to keep the claim honest: **cricket itself scores 107 occurrences.** The
sport is supported; the wedge is not. All three Stage-1 integrations that `13a` gated its
sprints on are absent, as is every sport-specific differentiator.

The GTM plan is to walk into the Dubai Cricket Council, convert DSL and Mammoths captains,
and hand them an app. `09` Slide 6 sells them *"Scorecard integration with CricClubs"*,
*"Match scheduler with auto-roster"*, *"League table with auto-update"*, *"Captain dashboard
with no-show prediction"*. **A cricket captain can run a game on Dabbler today. What they
cannot do is anything they could not already do in WhatsApp plus a spreadsheet** — which
`07` names as the actual incumbent (§3).

This does not block the app being live, and it is not a defect. It blocks the **wedge**,
which is the entire acquisition strategy.

### B7 — The venue pack is a contract the product cannot honour.

`09`'s Pilot Agreement obliges Dabbler, per venue, within days of signature:

> "Venue created as entity in Dabbler admin · Venue logo and branding uploaded · Specific
> sport/activity types configured · **Custom landing page draft created (subdomain like
> venuename.dabbler.app)** · Member import template prepared" — §C.2
> plus *"Weekly progress reporting to venue"* (§B.2 Art. 3) and a **venue analytics
> dashboard** at Standard tier (Slide 8).

`PROJECT_STATE.md`: `venue_submissions` ships end-to-end (submit → approve); venue
*booking* does not; there is no venue admin surface, no per-venue landing page, no analytics
dashboard, no member import. `SupabaseConfig.venueImagesBucket = 'venue-images'` points at
a bucket that does not exist, and the real `venue` bucket has **zero storage policies** — a
venue cannot upload the logo the agreement obliges us to publish.

`09` also contains a walk-away clause the founder reads aloud in the sales script:

> "we measure adoption transparently — **30-50% of your member base downloads within Week 1
> of launch. If we don't hit that, Dabbler walks away** with no obligation on your side."
> — §G.1 Objection 2

That is a 30-day metric (§C.3) converted into a 7-day guarantee in the script. **Do not
send this pack until §C.2's deliverables exist and Objection 2 is rewritten.**

---

## 11. Where the corpus contradicts itself

A contradiction inside the corpus is a finding and it belongs to the PO. I quote both sides
and pick no winner.

**C1 — Year 1 is either $1.5M or $82K. The corpus says both.**

| Source | Year 1 |
|---|---|
| `00 executive summary` (precedence #1) | *"Year 1 \| UAE \| **50K** \| **$1–2M**"* |
| `02 monetization` (#2), Realistic | *"Year 1 \| **50,000** \| 1 \| **AED 4–8M**"* (≈$1.1–2.2M) |
| `03 investment memorandum` (#3) | *"Year 1 \| UAE \| **50,000** \| 4–8M \| **$1.1–2.2M**"* |
| `12c` narrative (newest, June 2026), Base | *"Total Revenue \| **$82K**"* |
| `12c`, Conservative | **$28K** |
| Benchmark Research Report | *"Honest Year-1 … ARR range is **$15–60K conservative, $60–180K base**"* |

**13–27× apart on the same year.** `12c` explicitly supersedes only the research brief —
*"It inherits everything upstream: The Financial Model Research Brief"* — and says nothing
about Docs 00/02/03, which remain live and which sit above it in precedence. `12c` then
contradicts itself on which case to pitch: §L.1 *"**Conservative is the plan.** … pitch
accordingly"* against §B.3 *"The pitch recommendation: **present Base as the plan**."*

Downstream, everything moves with it: EBITDA-positive Year 1 (`12c`) vs Year 4 (research);
Year-3 burn $4.55M (derived from `12c`'s own P&L) vs *"$1.2M–2.4M/yr"* (research);
LTV:CAC *"~32×"* / *"~79×"* (`12c`) vs the research's own standard, *"LTV:CAC target ≥3:1
(**no MENA discount**)"*, and vs `02`'s *"Year 1: 4–6x"*.

**C2 — "The world's first" was retracted, and the retraction was never applied.**

> `00`: *"The world's first amateur sports identity infrastructure."*
> `03` Part I: *"Dabbler is the world's first amateur sports identity infrastructure."*
> `06b` §2.2 holds *"Dabbler is the first platform of its kind"* up as the **model of
> correct brand voice**.

Against, from the same corpus:

> "**Dabbler is NOT first in 'amateur sports identity infrastructure.'** Malaeb (Bahrain),
> Playtomic (Spain, with a UAE FZCO entity …), Hawi (Saudi Vision 2030 platform with 509
> clubs and 21,489 affiliated members), and the SAFF+ federation stack already occupy
> meaningful parts of the same stack. … The 'category creator' framing **will not survive
> due diligence by a sophisticated investor**." — `07` research briefing

`07d` §4.18 issues the correction as an instruction: *"**Adjustment required: Soften the
'category creator' claim**"* to *"first integrated multi-sport stack purpose-built for MENA
amateur coordination, with cricket included"*, and *"**Adjustment required: Update the
competition slide** … Explicitly acknowledge Playtomic in UAE."* **Neither `00`, `03` nor
`05` has been revised.** `07` also identifies a competitor the earlier analysis missed —
Grintafy, *"nearly 2.5 million registered users across the Middle East"* — and notes it *"is
doing this for football in MENA today"*, which directly qualifies the Hidden Talent Doctrine.

**C3 — Four different Stage-1 sport scopes.**

`00`/`01`/`02`/`03`/`05`: *"Football, padel, cricket"* at equal priority, and `06a` §1.10
Rule 2 makes neutrality a brand rule: *"Dabbler does not pick sides … the global brand
respects all of them equally."* · `07d`: *"**Padel is not Dabbler's launch sport**"*,
*"Months 0–9: No active padel acquisition"* · `08` Part 1: *"padel is not active in Stage
1"* · `08` Part 2: *"**5-sport Stage 1**: Cricket … Football … **Padel via Playtomic
integration** … Indoor Fitness … Running"*.

`07d` names hedging between these as **Failure Mode 5**. The corpus is currently hedging.

**C4 — Does a player ever pay Dabbler? This one is constitutional.**

> `01` Permanent Truth 1: *"Dabbler will never gate community behind a paywall. Joining
> games, finding teammates, building a profile, and belonging to the platform will always
> be free. Forever."*
> `02` Part I: *"Players never pay to belong. Players never pay to find a game. … **Dabbler
> does not extract value from players.**"* · Pillar 1: *"Charged to the venue, **never to
> the player**"* · *"**No pay-to-play.**"*
> `04` Non-Negotiable 1: *"Players will never be required to pay for community
> participation."* Art. 33.1: *"**No officer … holds the authority to waive, modify, or
> negotiate the Non-Negotiables.**"*

Against:

> `12b` B.1: *"**App Fee** \| Free users only \| **Dabbler** \| Organised games (Free
> Players)"* — *"**AED 1.3 per transaction** charged to Free Players"*
> `12b` B.3: Organiser Uplift — *"10% uplift on organised game player cost"*, of which
> *"Dabbler's share: **80% (Free)**"*. Worked example: on an AED 50 game, *"Free Organiser
> game: **AED 5.30**"* to Dabbler, from the player's payment.

Two player-facing Dabbler revenue lines, against a Permanent Truth, the #2-precedence
document's governing sentence, and a Non-Negotiable that `04` says is written into every
partnership agreement and reflected in terms of service.

There is a defensible reading — the fee applies only where money is already changing hands,
and joining a *free* game stays free — but the corpus never makes that argument, and `02`
forecloses it in plain words. **This must be settled before any pricing goes live**, because
`04` turns it into a contractual representation to institutional partners, and `02` Part XI
currently records every pillar as ✅ Truth-checked without the App Fee existing in it.

**C5 — Two north stars.** `02` Part X: *"The metric that overrules all others — the North
Star — is: **Games confirmed.**"* `08` Part 2 §H.1: *"**Cross-sport active users (CSAU)**."*
Both claim to overrule.

**C6 — Player Premium: two activations, two prices, two conversion targets.**

| | `02` Pillar 2 (precedence #2) | `12a` (operating doc) |
|---|---|---|
| Activation | *"Year 2 (after core player base exceeds 50K active)"* | *"Phase 1B"* (Month 9) |
| Price | *"AED 29–49/month"* | *"AED 29/month · AED 299/year"* |
| Conversion | *"Target conversion: **6–10% of MAU**"* | *"Player Free → Pro \| **1.0-1.5%** (M12)"* |

The tie-breaker's target is **4–10× the operating plan's**, and `12a` justifies its own
number from research (*"MENA freemium conversion: 1-3% (not Western 3-7%)"*) that `02`
predates.

**C7 — Venue pricing is 3× apart.** `02` Pillar 1: commission *"8–15%"*, venue SaaS
*"AED 300–1,500 per venue per month"*, and *"100 venues = AED 140K–350K/month from venues
alone in Year 1"*. `12a` D.2/D.4: **Venue Basic AED 99/month**, launch commission **5%**,
and `12c` models **10 paying venues in Year 1**. `02`'s Year-1 venue revenue is unreachable
at `12a`'s prices and `12c`'s volumes by roughly two orders of magnitude.

**C8 — Capital stack.** `02` Part V and `03` §10.3: Seed $1.5–3M · Series A **$8–15M** ·
Series B **$25–50M** · Series C $75–150M · *"$110–215M across approximately five years"*.
`12c` F.1: Seed $1.8M @ $10M · Series A **$7M @ $40M** · Series B **$20M @ $120M**. The
research brief contradicts *itself* — §10 says *"$5–10M @ $30–50M"* for Series A, its
recommendations say *"plan for $1.5–3M Series A at $25–45M post"*.

**C9 — Auth: the newest document contradicts the shipped app.**

> `14`: *"**Auth note (important)**: Phone OTP is **OUT** — it costs money (Twilio) and the
> budget is $0. Authentication is **Email + Google + Apple only**. … Any OTP references in
> 13a–13c are superseded by this document."*

`13a` Sprint 1 gate is *"✅ One OTP successfully sent via Twilio"*; `13b` monitors Twilio
delivery as a P1 alert; `13d`'s T0 smoke test step 2 is *"Sign up via phone OTP"*; `13c`
calls the OTP reviewer problem *"the single most important reviewer-notes item for
Dabbler."* Meanwhile the product ships passwordless OTP (`PROJECT_STATE.md` flow 2, WORKS;
decision 002). **`14`'s supersession describes neither the product nor the other documents**,
and `13b`'s load-test matrix and `13d`'s smoke test have not been rewritten to replace the
OTP steps.

**C10 — `14` says the app is built; `14` also says twelve things are unbuilt.**

> "The app is already developed. So this document is **not** a build plan"

and then tags 24 items 🔵 BUILD-IT, including all five of its own declared blockers (D9,
I6, I9, G1, H1) and D8 data export — which `13a`'s Sprint 3 gate had already declared
complete (*"✅ Data export + account deletion functional"*) two months earlier. Either the
Sprint 3 gate never passed or "already developed" is overstated. On the evidence in
`PROJECT_STATE.md`, the Sprint 3 gate did not pass.

**C11 — Solo founder, and an org chart.** Every execution doc asserts one person: `13b` —
*"written for a **solo founder running launch alone** (AI-assisted, no ops team)"*; `13d` —
*"you are the QA team"*. Simultaneously committed:

- `04` Art. 22–25: an **Ethics Committee** where *"Independent members constitute a
  majority"*, an **Independent Audit Function** (*"a third-party professional services
  firm"*), an **Annual Transparency Report** *"published within 120 days of the close of
  each calendar year"* and *"publicly available"*, and a **Player Council** at 1M players.
- `06e` §5.23: a **Brand Council** — founder, head of design, head of product, head of
  marketing, one independent member — plus a Tier-4 Ethics Committee approval gate and
  *"New hires read all five parts in their first week."*
- `13a`/`13d`: an **Arabic copywriter contractor** described as *"in the stack"*, gating a
  P0 (`13b` P0-10).
- `13b` A.2: *"Founder contactable plan for launch week (**who covers what hours**…)"* —
  a rota question, posed and never answered.
- `13d`: 25 personal invites + 25 founder-guided first games + 25 debriefs + daily triage,
  inside one week (Aug 17–23), concurrent with store submission.
- Budget: *"sub-$250K"* (`08`) vs *"the budget is **$0**"* (`14`), while `13b`'s binding
  T-30 gate requires paid Supabase, Firebase Blaze, live Stripe, Sentry and Crisp/Intercom.

**C12 — The calendar has run out.** `13b`'s binding timeline: T-30 **Aug 2** · submission
window **Aug 17–23** · T-14 review **Aug 18** · escalation trigger **Aug 20** · T-7 code
freeze **Aug 25** · store approval target **Aug 28** · T-1 go/no-go **Aug 31** · **Day-0
Sep 1**. Today is **2026-08-27**. Every gate before today has passed without its evidence
being produced, and the app is *already live on both stores* — so the calendar no longer
describes reality in either direction.

**C13 — ~36 internal inconsistencies inside the 11/12 series.** Not individually blocking,
collectively corrosive, because these are the numbers a diligence process samples. The
material ones: Free Organiser uplift stated as *"0.5 AED per player for non-Pro"* and
*"0.2 AED per player"* four paragraphs apart in `11 v2` B.5 · App Fee input **AED 1** in
`12c`'s assumptions tab vs **AED 1.3** in its own narrative formula (a 30% error on a
revenue line) · average booking value **AED 250** (`12a` D.3) vs **AED 280** (`12b` D.1),
which makes the 120-booking Venue Pro upgrade trigger wrong under the corpus's own
assumption · commission **5%** (`12a`), **6%** (`12c` model), **5–8%** (`11b`) ·
*"THE 15 STREAMS"* against a 16-row margin table · Verified Venue Pro priced *"TBD"*
(`11b`), *"proposed"* (`12a`), and as settled fact (`12b`) · Free Organiser league creation
granted in `12a` C.1 and denied in `11b` D.2 (*"Free: View only"*) · `12a` K.2's *"PRICES
THAT NEVER MOVE … contractual for life"* listing a price (*"AED 19-year-1 Player"*) that
expires after twelve months · Corporate pricing non-monotonic at the 500-employee boundary
(AED 15,000 → AED 25,000 for one more employee) · a literal unresolved editing artifact in
the "Definitive Fee Split (Locked)" section: *"AED 2.50 (50% of uplift = Dabbler's share if
Free Organiser keeps… **wait**)"*.

**C14 — Entitlements no revenue stream funds.** `12a` sells Player Pro at AED 29/mo from
Month 9, but every Pillar 2/3/4 entitlement in it (~23 features) is **Phase 2 (M12–24)** in
`11b`; only the App Fee waiver is deliverable at launch — **AED 10.40 of value against AED
29 charged** at 8 games/month. The 14-day trial (`11b` 170), subscription pause (167) and
renewal reminders (169) are all Phase 2, yet all three are required by `12a`'s own Principle
7 at launch. And the **feature-flag system** (`11b` 590) is Phase 2 while Free-vs-Pro gating
must be live at Phase 1B. Separately: Player Pro promises *"**Unlimited** AI chat
translation"* at a **92–95% gross margin** with no inference cost line anywhere in `12b`.

## 12. What is missing entirely

| # | Gap | Why it matters now |
|---|---|---|
| **G1** | **No runway figure.** No cash balance, no closing cash, no months. `12c` F.3 says only *"substantial runway"*. | The Path-C pivot trigger is *"Cash reserves below 90 days"* — a trigger that cannot fire without a cash number. |
| **G2** | **The deck cannot be sent.** `05` slides 13–14 are placeholders: *"[Founder Name] [Role] [Single most relevant credential]"*, *"Series A — $[X]M / Pre-money valuation: $[Y]M"*, *"Target close: [Q/Year]"*. | Every Phase-A artifact exists except the two an investor reads first. |
| **G3** | **Market sizing has no source.** TAM $80–123B / SAM $42–68B / SOM $1.2–2.1B appear in `00`, `03` and `05` uncited; `07e` cites them circularly back to `03`. The Airbnb-3%/Stripe-2% analogy carrying the SOM is unsourced — and is the exact comparison `06a` §1.13 bans. | `07` already warns the category claim fails diligence. An uncited TAM is the second thing that fails. |
| **G4** | **No support / moderation / incident operating model for a live product.** `13b` assigns support, moderation, venue-claim review, and P0 triage to one person in two languages simultaneously. | `v_mod_queue_open` has **9 open tickets** and there is no in-app link to the moderation screen — URL only (`PROJECT_STATE.md` flow 18). |
| **G5** | **No pricing decision of record.** Venue Pro is TBD/proposed/fact across three docs; AED 99 vs AED 79 Organiser Pro is a Month-15 checkpoint, not a decision. | Nothing can be built against a price that is not decided. |
| **G6** | **No legal / entity / licence status.** `12b` I.1–I.3 flags SVF licensing (AED 200–400K), insurance-intermediary status, and PDPL data-product constraints. None has an owner or a date. `13b` Appendix B leaves every escalation contact blank with *"(Fill these in before T-7.)"* — T-7 was Aug 25. | |
| **G7** | **No record that the beta ran.** `13d` designed the proof: 25 organisers, *"≥80% ran a real game"*, *"'Would use instead of WhatsApp' (4–5) ≥60%"*, *"Recap shared to WhatsApp ≥50% of games"*. Nothing in the corpus or the repo records a result. | **This is the most valuable missing artifact in the whole assessment.** `13d`: *"If the beta reveals that Organisers *don't* prefer Dabbler to WhatsApp — that's not a bug, it's a product signal."* We are considering promoting a product whose one designed proof point has no recorded outcome. |

## 13. What would improve it — per document

Ordered by leverage, not by document number.

| Document | Change |
|---|---|
| `00`, `03`, `05` | Apply `07d` §4.18's own instruction: retire *"the world's first"*, adopt *"first integrated multi-sport stack purpose-built for MENA amateur coordination, with cricket included"*. Rewrite `05` slide 7 to name Playtomic in UAE, the institutional tier, and WhatsApp as the incumbent. Fill slides 13–14 or stop calling the deck ready. Cite the TAM. |
| `02` | Reconcile with the 12-series or state that it is superseded on numbers and retained on philosophy. Specifically: Pillar 1 *"Activation: Day One"* against booking at Month 9; Pillar 2 Year 2 / 6–10% against Phase 1B / 1–1.5%; venue SaaS AED 300–1,500 against AED 99. Add the App Fee and the Organiser Uplift to the Part XI Truth-check matrix, or remove them from `12b`. |
| `12a` + `12b` + `12c` | One reconciliation pass over C13's ~36 inconsistencies. Fix the AED 1 vs AED 1.3 model input first — it is a 30% error on a revenue line. Lock the Verified Venue Pro price. Resolve `12c` §L.1 vs §B.3 on which case is the plan. |
| `08` + `10` | Settle the marketing budget: `08` §F.2 says $20K, `10` §D.2 says ~$60K *citing `08`*, `10` §J.2 says $60–80K, the research brief implies $120K. Settle the captain target: 25–35 and 45–55 both appear for Month 9 in the same document. Settle paid-ads spend: $25–50/month (`08`) vs $200–500/month (`10`). |
| `09` | **Do not send until B7 closes.** Rewrite Objection 2 (a 30-day metric is being sold as a 7-day guarantee), reconcile Objection 3 (*"We don't take a cut of your direct bookings"*) with the §B.3 revenue-share table, and convert Slide 7's past-tense case studies to the *"what we expect"* framing the document itself recommends. Remove the PDPL claim until B1 and B2 close. |
| `13a`–`13d` + `14` | Re-date the whole Phase C/D sequence against reality — the app is live, the calendar is spent. Decide which document owns the go/no-go gate: `13b`'s ten P0s or `14` J10's one line (which silently drops payments-dormant, data safety, rollback, security and bilingual integrity). Rewrite `13b`'s load-test matrix and `13d`'s T0 smoke test now that OTP is nominally out — while noting the shipped app still uses it (C9). |
| `04` | Either staff the Ethics Committee, the Independent Audit Function and the Annual Transparency Report, or downgrade them from commitments to intentions with a date. As written they are representations to institutional partners that no one is in a position to perform. |
| `06` | Name the Arabic copywriter or remove the native-review gate from the P0 list. It currently blocks a launch and is not staffed. |
| **New** | The corpus has no **runway document** and no **beta result**. Those two artifacts are worth more right now than any revision above. |

---

## 14. THE QUESTIONS FOR THE PO

`master-analyst` left ten `NEEDS PO INPUT` markers. The corpus retires most of them. **Six
questions remain, and five are rulings only the owner can make.**

1. **Which financial model is the plan — `00`/`02`/`03` (~$1.5M Year 1) or `12c` (~$82K)?**
   Everything downstream moves with the answer: hiring, the seed ask, what "on track" means.
   One of them must be marked superseded. (C1)
2. **Does the App Fee stand?** `12b` charges free players AED 1.3 per transaction and takes
   80% of the organiser uplift out of what a player pays. `01` Truth 1, `02`'s governing
   sentence and `04` Non-Negotiable 1 say Dabbler does not take money from players. This
   needs a ruling before any pricing is built, because `04` makes it a contractual
   representation to institutional partners. (C4)
3. **Is the category claim retired?** `07d` instructed the change in May; `00`, `03` and
   `05` still carry *"the world's first"*. Either apply the correction or record a decision
   to keep the claim and accept the diligence risk. (C2)
4. **Which north star — "games confirmed" or CSAU?** Both are written as overruling. The
   answer determines what `analytics_service.dart` gets wired to first. (C5)
5. **Did the 25-organiser beta run, and what did it say?** Specifically the one question
   `13d` calls the key one: *"would you use this instead of WhatsApp?"* If it never ran,
   running it is the highest-value action available before any promotion spend. (G7)
6. **What is the runway, in months?** The corpus does not contain it and the pivot trigger
   depends on it. (G1)

**What I am not asking, because the corpus answered it:** who the product is for and the
persona hierarchy (§2) · the flag contradiction (§2) · the centre of gravity (§1) · the
problem statement (§3) · the failure conditions (§7) · four of the five non-goal forks (§5).

---

## 15. HOW THIS FILE STAYS TRUE

`cpo` owns it. It is filled from the business corpus, never from the codebase — the rule
`master-analyst` wrote this file under, and it still holds. Where the corpus and the build
disagree, §§10–11 record the gap; the fix belongs in one or the other, not in this file.

Rulings the PO makes against §14 land as numbered `P-nnn` entries in `docs/DECISIONS.md`
and are reflected back into §§1–7 here. A corpus document that a ruling supersedes is named
in the decision, so the next reader knows which Notion page has gone stale.
