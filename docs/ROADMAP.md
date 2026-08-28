# docs/ROADMAP.md — Release Roadmap

**Owner:** master-analyst (write, from PO direction) · all agents (read)
**Last updated:** 2026-08-26

Scope buckets, not dated plans. A wave is done when its **exit criterion** passes, not when
its list is ticked.

> **Wave assignment is the PO's call.** Every flag below carries a *recommendation* and an
> evidence line. Where the call is not mine to make, the row says `NEEDS PO INPUT` rather
> than inventing a plan.

---

## 0. WHAT THE FLAGS FILE ACTUALLY IS

Before the table, two facts that change how to read it.

**Fact 1 — 112 of 113 flags are hardcoded `true`.** Exactly one is `false`:
`enableRewards` (`feature_flags.dart:57`). Everything else, including every flag under the
file's own `// HIDDEN FEATURES (Future Release)` heading, is on.

So `feature_flags.dart` is not a control surface. **It is a to-do list on which every item
is marked done.** Even the 10 flags that something reads cannot gate a feature *off*,
because they are constants that are never false. This is a stronger finding than "98 flags
are unread": the 10 live ones are decorative too.

**Fact 2 — two flags contradict their own comments:**

```dart
static const bool enablePlayerGameCreation =
    true; // Players CANNOT create games in MVP      ← value says they can

static const bool enableOrganiserGameJoining =
    true; // Organisers CANNOT join games in MVP     ← value says they can
```

Either the comment is stale or the value is wrong. **Both flags gate live code** (3 and 2
files), so this is not academic — one of the two is currently misdescribing what the app
does to players and organisers. **NEEDS PO INPUT**, and it should be answered before the
cleanup in KAN-32 removes the evidence.

**Fact 3 — `enableRewards = false` is meaningful.** The one flag that is off is the one
gating the 20,545-LOC unreachable slice. That is consistent with *paused*, not
*abandoned* — someone deliberately switched it off rather than deleting it. Relevant input
to KAN-29, and a reason not to assume the answer there is "delete".

---

## 1. WAVES

### Wave 0 — Make it safe (IN PROGRESS, BLOCKING EVERYTHING)

**Scope:** the security findings, plus the schema history that would have caught them.
KAN-24 · KAN-25 · KAN-26 · KAN-27 · KAN-33

**Dependencies:** none. This wave blocks every other wave.

**Exit criterion:** as `anon`, every view in the public schema returns either zero rows or
only data intended to be public — verified by probe with a control query. And
the 38 existing migrations are either relocated to `supabase/migrations/` with timestamp
prefixes, or a decision records why they stay where they are.

**Nothing ships to production until this passes** (`MANIFESTO.md` §4.4).

### Wave P — The promotion gate (added 2026-08-27 by `cpo`, decision P-004)

**This wave is not about shipping — the app is already live on both stores. It is about
whether we are allowed to *promote* it.** Nothing here is a CPO preference; every item is
a criterion the business corpus already wrote down as binding.

> "The go/no-go gate (Section C) is binding. If a P0 criterion is red, you hold the launch.
> No exceptions, no 'we'll fix it live.'" — `13b launch runbook and day-0 operations`

**Scope — six blockers** (B10 removed 2026-08-28, `P-013` — the gate is only useful while every item on it is one that promotion genuinely worsens) (B3 retracted 2026-08-27; B8 and B9 added 2026-08-28 per `P-007`/`P-008`;
numbering kept so ticket references resolve). No acquisition spend, no press, no venue
partner pack and no founding-cohort outreach until all six close. **B1 and B2 carry the
hold on their own.** B8 is the one that gets *worse* with promotion rather than merely
staying broken: it multiplies the attacker pool and the target pool in the same motion,
and accounts are free by design (decision 002).

