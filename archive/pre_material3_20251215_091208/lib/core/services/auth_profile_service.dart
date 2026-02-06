import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/profile.dart';
import '../../data/repositories/profiles_repository.dart';
import 'auth_service.dart';

/// Service that bridges authentication with profile data
/// Provides unified access to user auth state and profile information
class AuthProfileService {
  final AuthService _authService;
  final ProfilesRepository _profilesRepository;

  AuthProfileService({
    required AuthService authService,
    required ProfilesRepository profilesRepository,
  }) : _authService = authService,
       _profilesRepository = profilesRepository;

  // =====================================================
  // AUTH STATE QUERIES
  // =====================================================

  /// Check if user is authenticated
  bool get isAuthenticated => _authService.isAuthenticated();

  /// Get current authenticated user
  User? get currentUser => _authService.getCurrentUser();

  /// Get current user ID
  String? get currentUserId => _authService.getCurrentUserId();

  /// Get current user email
  String? get currentUserEmail => _authService.getCurrentUserEmail();

  /// Get current session
  Session? get currentSession => _authService.getCurrentSession();

  // =====================================================
  // PROFILE DATA ACCESS
  // =====================================================

  /// Get current user's profile
  /// Returns Result<Profile, Failure> - use fold() to handle success/failure
  Future<Result<Profile, Failure>> getMyProfile() async {
    if (!isAuthenticated) {
      return failure(const AuthFailure(message: 'User not authenticated'));
    }

    return await _profilesRepository.getMyProfile();
  }

  /// Get profile by user ID
  /// Returns Result<Profile, Failure> - use fold() to handle success/failure
  Future<Result<Profile, Failure>> getProfileByUserId(String userId) async {
    return await _profilesRepository.getByUserId(userId);
  }

  /// Get public profile by username
  /// Returns Result<Profile?, Failure> - profile may not exist
  Future<Result<Profile?, Failure>> getPublicProfileByUsername(
    String username,
  ) async {
    return await _profilesRepository.getPublicByUsername(username);
  }

  /// Watch current user's profile for real-time updates
  /// Returns a stream that emits Result<Profile?, Failure> on changes
  Stream<Result<Profile?, Failure>> watchMyProfile() {
    if (!isAuthenticated) {
      return Stream.value(
        failure(const AuthFailure(message: 'User not authenticated')),
      );
    }

    return _profilesRepository.watchMyProfile();
  }

  // =====================================================
  // COMBINED AUTH + PROFILE OPERATIONS
  // =====================================================

  /// Get authenticated user with their profile
  /// Returns null if not authenticated or profile not found
  Future<AuthenticatedUserWithProfile?>
  getAuthenticatedUserWithProfile() async {
    if (!isAuthenticated) {
      return null;
    }

    final user = currentUser;
    if (user == null) {
      return null;
    }

    final profileResult = await getMyProfile();

    return profileResult.fold((failure) {
      return null;
    }, (profile) => AuthenticatedUserWithProfile(user: user, profile: profile));
  }

  // =====================================================
  // PROFILE UPDATE OPERATIONS
  // =====================================================

  /// Update current user's profile
  /// This uses the legacy AuthService.updateUserProfile method
  /// TODO: Migrate to use ProfilesRepository.upsert instead
  Future<Result<Map<String, dynamic>, Failure>> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? phone,
    DateTime? dateOfBirth,
    int? age,
    String? gender,
    String? nationality,
    String? skillLevel,
    List<String>? sports,
    List<String>? interests,
    String? intent,
    String? location,
    String? timezone,
    String? language,
  }) async {
    if (!isAuthenticated) {
      return failure(const AuthFailure(message: 'User not authenticated'));
    }

    try {
      final result = await _authService.updateUserProfile(
        displayName: displayName,
        username: username,
        bio: bio,
        phone: phone,
        dateOfBirth: dateOfBirth,
        age: age,
        gender: gender,
        nationality: nationality,
        skillLevel: skillLevel,
        sports: sports,
        interests: interests,
        intent: intent,
        location: location,
        timezone: timezone,
        language: language,
      );

      return success(result);
    } catch (e) {
      return failure(ServerFailure(message: e.toString()));
    }
  }

  // =====================================================
  // AUTH OPERATIONS
  // =====================================================

  /// Sign out current user
  Future<Result<void, Failure>> signOut() async {
    try {
      await _authService.signOut();
      return success(null);
    } catch (e) {
      return failure(ServerFailure(message: e.toString()));
    }
  }

  /// Sign in with email and password
  Future<Result<AuthResponse, Failure>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      return success(response);
    } catch (e) {
      return failure(AuthFailure(message: e.toString()));
    }
  }

  /// Sign up with email and password
  Future<Result<AuthResponse, Failure>> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );
      return success(response);
    } catch (e) {
      return failure(AuthFailure(message: e.toString()));
    }
  }

  /// Refresh auth session
  Future<Result<AuthResponse?, Failure>> refreshSession() async {
    try {
      final response = await _authService.refreshSession();
      return success(response);
    } catch (e) {
      return failure(AuthFailure(message: e.toString()));
    }
  }

  // =====================================================
  // UTILITY METHODS
  // =====================================================

  /// Check if user profile exists
  Future<bool> hasProfile() async {
    if (!isAuthenticated) {
      return false;
    }

    final result = await getMyProfile();
    return result.fold((failure) => false, (profile) => true);
  }

  /// Check if profile is complete
  /// (has all required fields filled)
  Future<bool> isProfileComplete() async {
    final userWithProfile = await getAuthenticatedUserWithProfile();

    if (userWithProfile == null) {
      return false;
    }

    // Check if all mandatory fields are set
    final profile = userWithProfile.profile;
    return profile.displayName.isNotEmpty;
  }
}

/// Data class combining authenticated user with their profile
class AuthenticatedUserWithProfile {
  final User user;
  final Profile profile;

  const AuthenticatedUserWithProfile({
    required this.user,
    required this.profile,
  });

  String get userId => user.id;
  String get email => user.email ?? '';
  String get displayName => profile.displayName;
  String? get username => profile.username;
  String? get bio => profile.bio;
  String? get avatarUrl => profile.avatarUrl;
  String? get city => profile.city;
  String? get country => profile.country;
  bool? get isActive => profile.isActive;

  @override
  String toString() =>
      'AuthenticatedUserWithProfile(email: $email, displayName: $displayName)';
}

// Helper functions to create Result values
Result<T, Failure> success<T>(T value) => Ok(value);
Result<T, Failure> failure<T>(Failure error) => Err(error);
