# Onboarding Audit — Dabbler Flutter App

## Context

This audit maps the complete onboarding system as it exists today, identifies which screens/files are active, which are dead, and surfaces cleanup recommendations. No code changes are included.

---

## 1. Active Onboarding Flow

The app uses a **DB-authoritative onboarding** system driven by `OnboardingController` (in `lib/features/auth_onboarding/`) and enforced via `_handleRedirect` in `lib/app/app_router.dart`.

### Step-by-step flow

```
/landing  (LandingPage)
    ↓
/auth-welcome  (AuthWelcomeScreen)
    ↓ choose method
┌──────────────────────────────┐
│  Phone / Email OTP flow      │   or   Password flow
│  /phone_input                │        /email_input → /enter-password
│  /email_input                │        (EnterPasswordScreen)
│  /otp_verification           │
└──────────────────────────────┘
    ↓ after auth
/welcome  (WelcomeScreen — post-login, shows once per session)
    ↓ DB check: no profile
/create-user-info  (CreateUserInformation — age + gender)
    ↓ pushed from screen
/intent-selection  (IntentSelectionScreen — persona: player/organiser/hoster/socialiser)
    ↓ after persona picked, back to create-user-info flow
        (username is collected in SetUsernameScreen via /set-username)
    ↓ DB step: selectingPrimarySport
/onboarding-interests-selection  (InterestsSelectionScreen — sports interests)
    ↓ navigates to
/onboarding-primary-sport  (PrimarySportSelectionScreen)
    ↓ finalizeOnboarding() sets profiles.onboard = TRUE
/home  (onboarding complete)
```

### DB completion markers

| Field | Value | Meaning |
|-------|-------|---------|
| `profiles.onboard` | `true` | Onboarding complete |
| `profiles.profile_completion` | `'complete'` | Paired with above |

### Resume logic (`checkResumeState()`)

| DB state | Resumes at |
|----------|-----------|
| 0 profiles | `/create-user-info` |
| 1 profile, `onboard=false`, no persona ext | `creatingPersonaExtension` |
| 1 profile, `onboard=false`, has persona, no sport | `selectingPrimarySport` |
| 1 profile, `onboard=false`, `profile_completion='sport_added'` | `finalizing` |
| 1 profile, `onboard=true` | completed |
| 2+ profiles | completed |

---

## 2. File Inventory — Active Files

### Screens (in use)
| File | Route | Purpose |
|------|-------|---------|
| `screens/landing_screen.dart` | `/landing` | First screen after splash |
| `screens/auth_welcome_screen.dart` | `/auth-welcome` | Auth method picker |
| `screens/identity_verification_screen.dart` | `/phone_input` | Phone/email identifier entry |
| `screens/email_input_screen.dart` | `/email_input` | Email entry + OTP send |
| `screens/otp_verification_screen.dart` | `/otp_verification` | 6-digit OTP entry |
| `screens/email_password_screen.dart` | `/enter-password` | Password login for returning users |
| `screens/forgot_password_screen.dart` | `/forgot-password` | Forgot password |
| `screens/reset_password_screen.dart` | `/reset-password` | Reset password (deep link) |
| `screens/create_user_information.dart` | `/create-user-info` | Age + gender (Step 1) |
| `screens/intent_selection_screen.dart` | `/intent-selection` | Persona picker (Step 2) |
| `screens/set_username_screen.dart` | `/set-username` (also `/add-persona/username`) | Username + display name (Step 3) |
| `screens/interests_selection_screen.dart` | `/onboarding-interests-selection` (also `/add-persona/interests`) | Sport interests (Step 4) |
| `screens/primary_sport_selection_screen.dart` | `/onboarding-primary-sport` (also `/add-persona/primary-sport`) | Primary sport (Step 5) |
| `screens/welcome_screen.dart` | `/welcome` + `/add-persona/welcome` | Post-login / post-persona welcome |
| `screens/language_selection_screen.dart` | `/settings/language` | Language picker (settings only) |

