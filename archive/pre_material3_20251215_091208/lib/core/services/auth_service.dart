import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../../utils/constants/route_constants.dart';
import '../models/google_sign_in_result.dart';
import '../utils/identifier_detector.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // AUTHENTICATION METHODS
  // =====================================================

  // Normalize email to avoid hidden/invisible chars and casing issues
  String _normalizeEmail(String email) {
    // Remove zero-width and BOM chars, collapse/strip whitespace, and lowercase
    final noInvisible = email.replaceAll(RegExp(r"[\u200B-\u200D\uFEFF]"), "");
    final noSpaces = noInvisible.replaceAll(RegExp(r"\s+"), "");
    return noSpaces.trim().toLowerCase();
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = _normalizeEmail(email);

      final response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
      );

      return response;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Sign up with email and password (NO metadata - we use profiles table)
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);

    try {
      final response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        // NO metadata - we store everything in public.profiles
      );

      return response;
    } catch (e) {
      throw Exception(
        'Account creation failed. Please try again later or contact support.',
      );
    }
  }

  /// Create profile in public.profiles table (called after onboarding completes)
  Future<void> createProfile({
    required String userId,
    required String displayName,
    required String username,
    required int age,
    required String gender,
    required String intention,
    required String preferredSport,
    String? interests,
  }) async {
    try {
      // Map intention to profile_type
      final profileType = intention == 'organise' ? 'organiser' : 'player';

      // Check if profile already exists
      final existingProfile = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingProfile != null) {
        return;
      }

      // Update display_name in auth.users metadata
      await _supabase.auth.updateUser(
        UserAttributes(data: {'display_name': displayName}),
      );

      // Create profile with onboarding data
      final profileData = {
        'user_id': userId,
        'display_name': displayName,
        'username': username,
        'age': age,
        'gender': gender.toLowerCase(),
        'intention': intention.toLowerCase(),
        'profile_type': profileType,
        'preferred_sport': preferredSport.toLowerCase(),
        'interests': interests,
      };

      // Insert profile and get the created row with id, profile_type, and preferred_sport
      final insertedProfile = await _supabase
          .from(SupabaseConfig.usersTable)
          .insert(profileData)
          .select('id, profile_type, preferred_sport')
          .single();

      // Extract values from inserted profile
      final profileId = insertedProfile['id'] as String;
      final insertedProfileType = insertedProfile['profile_type'] as String;
      final primarySport =
          (insertedProfile['preferred_sport'] ?? preferredSport.toLowerCase())
              as String;

      // Create child profile based on profile_type
      if (insertedProfileType == 'player') {
        // Create sport_profile for player
        try {
          // Use 'sport' column (actual database column name)
          // Primary key is (profile_id, sport)
          final sportProfileData = {
            'profile_id': profileId,
            'sport': primarySport.toLowerCase(),
            'skill_level': 1, // Beginner level
          };
          final sportProfileResult = await _supabase
              .from('sport_profiles')
              .insert(sportProfileData)
              .select()
              .single();
        } catch (e) {
          if (e is PostgrestException) {}
          // Don't rethrow - profile creation succeeded, sport profile is secondary
          // But log extensively so we can debug
        }
      } else if (insertedProfileType == 'organiser') {
        // Create organiser_profile for organiser
        try {
          final organiserProfileData = {
            'profile_id': profileId,
            'sport': primarySport.toLowerCase(),
            // Use DB defaults for: organiser_level (1), commission_type ('percent'),
            // commission_value (0), is_verified (false), is_active (true)
          };
          final organiserProfileResult = await _supabase
              .from('organiser_profiles')
              .insert(organiserProfileData)
              .select()
              .single();
        } catch (e) {
          if (e is PostgrestException) {}
          // Don't rethrow - profile creation succeeded, organiser profile is secondary
          // But log extensively so we can debug
        }
      } else {}
    } catch (e) {
      throw Exception('Failed to create user profile: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = _normalizeEmail(email);

      final response = await _supabase.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      // Verify the auth state immediately after signin
      final isAuth = _supabase.auth.currentUser != null;

      return response;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  /// Sign in with phone (OTP) - Legacy method, use sendOtp instead
  Future<void> signInWithPhone({required String phone}) async {
    try {
      await _supabase.auth.signInWithOtp(phone: phone);
    } catch (e) {
      throw Exception('Phone sign in failed: $e');
    }
  }

  /// Unified OTP sending method - works for both email and phone
  Future<void> sendOtp({
    required String identifier,
    required IdentifierType type,
  }) async {
    try {
      if (type == IdentifierType.email) {
        final normalizedEmail = _normalizeEmail(identifier);
        await _supabase.auth.signInWithOtp(email: normalizedEmail);
      } else {
        await _supabase.auth.signInWithOtp(phone: identifier);
      }
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  /// Unified OTP verification method - works for both email and phone
  /// After successful verification, ensures stub profile exists
  Future<AuthResponse> verifyOtp({
    required String identifier,
    required IdentifierType type,
    required String token,
  }) async {
    try {
      AuthResponse response;
      if (type == IdentifierType.email) {
        final normalizedEmail = _normalizeEmail(identifier);
        response = await _supabase.auth.verifyOTP(
          email: normalizedEmail,
          token: token,
          type: OtpType.email,
        );
      } else {
        response = await _supabase.auth.verifyOTP(
          phone: identifier,
          token: token,
          type: OtpType.sms,
        );
      }

      // After successful OTP verification, ensure stub profile exists
      if (response.user != null) {
        await ensureStubProfileForCurrentUser();
      }

      return response;
    } catch (e) {
      throw Exception('OTP verification failed: $e');
    }
  }

  /// Legacy verifyOtp method for phone - use unified verifyOtp instead
  Future<AuthResponse> verifyOtpLegacy({
    required String phone,
    required String token,
  }) async {
    return verifyOtp(
      identifier: phone,
      type: IdentifierType.phone,
      token: token,
    );
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw Exception('Password update failed: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Build deep link that opens the app to reset password screen
      final redirect =
          '${RoutePaths.deepLinkPrefix}${RoutePaths.resetPassword}';
      await _supabase.auth.resetPasswordForEmail(email, redirectTo: redirect);
    } catch (e) {
      throw Exception('Password reset email failed: $e');
    }
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      // For mobile, use the app's custom scheme for OAuth callback
      // For web, use the current origin
      final redirectUrl = kIsWeb ? Uri.base.origin : 'dabbler://app';

      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      return launched;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  /// Handle Google sign-in flow and determine the correct path for the user
  /// This should be called AFTER OAuth completes (e.g., from auth state listener)
  Future<GoogleSignInResult> handleGoogleSignInFlow() async {
    try {
      // Get the authenticated user (should be set after OAuth completes)
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const GoogleSignInResultError(
          message: 'Please complete Google sign-in and try again.',
        );
      }

      // Step 3: Derive provider flags
      final email = user.email;
      if (email == null || email.isEmpty) {
        return const GoogleSignInResultError(
          message: 'Google account does not have an email address.',
        );
      }

      final phone = user.phone;
      final hasPhone = phone != null && phone.isNotEmpty;
      final phoneValue =
          phone ?? ''; // Extract non-null value for use in branches

      // Check if user has Google as provider
      final identities = user.identities;
      final hasGoogleProvider =
          (identities != null &&
              identities.isNotEmpty &&
              identities.any((identity) => identity.provider == 'google')) ||
          (user.appMetadata['provider'] == 'google');

      // Step 4: Query profile store by user_id (since profiles don't store email)
      final profile = await getUserProfile(fields: ['id', 'user_id']);
      final hasProfile = profile != null;

      if (hasProfile) {}

      // Step 5: Apply branching logic
      if (!hasProfile && !hasPhone) {
        // User A: New email, no phone - needs full onboarding flow
        return GoogleSignInResultGoToOnboarding(email: email);
      } else if (!hasProfile && hasPhone) {
        // User B: New email, has phone
        return GoogleSignInResultGoToPhoneOtp(phone: phoneValue, email: email);
      } else if (hasProfile && hasGoogleProvider) {
        // User C: Existing profile, already used Google
        return const GoogleSignInResultGoToHome();
      } else if (hasProfile && !hasGoogleProvider) {
        // User D: Existing profile, but not created via Google
        return GoogleSignInResultRequirePassword(email: email);
      } else {
        // Fallback: Should not reach here, but handle gracefully
        return const GoogleSignInResultError(
          message: 'Unable to determine sign-in path. Please contact support.',
        );
      }
    } catch (e) {
      return GoogleSignInResultError(
        message: 'Google sign-in failed: ${e.toString()}',
      );
    }
  }

  /// Get profile by email (helper for Google flow)
  /// Note: Profiles don't store email, so we need to check auth.users first
  Future<Map<String, dynamic>?> getProfileByEmail(String email) async {
    try {
      // Since profiles don't store email, we need to:
      // 1. Check if a user exists with this email in auth.users
      // 2. If yes, get their user_id and query profiles by user_id

      // For now, we'll use the current user if their email matches
      final user = _supabase.auth.currentUser;
      if (user != null && user.email?.toLowerCase() == email.toLowerCase()) {
        return await getUserProfile();
      }

      // If we need to query by email, we'd need an RPC function
      // For now, return null if not the current user
      return null;
    } catch (e) {
      return null;
    }
  }

  // =====================================================
  // USER STATUS METHODS
  // =====================================================

  /// Get current authenticated user
  User? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    return user;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    final authenticated = _supabase.auth.currentUser != null;
    return authenticated;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    final userId = _supabase.auth.currentUser?.id;
    return userId;
  }

  /// Get current user email
  String? getCurrentUserEmail() {
    final email = _supabase.auth.currentUser?.email;
    return email;
  }

  // =====================================================
  // USER VALIDATION METHODS
  // =====================================================

  /// Check if a user exists by email in auth.users
  /// Uses a unified database function to query auth.users table
  Future<bool> checkUserExistsByEmail(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    return _checkUserExistsByIdentifier(normalizedEmail);
  }

  /// Check if a user exists by phone in auth.users
  /// Uses a unified database function to query auth.users table
  Future<bool> checkUserExistsByPhone(String phone) async {
    return _checkUserExistsByIdentifier(phone);
  }

  /// Internal method to check if a user exists by email or phone in auth.users
  /// Uses a database function that checks both email and phone columns
  Future<bool> _checkUserExistsByIdentifier(String identifier) async {
    try {
      // Call the unified database function to check auth.users
      final response = await _supabase.rpc(
        'check_user_exists_by_identifier',
        params: {'identifier': identifier},
      );

      final exists = response as bool;

      return exists;
    } catch (e) {
      // On error, return false to allow flow to continue to onboarding
      return false;
    }
  }

  // =====================================================
  // USER PROFILE METHODS
  // =====================================================

  /// Get user profile from database
  Future<Map<String, dynamic>?> getUserProfile({List<String>? fields}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return null;
      }

      final selectFields = (fields == null || fields.isEmpty)
          ? '*'
          : fields.join(',');

      // Use maybeSingle() instead of single() to handle missing profiles gracefully
      final response = await _supabase
          .from(SupabaseConfig.usersTable)
          .select(selectFields)
          .eq('user_id', user.id) // Query by user_id, not id
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Ensure a stub profile exists for the current authenticated user
  /// Creates a minimal profile with onboard=FALSE if none exists
  Future<void> ensureStubProfileForCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return;
      }

      // Check if profile already exists
      final existingProfile = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('id, onboard')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingProfile != null) {
        return;
      }

      // Create stub profile with minimal data and onboard=FALSE
      final emailPart = user.email?.split('@').first;
      final displayName =
          user.userMetadata?['display_name'] as String? ??
          emailPart ??
          'Player';

      // Ensure display name meets minimum length requirement (2 chars)
      final safeDisplayName = displayName.length >= 2
          ? displayName.substring(
              0,
              displayName.length > 50 ? 50 : displayName.length,
            )
          : 'Player';

      final stubProfileData = {
        'user_id': user.id,
        'display_name': safeDisplayName,
        'profile_type': 'player', // Default, will be updated during onboarding
        'onboard': false, // Explicitly set to FALSE
        'is_active': true,
        'is_player': true,
      };

      await _supabase.from(SupabaseConfig.usersTable).insert(stubProfileData);
    } catch (e) {
      // Don't throw - this is called after auth, we don't want to break the flow
      // The profile will be created during onboarding completion if needed
    }
  }

  /// Complete onboarding by updating profile with all user data and setting onboard=TRUE
  /// Also creates sport_profiles or organiser_profiles row and syncs to auth.users metadata
  Future<void> completeOnboarding({
    required String displayName,
    required String username,
    required int age,
    required String gender,
    required String intention,
    required String preferredSport,
    String? interests,
    String? password, // Required for email users, null for phone/Google users
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Map intention to profile_type
      final profileType = intention == 'organise' ? 'organiser' : 'player';

      // Update password if provided (for email users)
      if (password != null && password.isNotEmpty) {
        await _supabase.auth.updateUser(UserAttributes(password: password));
      }

      // Update auth.users metadata with key profile fields
      final userMetadata = {
        'display_name': displayName,
        'preferred_sport': preferredSport,
        'primary_sport': preferredSport,
        if (username.isNotEmpty) 'username': username,
      };

      await _supabase.auth.updateUser(UserAttributes(data: userMetadata));

      // Check if profile exists (should exist as stub from ensureStubProfileForCurrentUser)
      final existingProfile = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('id, profile_type')
          .eq('user_id', user.id)
          .maybeSingle();

      String profileId;
      if (existingProfile != null) {
        // Update existing profile
        profileId = existingProfile['id'] as String;

        final updateData = {
          'display_name': displayName,
          'username': username,
          'age': age,
          'gender': gender.toLowerCase(),
          'intention': intention.toLowerCase(),
          'profile_type': profileType,
          'preferred_sport': preferredSport.toLowerCase(),
          'primary_sport': preferredSport.toLowerCase(),
          'interests': interests,
          'onboard': true, // Mark onboarding as complete
          'is_player': profileType == 'player',
        };

        await _supabase
            .from(SupabaseConfig.usersTable)
            .update(updateData)
            .eq('user_id', user.id);
      } else {
        // Create new profile (fallback if stub wasn't created)

        final profileData = {
          'user_id': user.id,
          'display_name': displayName,
          'username': username,
          'age': age,
          'gender': gender.toLowerCase(),
          'intention': intention.toLowerCase(),
          'profile_type': profileType,
          'preferred_sport': preferredSport.toLowerCase(),
          'primary_sport': preferredSport.toLowerCase(),
          'interests': interests,
          'onboard': true,
          'is_active': true,
          'is_player': profileType == 'player',
        };

        final insertedProfile = await _supabase
            .from(SupabaseConfig.usersTable)
            .insert(profileData)
            .select('id')
            .single();

        profileId = insertedProfile['id'] as String;
      }

      // Create child profile based on profile_type
      if (profileType == 'player') {
        // Create sport_profile for player
        try {
          final sportProfileData = {
            'profile_id': profileId,
            'sport': preferredSport.toLowerCase(),
            'skill_level': 1, // Beginner level
          };

          // Check if sport_profile already exists
          final existingSportProfile = await _supabase
              .from('sport_profiles')
              .select('profile_id')
              .eq('profile_id', profileId)
              .eq('sport', preferredSport.toLowerCase())
              .maybeSingle();

          if (existingSportProfile == null) {
            await _supabase.from('sport_profiles').insert(sportProfileData);
          } else {}
        } catch (e) {
          // Don't rethrow - profile update succeeded, sport profile is secondary
        }
      } else if (profileType == 'organiser') {
        // Create organiser_profile for organiser
        try {
          final organiserProfileData = {
            'profile_id': profileId,
            'sport': preferredSport.toLowerCase(),
            // Use DB defaults for: organiser_level (1), commission_type ('percent'),
            // commission_value (0), is_verified (false), is_active (true)
          };

          // Check if organiser_profile already exists
          final existingOrganiserProfile = await _supabase
              .from('organiser_profiles')
              .select('id')
              .eq('profile_id', profileId)
              .eq('sport', preferredSport.toLowerCase())
              .maybeSingle();

          if (existingOrganiserProfile == null) {
            await _supabase
                .from('organiser_profiles')
                .insert(organiserProfileData);
          } else {}
        } catch (e) {
          // Don't rethrow - profile update succeeded, organiser profile is secondary
        }
      }
    } catch (e) {
      throw Exception('Failed to complete onboarding: ${e.toString()}');
    }
  }

  /// Check if username already exists in public.profiles
  Future<bool> checkUsernameExists(String username) async {
    try {
      final result = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('id')
          .eq('username', username)
          .maybeSingle();

      final exists = result != null;

      return exists;
    } catch (e) {
      return false; // On error, allow the username (validation will happen on insert)
    }
  }

  /// Batch fetch profiles by IDs with field selection
  Future<List<Map<String, dynamic>>> getProfilesByIds(
    List<String> userIds, {
    List<String>? fields,
  }) async {
    if (userIds.isEmpty) return [];
    final selectFields = (fields == null || fields.isEmpty)
        ? '*'
        : fields.join(',');
    try {
      final rows = await _supabase
          .from(SupabaseConfig.usersTable)
          .select(selectFields)
          .inFilter('user_id', userIds);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
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
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Prefer server-side RPC if available for consistent authorization/validation
      try {
        final response = await _supabase.rpc(
          'update_user_profile',
          params: {
            'user_display_name': displayName,
            'user_username': username,
            'user_bio': bio,
            'user_phone': phone,
            'user_date_of_birth': dateOfBirth?.toIso8601String(),
            'user_age': age,
            'user_gender': gender,
            'user_nationality': nationality,
            'user_skill_level': skillLevel,
            'user_sports': sports,
            'user_interests': interests,
            'user_intent': intent,
            'user_location': location,
            'user_timezone': timezone,
            'user_language': language,
          },
        );

        return response;
      } on PostgrestException catch (e) {
        // If RPC is missing (PGRST202) or not yet deployed, fallback to direct table update
        final isMissingRpc =
            e.code == 'PGRST202' ||
            (e.message.toLowerCase().contains('could not find the function') &&
                e.message.toLowerCase().contains('update_user_profile'));

        if (!isMissingRpc) {
          rethrow;
        }

        // Build updates map with only non-null values to avoid wiping existing data
        final Map<String, dynamic> updates = {
          'updated_at': DateTime.now().toIso8601String(),
        };

        // CRITICAL: display_name is NOT NULL in database - validate before updating
        if (displayName != null) {
          final trimmedName = displayName.trim();
          if (trimmedName.isEmpty) {
            throw Exception(
              'Display name cannot be empty - database constraint will fail',
            );
          }
          if (trimmedName.length < 2) {
            throw Exception('Display name must be at least 2 characters long');
          }
          if (trimmedName.length > 50) {
            throw Exception('Display name must be 50 characters or less');
          }
          updates['display_name'] = trimmedName;
        }

        if (bio != null) {
          updates['bio'] = bio.trim().isEmpty ? null : bio.trim();
        }
        if (phone != null) {
          updates['phone'] = phone.trim().isEmpty ? null : phone.trim();
        }
        // Note: dateOfBirth not supported, we use age instead
        if (age != null) updates['age'] = age;
        if (gender != null && gender.trim().isNotEmpty) {
          updates['gender'] = gender.trim();
        }
        // Note: nationality not supported in current schema
        if (skillLevel != null) {
          updates['skill_level'] = skillLevel.trim().isEmpty
              ? null
              : skillLevel.trim();
        }
        if (sports != null) updates['sports'] = sports;
        // Note: interests not supported, we use sports instead
        if (intent != null && intent.trim().isNotEmpty) {
          updates['intent'] = intent.trim();
        }
        // Note: location not supported in current schema
        if (timezone != null) {
          updates['timezone'] = timezone.trim().isEmpty
              ? null
              : timezone.trim();
        }
        if (language != null) {
          updates['language'] = language.trim().isEmpty
              ? null
              : language.trim();
        }

        if (updates.length <= 1) {
          // Only updated_at
          final current = await _supabase
              .from(SupabaseConfig.usersTable)
              .select()
              .eq('user_id', user.id) // Match by user_id FK
              .single();
          return current;
        }

        try {
          final updated = await _supabase
              .from(SupabaseConfig.usersTable)
              .update(updates)
              .eq('user_id', user.id) // Match by user_id FK
              .select()
              .single();

          return updated;
        } on PostgrestException catch (e2) {
          // Handle schema differences gracefully (e.g., full_name vs name, preferred_sports vs sports)
          final isMissingColumn =
              e2.code == '42703' ||
              e2.message.toLowerCase().contains('column') &&
                  e2.message.toLowerCase().contains('does not exist');
          if (!isMissingColumn) rethrow;

          final Map<String, dynamic> altUpdates = {};
          // Map name -> full_name if present
          if (updates.containsKey('name')) {
            altUpdates['full_name'] = updates['name'];
          }
          // Map sports -> preferred_sports if present
          if (updates.containsKey('sports')) {
            altUpdates['preferred_sports'] = updates['sports'];
          }
          // Pass-through others
          if (updates.containsKey('age')) altUpdates['age'] = updates['age'];
          if (updates.containsKey('gender')) {
            altUpdates['gender'] = updates['gender'];
          }
          if (updates.containsKey('intent')) {
            altUpdates['intent'] = updates['intent'];
          }

          // If error reveals a specific missing column, drop it from the retry payload
          try {
            final lower = e2.message.toLowerCase();
            final startIdx = lower.indexOf('column ');
            final endIdx = lower.indexOf(' does not exist');
            if (startIdx != -1 && endIdx != -1 && endIdx > startIdx + 7) {
              final rawCol = e2.message.substring(startIdx + 7, endIdx).trim();
              final missingCol = rawCol
                  .replaceAll('u.', '')
                  .replaceAll('public.', '')
                  .replaceAll('profiles.', '')
                  .trim();
              altUpdates.remove(missingCol);
              // Also remove counterparts if applicable
              if (missingCol == 'name') altUpdates.remove('name');
              if (missingCol == 'sports') altUpdates.remove('sports');
            }
          } catch (_) {
            /* ignore parsing issues */
          }

          if (altUpdates.isEmpty) rethrow;

          final updatedAlt = await _supabase
              .from(SupabaseConfig.usersTable)
              .update(altUpdates)
              .eq('user_id', user.id)
              .select()
              .single();

          return updatedAlt;
        }
      }
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }

  // =====================================================
  // SESSION MANAGEMENT
  // =====================================================

  /// Get current session
  Session? getCurrentSession() {
    final session = _supabase.auth.currentSession;
    return session;
  }

  /// Check if session is expired
  bool isSessionExpired() {
    final session = _supabase.auth.currentSession;
    if (session == null) return true;

    final now = DateTime.now();
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (session.expiresAt ?? 0) * 1000,
    );
    final expired = now.isAfter(expiresAt);

    return expired;
  }

  /// Refresh session
  Future<AuthResponse?> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();

      return response;
    } catch (e) {
      return null;
    }
  }
}