| | Blocker | Gate it fails | Ticket |
|---|---|---|---|
| **B1a** | **LIVE DESTRUCTIVE EXPOSURE.** 70 of 71 views grant `anon` INSERT/UPDATE/DELETE; **8 are definer + auto-updatable live write paths**. `security_invoker=false` means RLS is **not consulted** — an unauthenticated party can today delete other users' notifications, drafts, posts-time data and reputation rows. An insert also fires a real push via `trg_push_on_notification_insert`. **Do not scope this as "add a uid predicate" — the REVOKE comes first** | `13b` P0-9 | KAN-56 · KAN-67 |
| B1b | Definer-view read sweep — 49 definer views, 27 anon-readable, 30 zero-policy tables | `13b` P0-9 | KAN-37 · KAN-38 |
| B2 | PDPL data export unreachable | `13b` P0-6, `14` D8 | KAN-52 |
| ~~B3~~ | ~~Users cannot switch to Arabic~~ — **RETRACTED, claim was false** | — | KAN-53 closed |
| B4 | "Message" button on every profile → "Coming Soon" | `14` H6 | KAN-45 |
| B5 | Analytics sink is 4 empty methods — the app emits nothing | `08` Part 2 §A.2 | KAN-51 |
| **B8** | `send-push-notification` authenticates but does **not authorize** — any free account can send trusted first-party push to anyone | trust · `13b` P0-9 class | **KAN-59** |
| **B9** | Logout teardown — a signed-out device keeps receiving another account's pushes | user harm, occurring now | **KAN-58** |

**Two further holds, both PO calls rather than engineering work:** KAN-54 (the cricket-first
wedge has no cricket feature) and KAN-55 (the venue partner pack contracts deliverables the
product does not have).

**THE BINDING CONSTRAINT — read before scoping any of this** (`P-007`, verified
2026-08-28). There are **two** bottlenecks and a Flutter agent only fixes one.

- **Authoring.** 7 agents exist; **none writes Dart feature code.** `CONTRACT.md` gives
  `notifications-specialist` only `lib/features/notifications/**` and
  `lib/services/notifications/**`; 23 of 25 slices, `lib/core/**` and `lib/data/**` are
  UNOWNED. **B2, B4 and B5 have zero throughput today.**
- **Shipping.** `CONTRACT.md:125` — *"NOBODY. No agent writes production … however
  correct or urgent"* (decision 019). B1 and B8 can reach *reviewed SQL / a reviewed
  function* and stop there.

**B1 cannot "move today."** It spans `v_mod_queue_open`, `v_safety_overview` and
`v_circle_feed` — moderation, safety, circles — and `CONTRACT.md:119` limits NS to
*notification-related* migrations, everything else UNOWNED. NS can author **two of five**
views, and may apply none of them. Both bottlenecks are PO decisions; neither `cpo` nor
`cto` may grant them, because `CONTRACT.md` is governance.

**Dependencies:** B1 is Wave 0 work and blocks this wave the same way it blocks every other.
B2 and B5 are independent of each other and can run in parallel. **B5 is LARGER than first
scoped** (corrected 2026-08-28, `P-008`) — I previously wrote that it was only wiring. It is
not: there is **one live emission site in the app** (`main.dart:78`, a flags snapshot),
nothing on the games-confirmed path emits, **two classes are named `AnalyticsService`**, and
`lib/core/analytics/` (~900 lines) has zero importers. B5 is building the emission layer.

**Why B5 ranks where it does.** B1 is the more serious defect. B5 is the one that makes the
$200–225K acquisition budget in `08` unspendable: the growth loops it funds are defined
entirely by numbers the product does not emit, so money spent before B5 closes buys users
and learns nothing.

**Exit criterion:** all five closed and verified *in production*, not in code — `13b` P0-6
is explicit about that. Then the promotion decision returns to the PO.

**Full reasoning:** `docs/BRIEF.md` §10.

### Wave 1 — Decide what exists

**Scope:** the two frozen questions and the ownership gap.
KAN-29 (rewards) · KAN-30 (clean-arch stack) · KAN-16 (roster) · plus the flag table below

**Dependencies:** PO input only. No engineering.

**Exit criterion:** every one of the 113 flags is deferred-to-a-wave or cut-with-a-decision-id;
`rewards` and the clean-arch stack each have a written ruling; every path in `CONTRACT.md`
has an owner or a documented reason it does not.

**This is the cheapest wave and it unblocks the most.** It is decisions, not code.

### Wave 2 — Make the truth cheap to keep

**Scope:** delete what is dead, so the next audit is smaller.
KAN-31 (~7,800 LOC) · KAN-32 (98 flags, 54 route constants, 2 deps) · KAN-28
(`SettingsRepositoryImpl`) · KAN-34 (first live-path tests)

