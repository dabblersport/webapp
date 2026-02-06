import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/data/models/profile/organiser_profile.dart';

/// State for organiser profile management
class OrganiserProfileState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final List<OrganiserProfile> profiles;
  final bool hasUnsavedChanges;
  final DateTime? lastSyncTime;

  const OrganiserProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.profiles = const [],
    this.hasUnsavedChanges = false,
    this.lastSyncTime,
  });

  OrganiserProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    List<OrganiserProfile>? profiles,
    bool? hasUnsavedChanges,
    DateTime? lastSyncTime,
  }) {
    return OrganiserProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      profiles: profiles ?? this.profiles,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// Controller for organiser profile management
class OrganiserProfileController extends StateNotifier<OrganiserProfileState> {
  OrganiserProfileController() : super(const OrganiserProfileState());

  /// Load organiser profiles for a user
  /// [userId] - The auth user ID
  /// [profileId] - Optional profile ID. If not provided, will fetch organiser profile for user
  Future<void> loadOrganiserProfiles(String userId, {String? profileId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final client = Supabase.instance.client;

      String? resolvedProfileId = profileId;

      // If profileId not provided, resolve the organiser profile.id for this auth user
      if (resolvedProfileId == null) {
        final profileRow = await client
            .from('profiles')
            .select('id')
            .eq('user_id', userId)
            .eq('profile_type', 'organiser')
            .maybeSingle();

        if (profileRow == null) {
          state = state.copyWith(isLoading: false, profiles: const []);
          return;
        }

        resolvedProfileId = profileRow['id'] as String;
      }

      // Load organiser profiles from organiser_profiles table
      final List<dynamic> rows = await client
          .from('organiser_profiles')
          .select()
          .eq('profile_id', resolvedProfileId);

      final profiles = rows
          .map(
            (row) => OrganiserProfile.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();

      state = state.copyWith(
        isLoading: false,
        profiles: profiles,
        lastSyncTime: DateTime.now(),
        hasUnsavedChanges: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getErrorMessage(error),
      );
    }
  }

  /// Get organiser profile by sport
  OrganiserProfile? getProfileBySport(String sport) {
    try {
      return state.profiles.firstWhere((p) => p.sport == sport);
    } catch (e) {
      return null;
    }
  }

  /// Convert error to user-friendly message
  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }
}
