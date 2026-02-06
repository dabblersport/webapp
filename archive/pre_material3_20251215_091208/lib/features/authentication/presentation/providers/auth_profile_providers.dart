import 'package:dabbler/core/fp/failure.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/services/auth_profile_service.dart';
import '../../../../data/repositories/profiles_repository.dart';
import '../../../../data/repositories/profiles_repository_impl.dart';
import '../../../../features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile.dart';
import './auth_providers.dart'; // For authServiceProvider

// =====================================================
// REPOSITORY PROVIDERS
// =====================================================

/// Provides ProfilesRepository implementation
final profilesRepositoryProvider = Provider<ProfilesRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ProfilesRepositoryImpl(supabaseService);
});

// =====================================================
// SERVICE PROVIDERS
// =====================================================

/// Provides the unified AuthProfileService
/// This bridges authentication with profile data
final authProfileServiceProvider = Provider<AuthProfileService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final profilesRepo = ref.watch(profilesRepositoryProvider);

  return AuthProfileService(
    authService: authService,
    profilesRepository: profilesRepo,
  );
});

// =====================================================
// PROFILE DATA PROVIDERS
// =====================================================

/// Provides the current user's profile
/// Returns Result<Profile, Failure> which must be handled with fold()
final myProfileProvider = FutureProvider<Result<Profile, Failure>>((ref) async {
  final service = ref.watch(authProfileServiceProvider);
  return await service.getMyProfile();
});

/// Provides authenticated user with their profile
/// Returns null if not authenticated or profile not found
final authenticatedUserWithProfileProvider =
    FutureProvider<AuthenticatedUserWithProfile?>((ref) async {
      final service = ref.watch(authProfileServiceProvider);
      return await service.getAuthenticatedUserWithProfile();
    });

/// Stream provider for watching profile changes in real-time
final watchMyProfileProvider = StreamProvider<Result<Profile?, Failure>>((ref) {
  final service = ref.watch(authProfileServiceProvider);
  return service.watchMyProfile();
});

// =====================================================
// CONVENIENCE PROVIDERS
// =====================================================

/// Provides the current display name (or fallback)
/// Returns empty string if not authenticated or profile not found
final currentDisplayNameProvider = FutureProvider<String>((ref) async {
  final userWithProfile = await ref.watch(
    authenticatedUserWithProfileProvider.future,
  );
  return userWithProfile?.displayName ?? '';
});

/// Provides the current user ID
/// Returns null if not authenticated
final currentUserIdProvider = Provider<String?>((ref) {
  final service = ref.watch(authProfileServiceProvider);
  return service.currentUserId;
});

/// Provides the current user email
/// Returns null if not authenticated
final currentUserEmailProvider = Provider<String?>((ref) {
  final service = ref.watch(authProfileServiceProvider);
  return service.currentUserEmail;
});

/// Check if profile is complete
final isProfileCompleteProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(authProfileServiceProvider);
  return await service.isProfileComplete();
});

/// Check if user has a profile
final hasProfileProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(authProfileServiceProvider);
  return await service.hasProfile();
});

// =====================================================
// PROFILE BY ID PROVIDERS (for viewing other profiles)
// =====================================================

/// Provides a profile by user ID
/// Family provider - pass userId as parameter
final profileByUserIdProvider =
    FutureProvider.family<Result<Profile, Failure>, String>((
      ref,
      userId,
    ) async {
      final service = ref.watch(authProfileServiceProvider);
      return await service.getProfileByUserId(userId);
    });

/// Provides a public profile by username
/// Family provider - pass username as parameter
final publicProfileByUsernameProvider =
    FutureProvider.family<Result<Profile?, Failure>, String>((
      ref,
      username,
    ) async {
      final service = ref.watch(authProfileServiceProvider);
      return await service.getPublicProfileByUsername(username);
    });