**Dependencies:** Wave 1 — deletions in `rewards` and the clean-arch stack wait on the rulings.

**Exit criterion:** `flutter analyze` 0 errors; every remaining feature flag gates something;
every remaining route constant resolves to a route; at least one test covers a route-reachable
path.

### Wave 3 — Finish what is half-built

**Scope:** the features that exist as partial implementations — the six "Coming Soon" routes,
analytics wiring, the settings backend, the `Either` → `Result` migration in `profile` and
`games`.

**Dependencies:** Wave 2 (do not finish code that is about to be deleted).

**Exit criterion:** no route resolves to a placeholder; no live repository throws
`UnimplementedError`; no slice mixes `Either` and `Result`.

### Wave 4+ — New capability

**Scope:** everything in the DEFER column below — 38 flags' worth of unbuilt features.

**Dependencies:** Wave 1 (a feature cannot be built while it is ambiguous whether it was
cut), and Wave 2 for anything in a slice due for deletion.

**Exit criterion: `NEEDS PO INPUT`.**

This is deliberately not invented. A wave's exit criterion has to state what "done" means
for the scope, and that depends on which capabilities the PO actually wants — the same
question as `BRIEF.md` §8.5 and the DEFER/CUT sign-off in §2 of this file. Writing a
plausible criterion here would be exactly the "invent a plan" failure the ticket forbids,
and it would then be quoted back as a decision nobody made.

**What is needed to fill it:** an ordering of the DEFER list, or at minimum the top three.
§4 groups the deferred work by what it needs, which should make that ordering cheap —
six of those features need **only client work**, their backends already exist.

---

## 2. THE FLAG TABLE — all 113, grouped by slice

**Legend** · `LIVE` gates something · `SNAPSHOT` read only by the `main.dart:80-92` analytics
event · `DEAD` read nowhere.
**Recommendation** · `KEEP` · `CUT` (delete the flag; the feature exists and is permanent, or
will never be built) · `DEFER` (feature not built; flag should track it).

### Auth — `auth_onboarding` (SHIPPED)

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `enablePhoneAuth` | DEAD | **CUT** | Auth ships; not gated. Phone auth is not implemented and OTP is email |
| `enableEmailAuth` | DEAD | **CUT** | Ships permanently. A flag on the front door is not useful |
| `enableGoogleAuth` | DEAD | **CUT** | Live on web via `GOOGLE_WEB_CLIENT_ID` |
| `enableAppleAuth` | DEAD | **DEFER** | Not built — l10n has "Apple sign-in is coming soon" (`app_localizations_en.dart:148,289`). This is a real deferral |

### Profile — `profile` (PARTIAL, 40,854 LOC)

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `enableBasicProfile`, `enableProfileEdit`, `enableAvatarUpload`, `enableBioEdit`, `enableLocationEdit` | DEAD ×5 | **CUT ×5** | All ship. 18 profile screens routed |
| `enableOrganiserProfile` | DEAD | **CUT** | Ships. Duplicates `organiserProfile` below |
| `organiserProfile` | SNAPSHOT | **CUT** | Duplicate of the above |
| `enableMultiProfile` | DEAD | **KEEP** | Multi-persona is real (`trg_limit_active_profiles`, `rpc_act_as`). Should gate |
| `enableVerificationBadge` | DEAD | **KEEP** | `profile_verifications` table + `rpc_verify_profile` exist |
| `enableProfileCompletionPercent` | DEAD | **CUT** | `calculate_profile_completion_usecase.dart` exists but is in the dead stack |
| `enableBasicStats`, `enableDetailedStats`, `enablePerformanceTrends` | DEAD ×3 | **DEFER ×3** | `profile_stats_repository.dart` is 8× `UnimplementedError` |

