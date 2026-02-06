import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/profile/sports_profile.dart';
import '../../domain/usecases/manage_sports_profile_usecase.dart';
import 'package:dabbler/core/fp/failure.dart';

/// State for sports profile management
class SportsProfileState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final List<SportProfile> profiles;
  final Map<String, dynamic> pendingChanges;
  final bool hasUnsavedChanges;
  final DateTime? lastSyncTime;
  final Map<String, List<String>> achievements;
  final String? activeProfileId;

  const SportsProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.profiles = const [],
    this.pendingChanges = const {},
    this.hasUnsavedChanges = false,
    this.lastSyncTime,
    this.achievements = const {},
    this.activeProfileId,
  });

  SportsProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    List<SportProfile>? profiles,
    Map<String, dynamic>? pendingChanges,
    bool? hasUnsavedChanges,
    DateTime? lastSyncTime,
    Map<String, List<String>>? achievements,
    String? activeProfileId,
  }) {
    return SportsProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      profiles: profiles ?? this.profiles,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      achievements: achievements ?? this.achievements,
      activeProfileId: activeProfileId,
    );
  }
}

/// Controller for sports profile management
class SportsProfileController extends StateNotifier<SportsProfileState> {
  final ManageSportsProfileUseCase? _manageSportsProfileUseCase;

  SportsProfileController({
    ManageSportsProfileUseCase? manageSportsProfileUseCase,
  }) : _manageSportsProfileUseCase = manageSportsProfileUseCase,
       super(const SportsProfileState());