### Controllers / Providers / Repositories (in use)
| File | Purpose |
|------|---------|
| `presentation/controllers/onboarding_controller.dart` | Main DB-authoritative onboarding state machine |
| `presentation/controllers/auth_controller.dart` | Auth session state |
| `presentation/providers/auth_providers.dart` | Auth providers + RouterRefreshNotifier |
| `presentation/providers/auth_profile_providers.dart` | Profile lookup providers |
| `presentation/providers/selected_country_provider.dart` | Location state |
| `presentation/providers/onboarding_data_provider.dart` | In-memory registration data |
| `data/repositories/onboarding_repository.dart` | Idempotent Supabase writes |
| `domain/models/onboarding_state.dart` | Freezed state models (OnboardingStep, OnboardingData, OnboardingState) |
| `domain/location/location_detector.dart` | IP + locale country detection |
| `data/services/ip_country_detection_service.dart` | IP-based location via edge function |
| `application/onboarding/onboarding_coordinator.dart` | Post-auth route decision |

---

## 3. Dead / Unused Files

### Dead screens

| File | Why Dead |
|------|----------|
| `screens/register_screen.dart` | Uses `registerControllerProvider` (stub), navigates to `/confirm-email` (no route). Never meaningfully reachable. |
| `screens/email_verification_screen.dart` | Legacy email confirmation flow (pre-OTP). Route exists but the active auth flow never navigates there. |
| `screens/set_password_screen.dart` | In `onboardingPaths` but **nothing navigates to it**. Also imports the dead `OnboardingService`. |
| `onboarding_scenarios/profile/onboarding_welcome_screen.dart` | In router at `/onboarding-welcome` but the DB-authoritative redirect never enforces this route. Unreachable in normal flow. |
| `onboarding_scenarios/profile/onboarding_sports_screen.dart` | Same — `/onboarding-sports` is in router but never enforced. |
| `onboarding_scenarios/profile/onboarding_preferences_screen.dart` | Same — `/onboarding-preferences`. |
| `onboarding_scenarios/profile/onboarding_privacy_screen.dart` | Same — `/onboarding-privacy`. |
| `onboarding_scenarios/profile/onboarding_completion_screen.dart` | Same — `/onboarding-completion`. |
| `onboarding_scenarios/social/social_onboarding_welcome_screen.dart` | In router at `/social-onboarding-welcome` but redirect never triggers this flow. |
| `onboarding_scenarios/social/social_onboarding_friends_screen.dart` | Same — `/social-onboarding-friends`. |
| `onboarding_scenarios/social/social_onboarding_privacy_screen.dart` | Same — `/social-onboarding-privacy`. |
| `onboarding_scenarios/social/social_onboarding_notifications_screen.dart` | Same — `/social-onboarding-notifications`. |
| `onboarding_scenarios/social/social_onboarding_complete_screen.dart` | Same — `/social-onboarding-complete`. |

**Total dead screens: 13** (5 profile scenario + 5 social scenario + register + email_verification + set_password)

### Dead services / controllers

| File | Why Dead |
|------|----------|
| `lib/core/services/onboarding_service.dart` | SharedPreferences-based onboarding tracker; replaced entirely by the DB-authoritative system. Only consumed by `set_password_screen.dart` (itself dead). |
| `lib/core/services/mock_onboarding_service.dart` | Test mock for the dead `OnboardingService`. |
| `lib/features/profile/services/onboarding_controller.dart` | Duplicate onboarding controller inside the profile feature. Has analytics hooks but is not wired into the app's routing or providers. |
| `lib/features/profile/services/onboarding_gamification.dart` | Only imported from dead profile scenario screens (`onboarding_welcome_screen`, `onboarding_completion_screen`). |

### Dead/redundant routes and constants