### Games — `games` (PARTIAL) + `misc` composer

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `enableGameBrowsing` | **LIVE** (2 files) | **KEEP** | Genuinely gating |
| `enablePlayerGameCreation` | **LIVE** (3) | **KEEP** — ⚠️ **value contradicts its comment** | See Fact 2 |
| `enableOrganiserGameCreation` | **LIVE** (3) | **KEEP** | |
| `enablePlayerGameJoining` | **LIVE** (2) | **KEEP** | |
| `enableOrganiserGameJoining` | **LIVE** (2) | **KEEP** — ⚠️ **value contradicts its comment** | See Fact 2 |
| `enableGameDetails`, `enableJoinGames`, `enableLeaveGames`, `enableMyGames` | DEAD ×4 | **CUT ×4** | Superseded by the five LIVE flags above |
| `enableGameEditing`, `enableGameDeletion` | DEAD ×2 | **CUT ×2** | `rpc_update_game` / `rpc_cancel_game` exist and are reachable |
| `enableGameInvitations`, `enableGameWaitlist` | DEAD ×2 | **CUT ×2** | Built — `game_invites`, `game_waitlist` tables with triggers |
| `enableRecurringGames` | DEAD | **DEFER** | Not built. `rpc_recreate_from_game` is adjacent, not the same |
| `enablePrivateGames` | DEAD | **CUT** | Built as `listing_visibility` / `join_policy` on `games` |
| `enableGameChat` | DEAD | **DEFER** | Not built |
| `enableTrendingGames` | DEAD | **CUT** | `rpc_trending_posts` is posts, not games. Not built and not asked for |

### Social — `social` (SHIPPED, 28,827 LOC)

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `socialFeed` | **LIVE** (2) | **KEEP** | |
| `messaging` | **LIVE** (2) | **KEEP** | Gates the 3 placeholder chat routes |
| `enableSocialFeed`, `enableCreatePost`, `enableLikePost`, `enableCommentPost`, `enableFollowUsers`, `enableFriendRequests`, `enableFriendsList` | DEAD ×7 | **CUT ×7** | All ship. Comments say "NOW ENABLED FOR MVP" — the enabling happened; the flags did not |
| `enableSharePost` | DEAD | **DEFER** | `venue_detail_screen.dart:922` — "Sharing coming soon" |
| `enableBlockUsers`, `enableReportContent` | DEAD ×2 | **CUT ×2** | Shipped for App Store compliance (`c5a83e9`) |
| `enableCircleFeed` | DEAD | **KEEP** | `circles` / `circle_members` live; `v_circle_feed` leaks (KAN-25) |
| `enableActivityFeed` | DEAD | **CUT** | Ships — `activities` slice + `public_activities` triggers |
| `enableDirectMessages`, `enableGroupChat`, `enableChatHistory`, `enableTypingIndicators`, `enableReadReceipts` | DEAD ×5 | **DEFER ×5** | **Nothing built.** Chat List / Messages routes are placeholders |

### Squads — `squads` (DEAD slice, 136 LOC)

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `squads` | SNAPSHOT | **DEFER** | Advertises a slice with 0 importers |
| `enableSquads`, `enableCreateSquad`, `enableJoinSquad`, `enableSquadInvites`, `enableSquadStats` | DEAD ×5 | **DEFER ×5** | **The backend is built** — `squads`, `squad_members`, `squad_invites` tables, 8 `rpc_squad_*`, `v_squad_card`. Only the Flutter side is missing |
| `enableSquadChat` | DEAD | **DEFER** | Depends on messaging, which is also unbuilt |

**Worth the PO's attention:** squads is the largest gap between backend and client in the
codebase. The database side is essentially complete.

### Notifications — `notifications` (SHIPPED, healthiest slice)

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `notifications` | **LIVE** (2) | **KEEP** | |
| `enablePushNotifications` | DEAD (read only inside `feature_flags.dart`) | **CUT** | Push ships on all 3 platforms. Note: an identically-named `UserSettings` field is unrelated and stays |
| `enableInAppNotifications`, `enableNotificationCenter`, `enableNotificationPreferences` | DEAD ×3 | **CUT ×3** | All ship — `notifications_screen_v2.dart` routed, settings wired in `3b7fd50` |

### Venues — `venues` (PARTIAL) + `venue_submissions` (SHIPPED)

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `venuesBooking` | SNAPSHOT | **DEFER** | Comment says "venues remain read-only" — accurate |
| `enableVenueSearch`, `enableNearbyVenues` | DEAD ×2 | **CUT ×2** | Ship |
| `enableVenueBooking`, `enableBookingFlow` | DEAD / SNAPSHOT | **DEFER ×2** | `venue_bookings` + `rpc_booking_*` exist; client side does not |
| `enableVenueRatings`, `enableVenueRating`, `enableGameRating`, `enableRatingComments` | DEAD ×4 | **DEFER ×4** | Backend complete (`rpc_rate_venue/game/user`, aggregate tables). No client UI. Also: 4 flags for 1 feature — collapse to one |
| `enableVenuePhotos` | DEAD | **DEFER** | `venue_photos` table exists; bucket `venue` has **zero policies**, so uploads are impossible (KAN-27) |

