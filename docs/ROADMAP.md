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

**Scope — four blockers** (B3 retracted 2026-08-27; numbering kept so ticket references
resolve). No acquisition spend, no press, no venue partner pack and no founding-cohort
outreach until all four close. **B1 and B2 carry the hold on their own.**

| | Blocker | Gate it fails | Ticket |
|---|---|---|---|
| B1 | Unauthenticated cross-tenant data leak | `13b` P0-9 | KAN-36 · KAN-37 · KAN-38 |
| B2 | PDPL data export unreachable | `13b` P0-6, `14` D8 | KAN-52 |
| ~~B3~~ | ~~Users cannot switch to Arabic~~ — **RETRACTED, claim was false** | — | KAN-53 closed |
| B4 | "Message" button on every profile → "Coming Soon" | `14` H6 | KAN-45 |
| B5 | Analytics sink is 4 empty methods — the app emits nothing | `08` Part 2 §A.2 | KAN-51 |

**Two further holds, both PO calls rather than engineering work:** KAN-54 (the cricket-first
wedge has no cricket feature) and KAN-55 (the venue partner pack contracts deliverables the
product does not have).

**Dependencies:** B1 is Wave 0 work and blocks this wave the same way it blocks every other.
B2 and B5 are independent of each other and can run in parallel. **B5 is smaller than first
scoped** — the ~14 tracking methods are already written and call `trackEvent`; only the
four-method static sink is empty, so this is wiring a provider, not building instrumentation.

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
