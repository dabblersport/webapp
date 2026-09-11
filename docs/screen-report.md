# Screen Report

Inventory of every screen in the app — working, drafted, and not working.

**Generated:** 2026-08-17 · **Branch:** `Canary` · **Commit:** `1b83967`
**Verification:** `flutter analyze --no-pub` → **0 errors**, 157 warnings/infos.

Nothing in this report is broken at compile level. "Not working" means *unreachable,
stubbed, or orphaned* — not failing to build.

Sources of truth: `lib/app/app_router.dart`, `lib/utils/constants/route_constants.dart`,
`lib/core/config/feature_flags.dart`.

---

## Summary

| Bucket | Count |
|---|---|
| ✅ Routed & reachable | 69 routes |
| ✅ Reachable via `Navigator.push` (not routed) | 2 |
| 🟡 Routed but stubbed ("Coming Soon") | 7 |
| 🟡 Routed but gated off / redirected away | 3 |
| 🔴 Redirect target with no route registered | 1 |
| 🔴 Registered but no entry point (dead flows) | 9 routes |
| 🔴 Orphaned screen files (zero references) | 16 files |
| 🔴 Route constants with no screen at all | 21 |

---

## ✅ Working — routed & reachable

### Auth / onboarding
`lib/features/auth_onboarding/presentation/screens/`

| Route | Screen |
|---|---|
| `/landing` | LandingPage |
| `/auth-welcome` | AuthWelcomeScreen |
| `/email_input` | EmailInputScreen |
| `/otp_verification` | OtpVerificationScreen |
| `/enter-password` | EnterPasswordScreen |
| `/forgot-password` | ForgotPasswordScreen |
| `/reset-password` | ResetPasswordScreen |
| `/register` | RegisterScreen |
| `/create-user-info` | CreateUserInformation |
| `/interests-selection` · `/onboarding-interests-selection` | InterestsSelectionScreen |
| `/intent-selection` | IntentSelectionScreen |
| `/onboarding-primary-sport` | PrimarySportSelectionScreen |
| `/set-username` | SetUsernameScreen |
| `/onboarding-welcome` | ProfileOnboardingWelcomeScreen (progress screen) |
| `/welcome` | WelcomeScreen |
| `/email-verification` | EmailVerificationScreen |

**Add-persona flow** (entered from Settings) — reuses the same four screens in `addPersona` mode:
`/add-persona/interests` · `/add-persona/primary-sport` · `/add-persona/username` · `/add-persona/welcome`

### Main shell — `StatefulShellRoute.indexedStack`, 4 bottom-nav branches

| Branch | Route | Screen |
|---|---|---|
| 0 | `/home` | HomeScreen |
| 1 | `/community` | RealFriendsScreen |
| 2 | `/sports/venues` | VenuesScreen |
| 3 | `/sports/games` | GamesScreen |

### Detail / content

| Route | Screen |
|---|---|
| `/sports/games/:gameId` | GameDetailScreen (`?focus=requests` scrolls to pending requests) |
| `/sports/venues/:venueId` | VenueDetailScreen |
| `/news/:newsId` | NewsDetailScreen |
| `/sports-explore` | ExploreScreen (`explore/…/sports_screen.dart`) |
| `/activities` | ActivitiesScreenV2 — routed, but no in-app entry point |
| `/transactions` | TransactionsScreen |
| `/notifications` | NotificationsScreenV2 |

### Profile

`/profile` ProfileScreen · `/profile/sport` SportProfileScreen · `/profile/edit` ProfileEditScreen ·
`/profile/photo` ProfileAvatarScreen · `/profile/sports-preferences` ProfileSportsScreen ·
`/user-profile/:userId` UserProfileScreen

### Creation

| Route | Screen |
|---|---|
| `/create-game`, `/create-game-basic-info`, `/edit-game/:gameId` | **GameComposerScreen** (all three) |
| `/social-create-post`, `/post-composer` | **PostComposerScreen** (both) |

> Duplicate route pairs — `/create-game-basic-info` and `/post-composer` are redundant aliases.

### Social

`/social-search` SocialSearchScreen · `/hashtag/:slug` HashtagFeedScreen ·
`/social-post-detail/:postId` PostDetailScreen · `/social-friends` RealFriendsScreen ·
`/following/:profileId` and `/followers/:profileId` (RealFriendsScreen with `initialTab`)

### Settings & support

`/settings` · `/settings/account` · `/settings/privacy` · `/settings/notifications` ·
`/settings/theme` · `/settings/language` (LanguageSelectionScreen) ·
`/preferences/games` · `/preferences/availability` ·
`/help/center` · `/help/contact` · `/help/bug-report` ·
`/about/terms` · `/about/privacy` · `/about/licenses`

> `/about/terms` and `/about/privacy` are the only two routes reachable pre-auth without a session.

### Organiser — gated on `profileType == 'organiser'`

`/venue-submissions` · `/venue-submissions/create` · `/venue-submissions/:submissionId`

### Admin — gated on the `is_admin` RPC

