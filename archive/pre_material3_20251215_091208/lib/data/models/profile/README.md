# Profile models overview

This folder contains the core profile data types used across the app. There are three main "layers" of profile-related models:

1. **Database models (row shapes)**  
   These mirror the Supabase tables and are usually Freezed/JsonSerializable types under `lib/data/models/`:
   - `Profile` / `ProfileModel` (from `lib/data/models/profile.dart` / `profile_model.dart`):
     - Reflect the raw `profiles` table schema (column names, nullability, defaults).
     - Used when reading and writing directly to Supabase.
     - Drive generated `*.freezed.dart` / `*.g.dart` code.

2. **Domain/user-facing model**  
   `UserProfile` (in `user_profile.dart`) is the primary type used by features and UI:
   - Aggregates core profile fields (`id`, `userId`, `displayName`, `avatarUrl`, etc.).
   - Includes enriched information and relationships:
     - `sportsProfiles` (list of `SportProfile`),
     - `statistics` (`ProfileStatistics`),
     - `privacySettings` (`PrivacySettings`),
     - `preferences` (`UserPreferences`),
     - `settings` (`UserSettings`).
   - Provides behaviour/logic helpers such as:
     - `getDisplayName`, `getFullName`,
     - `calculateProfileCompletion`,
     - `getPrimarySport`, `getCompatibilityScore`,
     - `isActiveUser`, `getActivityStatus`.
   - Constructed from Supabase rows via `UserProfile.fromJson` using the column set defined in profile repositories/datasources.

3. **Write/update helper models**  
   For some operations we use dedicated "model" classes that are optimised for write payloads:
   - `ProfileModel`, `SportProfileModel`, `UserPreferencesModel`, etc.
   - Usually have `toSupabaseJson`/`toInsertJson` methods that:
     - Use `includeIfNull: false` semantics so we only send changed fields.
     - Rename fields to match Supabase column names (`display_name`, `avatar_url`, ...).

## Source of truth

- The **database schema** is the ultimate source of truth for column names and types.  
- `Profile` / `ProfileModel` reflect that schema closely and drive codegen.  
- `UserProfile` is the **canonical in-app representation** of an end-user profile and is what most features should depend on.

When introducing new profile-related fields:

1. Update the Supabase schema (migration).  
2. Update `Profile`/`ProfileModel` and regenerate Freezed/JSON code.  
3. Update `UserProfile.fromJson` / `toJson` to include the new field.  
4. If the field participates in derived behaviour (completion, compatibility, etc.), extend the relevant methods in `UserProfile`.