| Issue | Location |
|-------|----------|
| `lib/routes/app_routes.dart` | Duplicate route constants file alongside `lib/utils/constants/route_constants.dart`. Not imported anywhere in the main app. |
| `RoutePaths.onboardingBasicInfo` (`/onboarding-basic-info`) | Defined in `route_constants.dart` but no route registered in router, never navigated to. |
| `/interests-selection` route (`RoutePaths.interestsSelection`) | Duplicate of `/onboarding-interests-selection`. Both point to `InterestsSelectionScreen`. The active redirect uses the `/onboarding-` version; the old path is in `authPaths` but the redirect never enforces it. |
| `/language_selection` route (hardcoded path) | Shows a hardcoded "Coming Soon" `Scaffold` instead of using `LanguageSelectionScreen`; the real language screen is at `/settings/language`. |

---

## 4. Bugs Found During Audit

### Bug 1 — Missing route for `/onboarding-persona-selection` (HIGH)
**Location:** `lib/app/app_router.dart` lines 175, 193, 306–309

The redirect enforces `OnboardingStep.selectingPersona` → `RoutePaths.onboardingPersonaSelection` (`/onboarding-persona-selection`), but **no GoRoute is registered for this path**. Users resuming with a `selectingPersona` step hit GoRouter's error page.

The actual persona selection screen (`IntentSelectionScreen`) is registered at `/intent-selection` and is pushed directly from `CreateUserInformation`. The fix is either:
- Register a route for `/onboarding-persona-selection` pointing to `IntentSelectionScreen`, or
- Change the redirect to use `RoutePaths.intentSelection` instead.

### Bug 2 — Duplicate `OnboardingData` class
Two different classes named `OnboardingData` exist:
- Freezed model: `lib/features/auth_onboarding/domain/models/onboarding_state.dart`
- Plain class: `lib/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart`

They have overlapping fields but serve the same purpose. The provider version should be merged into or replaced by the domain model.

---

## 5. Cleanup Recommendations (Priority Order)

### P1 — Fix routing bug
**Fix the missing `/onboarding-persona-selection` route.** In `app_router.dart`, either add a GoRoute for `RoutePaths.onboardingPersonaSelection` pointing to `IntentSelectionScreen`, or change the redirect case to `RoutePaths.intentSelection`. This is a silent runtime error for returning users.

### P2 — Delete dead scenario screens (13 files)
Remove the entire `onboarding_scenarios/` directory:
- `lib/features/auth_onboarding/presentation/onboarding_scenarios/profile/` (5 files)
- `lib/features/auth_onboarding/presentation/onboarding_scenarios/social/` (5 files)

And remove the 3 standalone dead screens:
- `screens/register_screen.dart`
- `screens/email_verification_screen.dart`
- `screens/set_password_screen.dart`

Also remove their route registrations from `app_router.dart` and route constants from `route_constants.dart`.

### P3 — Delete dead services (4 files)
- `lib/core/services/onboarding_service.dart`
- `lib/core/services/mock_onboarding_service.dart`
- `lib/features/profile/services/onboarding_controller.dart`
- `lib/features/profile/services/onboarding_gamification.dart`

### P4 — Remove duplicate route constants file
Delete `lib/routes/app_routes.dart` (duplicate of `route_constants.dart`, not imported anywhere).

### P5 — Clean up dead route constants
In `route_constants.dart` and `app_router.dart`, remove:
- `RoutePaths.onboardingBasicInfo` and `RouteNames.onboardingBasicInfo`
- The `/interests-selection` route (keep `/onboarding-interests-selection`)
- The `/language_selection` hardcoded placeholder route
- All route names/paths for the deleted scenario screens

### P6 — Unify `OnboardingData`
Consolidate the two `OnboardingData` classes. The `onboarding_data_provider.dart` plain class should either be removed (in favour of the Freezed domain model) or clearly renamed to avoid confusion.

---

## 6. File Count Summary

| Category | Count |
|----------|-------|
| Active onboarding screens | 15 |
| Dead onboarding screens | 13 |
| Active controllers/providers/repos | 11 |
| Dead services/controllers | 4 |
| Dead/duplicate support files | 2 |
| **Total dead files** | **~19** |
