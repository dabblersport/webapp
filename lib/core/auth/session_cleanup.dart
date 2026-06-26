import 'package:flutter_riverpod/flutter_riverpod.dart';

// User-scoped providers that cache data for the currently signed-in user.
// These must be reset on logout / account switch so the previous user's data
// never leaks into a new session.
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart'
    as auth_p;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    as profile_p;
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/features/social/providers.dart' as squads_p;
import 'package:dabbler/features/social/providers/community_providers.dart';
import 'package:dabbler/features/social/circles_providers.dart';
import 'package:dabbler/features/rewards/providers/check_in_providers.dart';

/// Invalidates every provider that holds data scoped to the currently
/// signed-in user. Call this on sign-out and on sign-in so that stale data
/// from a previous account never leaks into the new session (profile, settings,
/// persona, social graph, posts, notifications, etc.).
///
/// Invalidating a `.family` provider clears all of its instances at once.
void resetUserScopedProviders(Ref ref) {
  // --- Identity / current user ---
  ref.invalidate(auth_p.currentUserProvider);
  ref.invalidate(currentUserIdProvider);
  ref.invalidate(currentUserEmailProvider);
  ref.invalidate(currentDisplayNameProvider);
  ref.invalidate(myProfileProvider);
  ref.invalidate(authenticatedUserWithProfileProvider);
  ref.invalidate(watchMyProfileProvider);
  ref.invalidate(isProfileCompleteProvider);
  ref.invalidate(hasProfileProvider);

  // --- Profile + settings controllers ---
  ref.invalidate(profile_p.profileControllerProvider);
  ref.invalidate(profile_p.sportsProfileControllerProvider);
  ref.invalidate(profile_p.organiserProfileControllerProvider);
  ref.invalidate(profile_p.settingsControllerProvider);
  ref.invalidate(profile_p.preferencesControllerProvider);
  ref.invalidate(profile_p.privacyControllerProvider);
  ref.invalidate(profile_p.profileEditControllerProvider);
  ref.invalidate(profile_p.activeProfileTypeProvider);
  ref.invalidate(profile_p.profileBootstrapCompletedProvider);
  ref.invalidate(profile_p.myProfileIdProvider);
  ref.invalidate(profile_p.currentUserProvider);
  ref.invalidate(profile_p.availableProfilesProvider);

  // --- Persona ---
  ref.invalidate(personaServiceProvider);

  // --- Posts (families: invalidating clears every instance) ---
  ref.invalidate(userPostsProvider);
  ref.invalidate(userLikedPostsProvider);
  ref.invalidate(userCommentedPostsProvider);
  ref.invalidate(userRepostedPostsProvider);
  ref.invalidate(myReactionsProvider);

  // --- Blocks ---
  ref.invalidate(blockedUserIdsProvider);
  ref.invalidate(blockedUsersWithProfilesProvider);

  // --- Squads ---
  ref.invalidate(squads_p.mySquadsProvider);
  ref.invalidate(squads_p.mySquadsStreamProvider);
  ref.invalidate(squads_p.mySquadInvitesProvider);

  // --- Friends / community ---
  ref.invalidate(friendshipsProvider);
  ref.invalidate(friendEdgesProvider);
  ref.invalidate(incomingFriendRequestsProvider);
  ref.invalidate(outgoingFriendRequestsProvider);

  // --- Circles ---
  ref.invalidate(circleListProvider);
  ref.invalidate(friendInboxProvider);
  ref.invalidate(friendOutboxProvider);

  // --- Check-in / rewards ---
  ref.invalidate(checkInStatusDetailProvider);
  ref.invalidate(checkInRecordProvider);
  ref.invalidate(watchCheckInStatusProvider);
}