### Payments — `payments` (DEAD slice, 503 LOC)

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `enablePayments` | **LIVE** (2) | **KEEP** | The one live flag over a dead slice |
| `enableWallet`, `enableTransactionHistory`, `enableBookingHistory` | DEAD ×3 | **DEFER ×3** | `wallets`, `wallet_ledger`, `payment_intents`, `payouts` all exist with policies. Client side does not |

### Rewards — `rewards` (SCAFFOLD, 20,545 LOC) — **FROZEN by decision 015**

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `enableRewards` | **LIVE** (5) — **the only `false` flag** | **KEEP until KAN-29** | Correctly off. See Fact 3 |
| `enableLeaderboards`, `enableAchievementBadges` | DEAD ×2 | **BLOCKED on KAN-29** | Controllers exist, unreachable |

### Search / discovery — `explore` (PARTIAL)

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `enableAdvancedSearch` | DEAD | **CUT** | `rpc_unified_search_sectioned` + `social_search_screen.dart` (2,892 LOC) ship |
| `enableFilters` | DEAD | **CUT** | Ships |
| `enableMapView` | DEAD | **DEFER** | Not built |
| `enableRecommendations` | DEAD | **DEFER** | `rpc_potential_vibes` exists; no client surface |

### Moderation — `moderation` + `admin` (SHIPPED)

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `enableModerationUI`, `enableUserReports`, `enableContentModeration` | DEAD ×3 | **CUT ×3** | All ship — 2 admin screens routed, gated on `rpc(is_admin)` |

### Platform / infrastructure

| Flag | State | Recommendation | Evidence |
|---|---|---|---|
| `multiSport` | SNAPSHOT | **CUT** | Multi-sport is structural — `sports`, `sport_variants`, `sport_profiles`. Not toggleable |
| `enableRealtimeSync` | DEAD | **DEFER** | Comment says "use polling for MVP". `main.dart:217` — `TODO(post-rebuild): reinitialize realtime post updates` |
| `enableOfflineMode` | DEAD | **DEFER** | `sqflite` is a dependency; nothing uses it for offline |
| `enableAnalytics` | DEAD | **DEFER** | **Backend ready** — `rpc_track_event` + `analytics_events` with policies. Client is 18 empty `// TODO` bodies |
| `enableABTesting` | DEAD | **CUT** | Nothing built, nothing planned |
| `enableBenchMode` | DEAD | **DEFER** | Backend complete — `rpc_toggle_bench`, `v_bench_status`, `user_hidden_modes`. `bench_mode` slice has 0 importers |
| `enableThemeSettings`, `enableLanguageSettings`, `enableLogout` | DEAD ×3 | **CUT ×3** | Ship. (Language *selection* is a placeholder route, but the setting exists) |
| `enablePlayerRatings`, `enableViewRatings` | DEAD ×2 | **DEFER ×2** | Duplicates the rating cluster above — collapse |

### Navigation chrome — 10 flags

`showHomeTab` · `showSportsTab` · `showMyGamesTab` · `showSocialTab` · `showSquadsTab` ·
`showProfileTab` · `showSettingsTab` · `showNotificationBell` · `showMessagesIcon` ·
`showSearchIcon`

All **DEAD**. **CUT all 10.** Navigation is assembled in `main_navigation_screen.dart`
without consulting any of them. A tab is shown or not by the widget tree, not by a flag.

### Debug — 3 flags

`enableDebugMode` · `enableFeatureFlagOverride` · `showFeatureFlagIndicators`

All **DEAD**. **CUT all 3.** `enableFeatureFlagOverride` promises runtime toggling that does
not exist — the flags are `const`, so runtime override is impossible by construction.

---

## 3. TALLY

| Recommendation | Count |
|---|---:|
| **KEEP** — gates something, or should | 11 |
| **CUT** — feature ships permanently, or will never be built | 62 |
| **DEFER** — feature genuinely not built; flag should track it | 38 |
| **BLOCKED** on KAN-29 | 2 |
| **Total** | **113** |