  /// Load sports profiles
  /// [userId] - The auth user ID
  /// [profileId] - Optional profile ID. If not provided, will fetch player profile for user
  Future<void> loadSportsProfiles(String userId, {String? profileId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final client = Supabase.instance.client;

      String? resolvedProfileId = profileId;

      // If profileId not provided, resolve the player profile.id for this auth user
      if (resolvedProfileId == null) {
        final profileRow = await client
            .from('profiles')
            .select('id')
            .eq('user_id', userId)
            .eq('profile_type', 'player')
            .maybeSingle();

        if (profileRow == null) {
          state = state.copyWith(
            isLoading: false,
            profiles: const [],
            achievements: const {},
            activeProfileId: null,
          );
          return;
        }

        resolvedProfileId = profileRow['id'] as String;
      }

      // Select columns that actually exist in the sport_profiles table
      // Note: Database uses matches_played (not games_played), primary_position (not preferred_positions)
      // average_rating can be calculated from rating_total/rating_count if needed
      final List<dynamic> rows = await client
          .from('sport_profiles')
          .select(
            'sport, skill_level, matches_played, primary_position, rating_total, rating_count, profile_id',
          )
          .eq('profile_id', resolvedProfileId);

      final profiles = rows
          .map(
            (row) =>
                SportProfile.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();

      // Achievements are not modeled in simple schema; keep empty by default
      final achievements = <String, List<String>>{
        for (final p in profiles) p.sportId: <String>[],
      };

      state = state.copyWith(
        isLoading: false,
        profiles: profiles,
        achievements: achievements,
        lastSyncTime: DateTime.now(),
        pendingChanges: {},
        hasUnsavedChanges: false,
        activeProfileId: resolvedProfileId,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getErrorMessage(error),
      );
    }
  }

  /// Create a new sports profile
  Future<void> createSportsProfile({
    required String sportId,
    required String sportName,
    required SkillLevel skillLevel,
    int yearsPlaying = 0,
    List<String> preferredPositions = const [],
    bool isPrimarySport = false,
  }) async {
    if (state.profiles.any((profile) => profile.sportId == sportId)) {
      state = state.copyWith(
        errorMessage: 'Profile for this sport already exists',
      );
      return;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final params = ManageSportsProfileParams(
        userId: 'current-user-id', // Would come from auth
        sportId: sportId,
        sportName: sportName,
        skillLevel: skillLevel.toString().split('.').last,
        yearsOfExperience: yearsPlaying,
        isPrimarySport: isPrimarySport,
        action: 'create',
      );

      if (_manageSportsProfileUseCase == null) {
        final newProfile = SportProfile(
          sportId: sportId,
          sportName: sportName,
          skillLevel: skillLevel,
          yearsPlaying: yearsPlaying,
          preferredPositions: preferredPositions,
          certifications: [],
          achievements: [],
          isPrimarySport: isPrimarySport,
        );

        final updatedProfiles = List<SportProfile>.from(state.profiles);
        updatedProfiles.add(newProfile);

        state = state.copyWith(isSaving: false, profiles: updatedProfiles);
        return;
      }

      final result = await _manageSportsProfileUseCase.call(params);

      result.fold(
        (failure) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: _getFailureMessage(failure),
          );
        },
        (updateResult) {
          final newProfile = SportProfile(
            sportId: sportId,
            sportName: sportName,
            skillLevel: skillLevel,
            yearsPlaying: yearsPlaying,
            preferredPositions: preferredPositions,
            isPrimarySport: isPrimarySport,
          );

          final updatedProfiles = List<SportProfile>.from(state.profiles);
          updatedProfiles.add(newProfile);

          final updatedAchievements = Map<String, List<String>>.from(
            state.achievements,
          );
          updatedAchievements[sportId] = [];

          state = state.copyWith(
            isSaving: false,
            profiles: updatedProfiles,
            achievements: updatedAchievements,
            lastSyncTime: DateTime.now(),
            activeProfileId: sportId,
          );
        },
      );
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _getErrorMessage(error),
      );
    }
  }

  /// Update skill level
  Future<void> updateSkillLevel(String sportId, SkillLevel skillLevel) async {
    await _updateProfileField(
      sportId,
      'skillLevel',
      skillLevel.toString().split('.').last,
    );
  }

  /// Update years playing
  Future<void> updateYearsPlaying(String sportId, int years) async {
    if (years < 0 || years > 50) {
      state = state.copyWith(
        errorMessage: 'Years playing must be between 0 and 50',
      );
      return;
    }
    await _updateProfileField(sportId, 'yearsPlaying', years);
  }

  /// Update preferred positions
  Future<void> updatePreferredPositions(
    String sportId,
    List<String> positions,
  ) async {
    if (positions.length > 3) {
      state = state.copyWith(
        errorMessage: 'You can select up to 3 preferred positions',
      );
      return;
    }
    await _updateProfileField(sportId, 'preferredPositions', positions);
  }

  /// Toggle primary sport
  Future<void> togglePrimarySport(String sportId, bool isPrimary) async {
    // If setting as primary, unset other primary sports
    if (isPrimary) {
      final updatedProfiles = state.profiles.map((profile) {
        if (profile.sportId == sportId) {
          return profile.copyWith(isPrimarySport: true);
        } else {
          return profile.copyWith(isPrimarySport: false);
        }
      }).toList();

      state = state.copyWith(
        profiles: updatedProfiles,
        hasUnsavedChanges: true,
      );
    } else {
      await _updateProfileField(sportId, 'isPrimarySport', isPrimary);
    }
  }

  /// Add achievement
  Future<void> addAchievement(String sportId, String achievement) async {
    final currentAchievements = List<String>.from(
      state.achievements[sportId] ?? [],
    );

    if (currentAchievements.contains(achievement)) {
      state = state.copyWith(errorMessage: 'Achievement already exists');
      return;
    }

    currentAchievements.add(achievement);

    final updatedAchievements = Map<String, List<String>>.from(
      state.achievements,
    );
    updatedAchievements[sportId] = currentAchievements;

    // Also update the profile
    final updatedProfiles = state.profiles.map((profile) {
      if (profile.sportId == sportId) {
        return profile.copyWith(achievements: currentAchievements);
      }
      return profile;
    }).toList();

    state = state.copyWith(
      profiles: updatedProfiles,
      achievements: updatedAchievements,
      hasUnsavedChanges: true,
    );
  }

  /// Remove achievement
  Future<void> removeAchievement(String sportId, String achievement) async {
    final currentAchievements = List<String>.from(
      state.achievements[sportId] ?? [],
    );
    currentAchievements.remove(achievement);

    final updatedAchievements = Map<String, List<String>>.from(
      state.achievements,
    );
    updatedAchievements[sportId] = currentAchievements;

    // Also update the profile
    final updatedProfiles = state.profiles.map((profile) {
      if (profile.sportId == sportId) {
        return profile.copyWith(achievements: currentAchievements);
      }
      return profile;
    }).toList();

    state = state.copyWith(
      profiles: updatedProfiles,
      achievements: updatedAchievements,
      hasUnsavedChanges: true,
    );
  }

  /// Delete sports profile
  Future<void> deleteSportsProfile(String sportId) async {
    final profileExists = state.profiles.any(
      (profile) => profile.sportId == sportId,
    );
    if (!profileExists) {
      state = state.copyWith(errorMessage: 'Profile not found');
      return;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final params = ManageSportsProfileParams(
        userId: 'current-user-id',
        sportId: sportId,
        action: 'delete',
      );

      if (_manageSportsProfileUseCase == null) {
        final updatedProfiles = state.profiles
            .where((p) => p.sportId != sportId)
            .toList();
        final updatedAchievements = Map<String, List<String>>.from(
          state.achievements,
        );
        updatedAchievements.remove(sportId);

        String? newActiveProfileId = state.activeProfileId;
        if (state.activeProfileId == sportId) {
          newActiveProfileId = updatedProfiles.isNotEmpty
              ? updatedProfiles.first.sportId
              : null;
        }

        state = state.copyWith(
          isSaving: false,
          profiles: updatedProfiles,
          achievements: updatedAchievements,
          activeProfileId: newActiveProfileId,
        );
        return;
      }

      final result = await _manageSportsProfileUseCase.call(params);

      result.fold(
        (failure) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: _getFailureMessage(failure),
          );
        },
        (updateResult) {
          final updatedProfiles = state.profiles
              .where((p) => p.sportId != sportId)
              .toList();
          final updatedAchievements = Map<String, List<String>>.from(
            state.achievements,
          );
          updatedAchievements.remove(sportId);

          // If deleted profile was active, set new active profile
          String? newActiveProfileId = state.activeProfileId;
          if (state.activeProfileId == sportId) {
            newActiveProfileId = updatedProfiles.isNotEmpty
                ? updatedProfiles.first.sportId
                : null;
          }

          state = state.copyWith(
            isSaving: false,
            profiles: updatedProfiles,
            achievements: updatedAchievements,
            lastSyncTime: DateTime.now(),
            activeProfileId: newActiveProfileId,
          );
        },
      );
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _getErrorMessage(error),
      );
    }
  }

  /// Set active profile
  void setActiveProfile(String sportId) {
    if (state.profiles.any((profile) => profile.sportId == sportId)) {
      state = state.copyWith(activeProfileId: sportId);
    }
  }

  /// Get profile by sport ID
  SportProfile? getProfileBySport(String sportId) {
    try {
      return state.profiles.firstWhere((p) => p.sportId == sportId);
    } catch (e) {
      return null;
    }
  }

  /// Get active profile
  SportProfile? get activeProfile {
    if (state.activeProfileId == null) return null;
    return getProfileBySport(state.activeProfileId!);
  }

  /// Get primary sport profile
  SportProfile? get primaryProfile {
    try {
      return state.profiles.firstWhere((p) => p.isPrimarySport);
    } catch (e) {
      return null;
    }
  }

  /// Get sports profile summary
  Map<String, dynamic> get profilesSummary {
    final profiles = state.profiles;

    if (profiles.isEmpty) {
      return {
        'totalProfiles': 0,
        'totalGames': 0,
        'averageSkillLevel': 'None',
        'totalAchievements': 0,
        'primarySport': 'None',
      };
    }

    final totalGames = profiles.fold<int>(
      0,
      (sum, profile) => sum + profile.gamesPlayed,
    );
    final skillLevels = [
      SkillLevel.beginner,
      SkillLevel.intermediate,
      SkillLevel.advanced,
      SkillLevel.expert,
    ];
    final averageSkillIndex = profiles.isNotEmpty
        ? profiles
                  .map((p) => skillLevels.indexOf(p.skillLevel))
                  .reduce((a, b) => a + b) ~/
              profiles.length
        : 0;

    final totalAchievements = profiles.fold<int>(
      0,
      (sum, profile) => sum + profile.achievements.length,
    );
    final primarySport = primaryProfile?.sportName ?? 'None';

    return {
      'totalProfiles': profiles.length,
      'totalGames': totalGames,
      'averageSkillLevel':
          skillLevels[averageSkillIndex.clamp(0, skillLevels.length - 1)]
              .toString()
              .split('.')
              .last,
      'totalAchievements': totalAchievements,
      'primarySport': primarySport,
    };
  }

  /// Update a single profile field
  Future<void> _updateProfileField(
    String sportId,
    String field,
    dynamic value,
  ) async {
    final updatedProfiles = state.profiles.map((profile) {
      if (profile.sportId == sportId) {
        switch (field) {
          case 'skillLevel':
            final skillLevel = SkillLevel.values.firstWhere(
              (e) => e.toString().split('.').last == value,
              orElse: () => SkillLevel.beginner,
            );
            return profile.copyWith(skillLevel: skillLevel);
          case 'yearsPlaying':
            return profile.copyWith(yearsPlaying: value as int);
          case 'preferredPositions':
            return profile.copyWith(preferredPositions: value as List<String>);
          case 'isPrimarySport':
            return profile.copyWith(isPrimarySport: value as bool);
          default:
            return profile;
        }
      }
      return profile;
    }).toList();

    final updatedPendingChanges = Map<String, dynamic>.from(
      state.pendingChanges,
    );
    updatedPendingChanges['${sportId}_$field'] = value;

    state = state.copyWith(
      profiles: updatedProfiles,
      pendingChanges: updatedPendingChanges,
      hasUnsavedChanges: true,
    );
  }

  /// Convert error to user-friendly message
  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }

  /// Convert failure to user-friendly message
  String _getFailureMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ValidationFailure:
        return failure.message;
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      case ServerFailure:
        return 'Server error. Please try again later.';
      default:
        return failure.message;
    }
  }
}