`/admin/moderation-queue` ModerationQueueScreen · `/admin/safety-overview` SafetyOverviewScreen

### Error

`/error:message` → ErrorPage (also the router-wide `errorBuilder`)

### Reachable but not routed

Pushed with a raw `Navigator.push`, so they have no URL:

| Screen | Pushed from |
|---|---|
| `SportsLibraryScreen` | `explore/…/venues_screen.dart:132`, `explore/…/sports_screen.dart:1527` |
| `SavedLocationsScreen` | `location/…/widgets/home_location_picker_sheet.dart:114` |

---

## 🟡 Drafted — routed but stubbed or gated off

### "Coming Soon" placeholders

All six render `_PlaceholderScreen` (`app_router.dart:1715`) — a construction icon and a
"Coming Soon" label. Their feature flags are **all `true`**, so users can genuinely land here.

| Route | Flag gate |
|---|---|
| `/social-chat-list` | none |
| `/social-notifications` | `FeatureFlags.notifications` (true) |
| `/social-messages` | `FeatureFlags.messaging` (true) |
| `/social-chat/:conversationId` | `FeatureFlags.messaging` (true) |
| `/social-edit-post` | none |
| `/social-analytics` | none |

Plus `/language_selection` — an inline `Scaffold` with the literal text
"Language Selection - Coming Soon" (`app_router.dart:590`). The real screen is at
`/settings/language`.

### Gated off / redirected away

| Route | Behaviour |
|---|---|
| `/rewards` → RewardsScreen | `enableRewards = false` → redirects to `/home`. **The only route currently killed by a flag.** |
| `/social-feed` | redirects to `/home` (the feed moved into HomeScreen) |
| `/social` | redirects to `/community` |

---

## 🔴 Not working — unreachable or dead

### Broken redirect target

**`/onboarding-persona-selection` has no `GoRoute` registered.** It appears in the router's
`authPaths` and `onboardingPaths` sets (`app_router.dart:194`, `:211`) and is returned as a
redirect target at `app_router.dart:329` when `OnboardingStep.selectingPersona` and
`data.personaType == null`. When that branch fires, the path falls through to `errorBuilder`
and the user lands on the **ErrorPage**.

This is the one item here worth fixing rather than deleting.

### Registered but no entry point

Routes exist and build; nothing in the app navigates into them.

**Profile onboarding chain** — only `preferences → sports` links internally, and nothing links
into the chain at all:
`/onboarding-sports` · `/onboarding-preferences` · `/onboarding-privacy` · `/onboarding-completion`

**Social onboarding chain** — nothing pushes the welcome entry, so all five are dead:
`/social-onboarding-welcome` · `/social-onboarding-friends` · `/social-onboarding-privacy` ·
`/social-onboarding-notifications` · `/social-onboarding-complete`

### Orphaned screen files

Compile fine, zero references anywhere in `lib/`.

| File | Lines | Last touched | Note |
|---|---|---|---|
| `explore/presentation/screens/explore_nearby_screen.dart` | 864 | 2026-07-19 | superseded by nearby filters in routed tabs |
| `games/presentation/screens/games_nearby_screen.dart` | 722 | 2026-04-24 | ″ |
| `venues/presentation/screens/venues_nearby_screen.dart` | 619 | 2026-04-24 | ″ |
| `social/presentation/screens/create_post_screen.dart` | 1196 | 2026-07-19 | superseded by PostComposerScreen |
| `misc/presentation/screens/create_game_screen.dart` | 763 | 2026-08-14 | superseded by GameComposerScreen |
| `games/presentation/screens/create_game/game_screen_4_access_rules.dart` | 335 | 2026-07-12 | |
| `explore/presentation/screens/booking_summary_modal.dart` | — | — | |
| `explore/presentation/screens/payment_sheet.dart` | — | — | |
| `misc/presentation/screens/rebook_flow.dart` | — | — | |
| `rewards/presentation/screens/rewards_analytics_dashboard.dart` | 1100+ | — | 3 sub-dashboards are "Coming Soon" bodies |
| `explore/presentation/screens/sports_history_screen.dart` | 335 | — | class unused; file kept only for its `PastGame` model |

The five step files under `misc/presentation/screens/` are dead **only because their parent
`create_game_screen.dart` is dead** — they are still imported by it:
`sport_format_step.dart` · `venue_slot_step.dart` · `player_invitation_step.dart` ·
`participation_payment_step.dart` · `review_confirmation_step.dart`

### Route constants with no screen at all

Declared in `route_constants.dart`, never registered in the router:

`profileSwitcher` · `onboardingBasicInfo` · `games` · `bookings` · `support` · `loyalty` ·
`designSystemDemo` · `sports` · `leaderboard` ·
`createGameVenueSelection` · `createGameDateTime` · `createGamePlayerSettings` ·
`createGamePricing` · `createGameAdditionalDetails` · `createGameReview` ·
`socialPost` · `addPost` · `socialProfileDetail` · `socialChatDetail` ·
`socialAddFriends` · `userFriendsList`