Acting on this reduces `feature_flags.dart` from 113 boolean flags to **~49** — 11 kept and
38 deferred — and every one of those 49 would then mean something.

**The `CUT` majority is the finding.** 62 flags describe features that already ship. They
were never switches; they were a checklist someone kept ticking, and the file became a
worse description of the app than the app itself.

---

## 4. DEFERRED WORK, GROUPED BY WHAT IT NEEDS

Useful because several "unbuilt" features are unbuilt only on the client.

**Backend complete, client missing** — cheapest new capability available:
squads (8 RPCs, 3 tables, a view) · ratings (3 RPCs, aggregate tables) ·
bench mode (2 RPCs, a view, a table) · payments/wallet (4 tables) ·
venue booking (3 RPCs) · analytics (1 RPC, 1 table)

**Nothing built either side:** direct messages, group chat, typing indicators, read receipts,
game chat, recurring games, map view, offline mode, Apple sign-in.

**Blocked on a ruling:** everything in `rewards` (KAN-29).

---

## 5. CUT WITH A DECISION ID

Nothing has been formally cut yet. Every `CUT` above is a **recommendation awaiting PO
sign-off**; on approval each gets a `DECISIONS.md` entry and this column carries the id.

| Feature | Cut by | Date |
|---|---|---|
| *(none yet)* | | |

---

## Wave P — EXECUTION: the one-month plan

Written by `cpo` 2026-08-28 (`P-010`), converged with `cto` and `master-analyst`, no dissent.
`master-analyst` holds the ground-truth column; `cto` holds sequencing and refusals.

### The single question for the PO — everything below is shaped by the answer

> **Three of the gate's items have no author, and by decision 019 none of them has any way to
> reach production. Which do you unblock, and how?**

Two distinct bottlenecks. A Flutter agent fixes the first only:

| Bottleneck | What it blocks | Why it exists |
|---|---|---|
| **Backend authoring** | **B1a**, B1b, the 30 zero-policy tables | `CONTRACT.md` — non-notification migrations are *"UNOWNED — nobody writes it, **pending a backend owner**"*. **An unfilled seat, not a prohibition** (`P-015`) — filling it is what the row anticipates, and it needs no contested amendment |
| **Dart authoring** | B2, B4, B5, KAN-58's teardown half | 7 agents, **none writes Dart feature code**. 23 of 25 slices, `lib/core/**`, `lib/data/**` unowned |
| **Shipping** | all of the above | `CONTRACT.md` — *"NOBODY. No agent writes production … however correct or urgent"*. **A prohibition. Unamendable, reserved to the PO by `019`** |

**These are three hires-or-decisions, not one.** `P-015` corrects an earlier fusing of the
backend and Flutter seats. **B1a's dependency is `backend owner → PO applies`, not
`Flutter hire → …`** — so if the PO fills the backend seat first, **B1a can move in week one.**

**Neither `cpo` nor `cto` may grant either.** `CONTRACT.md` is governance — `master-analyst`
writes it, the PO accepts it. Both agents reached this independently and refused to
self-authorise; that refusal is the boundary working.

### The sequence

| # | Item | Owner | Ceiling this month |
|---|---|---|---|
| **0** | **B1a — fix the `anon` write grant: REVOKE **and** the `pg_default_acl` default** | **UNOWNED** | **Highest value on the gate and unassignable** (`P-014`). The grant is inherited Supabase **stock default privilege** — a REVOKE-only fix **reopens on the next migration** and would pass verification while silently regressing. Schema-level, so it **cannot be split by view ownership**; `hire → B1a` is a **hard dependency**. Counterpoint the PO needs: nothing in `lib/` writes through these views, so **revoking cannot blank a screen** — it reads as the scariest item and is the safest to apply. `geometry_columns` needs its own line (PostGIS, `supabase_admin`). PO-gated under 019 |
| 0b | **Stand up the Flutter feature agent** | PO | **Gate-clearing dependency, not capacity.** KAN-58 cannot be finished by anyone on the roster — FCM half is NS, teardown half is unowned `lib/core/**`. Its first task is the KAN-58 teardown, **never the 69,612 dead lines** |
| 1 | ~~B1a under NS authorship~~ — **superseded by row 0** (`P-011`). Ownership dissolves: a schema-wide `anon` privilege correction is not a notifications, moderation or social change, so it needs neither the matrix widened nor the Flutter agent. **One migration, `cto`'s authorship, PO-gated** | `cto` | Ceiling: reviewed SQL, PO-gated |
| 2 | **B9 / KAN-58** — logout teardown | NS + Flutter agent | Blocked on #0 |
| 3 | **B4** — hide the Message button | Flutter agent | Blocked on #0. **Hide at `user_profile_screen.dart:1475`, do not flip `messaging`** — the flag bounces the user to home, which reads as broken rather than absent |
| 4 | **B8 / KAN-59** — push authorization | NS | Edge function, owned |
| 5 | **B1b** — definer-view sweep | `cto` | 49 views, 27 anon-readable, 30 zero-policy tables. The week |
| — | **Cleanup commit** | `version-control` | 106 entries, **incl. Dart deletions**. Needs Android release + iOS builds |
| — | **12-view triage** | `master-analyst` | A read producing a list. No change proposed |

**Next month, explicitly:** **B2** (PDPL export) and **B5** (analytics emission layer).

### What this means commercially — state it, do not bury it

**The acquisition-spend gate does not open this month.** B5 gates it; B5 is not in the month.
`08`'s $200–225K stays unspent, and that is the correct outcome rather than a slip: spending
it against loops the product cannot measure buys users and learns nothing.

### Acceptance criteria — evidence, not assertion

| Item | Done means |
|---|---|
| B1a / B1 | As `anon`, all five views return 0 rows **and** `role_table_grants` shows no INSERT/UPDATE/DELETE/TRUNCATE for `anon` |
| B8 / KAN-59 | A valid JWT for account A targeting account B is **rejected** by `send-push-notification` |
| B9 / KAN-58 | Sign-out deletes the `fcm_tokens` row and clears the session-scoped stores; a signed-out device receives nothing. **Classify all 19 on-device stores** as session- or preference-scoped first — `theme_service`, `locale_provider`, `notification_preference` must survive. Delete the orphaned `LogoutUseCase` stack in the same ticket so the next owner cannot wire it back and silently defeat the teardown |
| B4 | The profile Message button reaches a screen that is not `app_router.dart:1617` |
| B5 | **One real event observable in the destination, not in code** |
| B2 | A PDPL export completes **in production** — `13b` P0-6 is explicit |
| ~~B10 / KAN-57~~ | **OFF THE GATE ENTIRELY** (`P-013`). The keystore file was never committed on any ref, so the password alone signs nothing. Promotion does not worsen it — the exposure is static and nine months old. **HIGH in the normal queue; still closes on rotation, never on the diff.** The real item is password **reuse**, escalated to the PO separately |
| Cleanup | 0 analyzer errors, tests green, **plus an Android release build and an iOS build** |

### Risks the plan carries rather than resolves

1. **KAN-57 — resolved as a blocker, escalated as something else.** The `build.gradle.kts` change
   is good and **does not close it**; only rotation does. **`P-012`: the keystore file was never
   committed**, so the password alone signs nothing — pre-promotion requirement, not a blocker.
   **The larger risk is not the key.** `storePassword` and `keyPassword` are the same value and
   read as a personal password. **If it is reused anywhere — email, Play Console, Apple, Supabase
   — rotating the upload key does not close that.** Treat the string as burned everywhere it
   appears. A PO item, escalated directly; not an engineering task, and in no ticket.
2. **Mobile is unverified.** The cleanup is web-verified only, on a product **live in two
   stores**, and the same diff touches the release signing path.
3. **Feature flags are decoration.** 112 of 113 hardcoded `true`; `enableRewards = false` is the
   only one holding anything back. Never read a flag as evidence something is gated.

### Explicitly out of the month

KAN-29 (rewards) · KAN-30 (clean architecture) · the 30 zero-policy tables · test coverage over
reachable code · `T-010` (143 oversized files, 317 colour literals, three error conventions) ·
**mass deletion of the 69,612 unreachable lines** — with zero coverage on live paths it is the
riskiest operation in the repo and must not be a new owner's first act. The dead code has
waited a year.
