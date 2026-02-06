import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import '../repositories/profile_repository.dart';

/// Parameters for managing sports profile
class ManageSportsProfileParams {
  final String userId;
  final String? sportId;
  final String? sportName;
  final String? skillLevel;
  final int? yearsOfExperience;
  final int? gamesPlayed;
  final int? gamesWon;
  final int? gamesLost;
  final double? averageRating;
  final List<String>? achievements;
  final String? preferredPosition;
  final bool? isPrimarySport;
  final bool? isActive;
  final Map<String, dynamic>? customStats;
  final String? action; // 'create', 'update', 'delete'

  const ManageSportsProfileParams({
    required this.userId,
    this.sportId,
    this.sportName,
    this.skillLevel,
    this.yearsOfExperience,
    this.gamesPlayed,
    this.gamesWon,
    this.gamesLost,
    this.averageRating,
    this.achievements,
    this.preferredPosition,
    this.isPrimarySport,
    this.isActive,
    this.customStats,
    this.action = 'update',
  });

  bool get hasUpdates =>
      sportName != null ||
      skillLevel != null ||
      yearsOfExperience != null ||
      gamesPlayed != null ||
      gamesWon != null ||
      gamesLost != null ||
      averageRating != null ||
      achievements != null ||
      preferredPosition != null ||
      isPrimarySport != null ||
      isActive != null ||
      customStats != null;
}

/// Result of sports profile management operation
class ManageSportsProfileResult {
  final UserProfile updatedProfile;
  final SportProfile? sportProfile;
  final List<String> warnings;
  final Map<String, dynamic> changedFields;
  final Map<String, double> performanceMetrics;

  const ManageSportsProfileResult({
    required this.updatedProfile,
    this.sportProfile,
    required this.warnings,
    required this.changedFields,
    required this.performanceMetrics,
  });
}

/// Use case for managing sports profiles with comprehensive validation and statistics tracking
class ManageSportsProfileUseCase {
  final ProfileRepository _profileRepository;

  ManageSportsProfileUseCase(this._profileRepository);

  Future<Either<Failure, ManageSportsProfileResult>> call(
    ManageSportsProfileParams params,
  ) async {
    try {
      // Validate input parameters
      final validationResult = _validateParams(params);
      if (validationResult.isLeft) {
        return Left(validationResult.leftOrNull()!);
      }

      // Get current profile
      final currentProfileResult = await _profileRepository.getProfile(
        params.userId,
      );
      if (currentProfileResult.isLeft) {
        return Left(currentProfileResult.leftOrNull()!);
      }

      final currentProfile = currentProfileResult.rightOrNull()!;

      // Process based on action type
      Either<Failure, ManageSportsProfileResult> result;

      switch (params.action?.toLowerCase()) {
        case 'create':
          result = await _createSportProfile(params, currentProfile);
          break;
        case 'delete':
          result = await _deleteSportProfile(params, currentProfile);
          break;
        case 'update':
        default:
          result = await _updateSportProfile(params, currentProfile);
          break;
      }

      return result;
    } catch (e) {
      return Left(DataFailure(message: 'Sports profile management failed: $e'));
    }
  }

  /// Create a new sport profile
  Future<Either<Failure, ManageSportsProfileResult>> _createSportProfile(
    ManageSportsProfileParams params,
    UserProfile currentProfile,
  ) async {
    if (params.sportId == null || params.sportName == null) {
      return const Left(
        ValidationFailure(
          message: 'Sport ID and name are required for creation',
        ),
      );
    }

    // Check if sport profile already exists
    final existingSport = currentProfile.sportsProfiles
        .cast<SportProfile?>()
        .firstWhere(
          (sport) => sport?.sportId == params.sportId,
          orElse: () => null,
        );

    if (existingSport != null) {
      return const Left(
        ConflictFailure(message: 'Sport profile already exists'),
      );
    }

    // Parse skill level
    final skillLevel = _parseSkillLevel(params.skillLevel ?? 'beginner');

    // Parse preferred positions
    final preferredPositions = params.preferredPosition != null
        ? [params.preferredPosition!]
        : <String>[];

    // Create new sport profile with defaults
    final newSportProfile = SportProfile(
      sportId: params.sportId!,
      sportName: params.sportName!,
      skillLevel: skillLevel,
      yearsPlaying: params.yearsOfExperience ?? 0,
      preferredPositions: preferredPositions,
      certifications: [],
      achievements: params.achievements ?? [],
      isPrimarySport:
          params.isPrimarySport ?? (currentProfile.sportsProfiles.isEmpty),
      lastPlayed: DateTime.now(),
      gamesPlayed: params.gamesPlayed ?? 0,
      averageRating: params.averageRating ?? 0.0,
    );

    // Add to profile's sports list
    final updatedSportProfiles = [
      ...currentProfile.sportsProfiles,
      newSportProfile,
    ];
    final updatedProfile = UserProfile(
      id: currentProfile.id,
      userId: currentProfile.userId,
      email: currentProfile.email,
      displayName: currentProfile.displayName,
      avatarUrl: currentProfile.avatarUrl,
      createdAt: currentProfile.createdAt,
      updatedAt: DateTime.now(),
      bio: currentProfile.bio,
      age: currentProfile.age,
      city: currentProfile.city,
      country: currentProfile.country,
      phoneNumber: currentProfile.phoneNumber,
      username: currentProfile.username,
      gender: currentProfile.gender,
      profileType: currentProfile.profileType,
      intention: currentProfile.intention,
      verified: currentProfile.verified,
      isActive: currentProfile.isActive,
      geoLat: currentProfile.geoLat,
      geoLng: currentProfile.geoLng,
      sportsProfiles: updatedSportProfiles,
      statistics: currentProfile.statistics,
      privacySettings: currentProfile.privacySettings,
      preferences: currentProfile.preferences,
      settings: currentProfile.settings,
    );

    // Update profile in repository
    final updateResult = await _profileRepository.updateProfile(updatedProfile);
    if (updateResult.isLeft) {
      return Left(updateResult.leftOrNull()!);
    }

    final finalProfile = updateResult.rightOrNull()!;
    final performanceMetrics = _calculatePerformanceMetrics(newSportProfile);
    final warnings = _generateWarnings(newSportProfile, {});

    return Right(
      ManageSportsProfileResult(
        updatedProfile: finalProfile,
        sportProfile: newSportProfile,
        warnings: warnings,
        changedFields: {'action': 'created'},
        performanceMetrics: performanceMetrics,
      ),
    );
  }

  /// Update existing sport profile
  Future<Either<Failure, ManageSportsProfileResult>> _updateSportProfile(
    ManageSportsProfileParams params,
    UserProfile currentProfile,
  ) async {
    if (params.sportId == null) {
      return const Left(
        ValidationFailure(message: 'Sport ID is required for update'),
      );
    }

    // Find existing sport profile
    final existingSportIndex = currentProfile.sportsProfiles.indexWhere(
      (sport) => sport.sportId == params.sportId,
    );

    if (existingSportIndex == -1) {
      return const Left(NotFoundFailure(message: 'Sport profile not found'));
    }

    final existingSport = currentProfile.sportsProfiles[existingSportIndex];

    // Apply business rules for updates
    _applyBusinessRules(params, existingSport);

    // Parse skill level
    final skillLevel = params.skillLevel != null
        ? _parseSkillLevel(params.skillLevel!)
        : existingSport.skillLevel;

    // Parse preferred positions
    final preferredPositions = params.preferredPosition != null
        ? [params.preferredPosition!]
        : existingSport.preferredPositions;

    // Create updated sport profile
    final updatedSportProfile = SportProfile(
      sportId: existingSport.sportId,
      sportName: params.sportName ?? existingSport.sportName,
      skillLevel: skillLevel,
      yearsPlaying: params.yearsOfExperience ?? existingSport.yearsPlaying,
      preferredPositions: preferredPositions,
      certifications: existingSport.certifications,
      achievements: params.achievements ?? existingSport.achievements,
      isPrimarySport: params.isPrimarySport ?? existingSport.isPrimarySport,
      lastPlayed: DateTime.now(),
      gamesPlayed: params.gamesPlayed ?? existingSport.gamesPlayed,
      averageRating: params.averageRating ?? existingSport.averageRating,
    );

    // Update sports profiles list
    final updatedSportProfiles = [...currentProfile.sportsProfiles];
    updatedSportProfiles[existingSportIndex] = updatedSportProfile;

    // Handle primary sport logic
    if (updatedSportProfile.isPrimarySport) {
      for (int i = 0; i < updatedSportProfiles.length; i++) {
        if (i != existingSportIndex && updatedSportProfiles[i].isPrimarySport) {
          updatedSportProfiles[i] = SportProfile(
            sportId: updatedSportProfiles[i].sportId,
            sportName: updatedSportProfiles[i].sportName,
            skillLevel: updatedSportProfiles[i].skillLevel,
            yearsPlaying: updatedSportProfiles[i].yearsPlaying,
            preferredPositions: updatedSportProfiles[i].preferredPositions,
            certifications: updatedSportProfiles[i].certifications,
            achievements: updatedSportProfiles[i].achievements,
            isPrimarySport: false,
            lastPlayed: updatedSportProfiles[i].lastPlayed,
            gamesPlayed: updatedSportProfiles[i].gamesPlayed,
            averageRating: updatedSportProfiles[i].averageRating,
          );
        }
      }
    }

    final updatedProfile = UserProfile(
      id: currentProfile.id,
      userId: currentProfile.userId,
      email: currentProfile.email,
      displayName: currentProfile.displayName,
      avatarUrl: currentProfile.avatarUrl,
      createdAt: currentProfile.createdAt,
      updatedAt: DateTime.now(),
      bio: currentProfile.bio,
      age: currentProfile.age,
      city: currentProfile.city,
      country: currentProfile.country,
      phoneNumber: currentProfile.phoneNumber,
      username: currentProfile.username,
      gender: currentProfile.gender,
      profileType: currentProfile.profileType,
      intention: currentProfile.intention,
      verified: currentProfile.verified,
      isActive: currentProfile.isActive,
      geoLat: currentProfile.geoLat,
      geoLng: currentProfile.geoLng,
      sportsProfiles: updatedSportProfiles,
      statistics: currentProfile.statistics,
      privacySettings: currentProfile.privacySettings,
      preferences: currentProfile.preferences,
      settings: currentProfile.settings,
    );

    // Update profile in repository
    final updateResult = await _profileRepository.updateProfile(updatedProfile);
    if (updateResult.isLeft) {
      return Left(updateResult.leftOrNull()!);
    }

    final finalProfile = updateResult.rightOrNull()!;
    final changedFields = _calculateChangedFields(
      existingSport,
      updatedSportProfile,
    );
    final performanceMetrics = _calculatePerformanceMetrics(
      updatedSportProfile,
    );
    final warnings = _generateWarnings(updatedSportProfile, changedFields);

    return Right(
      ManageSportsProfileResult(
        updatedProfile: finalProfile,
        sportProfile: updatedSportProfile,
        warnings: warnings,
        changedFields: changedFields,
        performanceMetrics: performanceMetrics,
      ),
    );
  }

  /// Delete sport profile
  Future<Either<Failure, ManageSportsProfileResult>> _deleteSportProfile(
    ManageSportsProfileParams params,
    UserProfile currentProfile,
  ) async {
    if (params.sportId == null) {
      return const Left(
        ValidationFailure(message: 'Sport ID is required for deletion'),
      );
    }

    // Find existing sport profile
    final existingSportIndex = currentProfile.sportsProfiles.indexWhere(
      (sport) => sport.sportId == params.sportId,
    );

    if (existingSportIndex == -1) {
      return const Left(NotFoundFailure(message: 'Sport profile not found'));
    }

    final sportToDelete = currentProfile.sportsProfiles[existingSportIndex];

    // Remove from sports profiles list
    final updatedSportProfiles = [...currentProfile.sportsProfiles];
    updatedSportProfiles.removeAt(existingSportIndex);

    // If this was the primary sport, make another sport primary
    if (sportToDelete.isPrimarySport && updatedSportProfiles.isNotEmpty) {
      final newPrimaryIndex = updatedSportProfiles.indexWhere(
        (sport) => sport.isActive(),
      );
      if (newPrimaryIndex != -1) {
        updatedSportProfiles[newPrimaryIndex] = SportProfile(
          sportId: updatedSportProfiles[newPrimaryIndex].sportId,
          sportName: updatedSportProfiles[newPrimaryIndex].sportName,
          skillLevel: updatedSportProfiles[newPrimaryIndex].skillLevel,
          yearsPlaying: updatedSportProfiles[newPrimaryIndex].yearsPlaying,
          preferredPositions:
              updatedSportProfiles[newPrimaryIndex].preferredPositions,
          certifications: updatedSportProfiles[newPrimaryIndex].certifications,
          achievements: updatedSportProfiles[newPrimaryIndex].achievements,
          isPrimarySport: true,
          lastPlayed: updatedSportProfiles[newPrimaryIndex].lastPlayed,
          gamesPlayed: updatedSportProfiles[newPrimaryIndex].gamesPlayed,
          averageRating: updatedSportProfiles[newPrimaryIndex].averageRating,
        );
      }
    }

    final updatedProfile = UserProfile(
      id: currentProfile.id,
      userId: currentProfile.userId,
      email: currentProfile.email,
      displayName: currentProfile.displayName,
      avatarUrl: currentProfile.avatarUrl,
      createdAt: currentProfile.createdAt,
      updatedAt: DateTime.now(),
      bio: currentProfile.bio,
      age: currentProfile.age,
      city: currentProfile.city,
      country: currentProfile.country,
      phoneNumber: currentProfile.phoneNumber,
      username: currentProfile.username,
      gender: currentProfile.gender,
      profileType: currentProfile.profileType,
      intention: currentProfile.intention,
      verified: currentProfile.verified,
      isActive: currentProfile.isActive,
      geoLat: currentProfile.geoLat,
      geoLng: currentProfile.geoLng,
      sportsProfiles: updatedSportProfiles,
      statistics: currentProfile.statistics,
      privacySettings: currentProfile.privacySettings,
      preferences: currentProfile.preferences,
      settings: currentProfile.settings,
    );

    // Update profile in repository
    final updateResult = await _profileRepository.updateProfile(updatedProfile);
    if (updateResult.isLeft) {
      return Left(updateResult.leftOrNull()!);
    }

    final finalProfile = updateResult.rightOrNull()!;
    final warnings = ['Sport profile deleted successfully'];
    if (updatedSportProfiles.isEmpty) {
      warnings.add(
        'Consider adding at least one sport to improve your profile.',
      );
    }

    return Right(
      ManageSportsProfileResult(
        updatedProfile: finalProfile,
        sportProfile: null,
        warnings: warnings,
        changedFields: {
          'action': 'deleted',
          'sport_name': sportToDelete.sportName,
        },
        performanceMetrics: {},
      ),
    );
  }

  /// Validate input parameters
  Either<Failure, void> _validateParams(ManageSportsProfileParams params) {
    final errors = <String>[];

    // Validate skill level
    if (params.skillLevel != null) {
      const validSkillLevels = [
        'beginner',
        'intermediate',
        'advanced',
        'expert',
      ];
      if (!validSkillLevels.contains(params.skillLevel!.toLowerCase())) {
        errors.add('Invalid skill level');
      }
    }

    // Validate statistics
    if (params.gamesPlayed != null && params.gamesPlayed! < 0) {
      errors.add('Games played cannot be negative');
    }

    if (params.gamesWon != null && params.gamesWon! < 0) {
      errors.add('Games won cannot be negative');
    }

    if (params.gamesLost != null && params.gamesLost! < 0) {
      errors.add('Games lost cannot be negative');
    }

    if (params.yearsOfExperience != null && params.yearsOfExperience! < 0) {
      errors.add('Years of experience cannot be negative');
    }

    if (params.averageRating != null &&
        (params.averageRating! < 0 || params.averageRating! > 5)) {
      errors.add('Average rating must be between 0 and 5');
    }

    // Validate game statistics consistency
    if (params.gamesPlayed != null &&
        params.gamesWon != null &&
        params.gamesLost != null) {
      if (params.gamesWon! + params.gamesLost! > params.gamesPlayed!) {
        errors.add('Total wins and losses cannot exceed games played');
      }
    }

    if (errors.isNotEmpty) {
      return Left(ValidationFailure(message: errors.join(', ')));
    }

    return const Right(null);
  }

  /// Apply business rules
  ManageSportsProfileParams _applyBusinessRules(
    ManageSportsProfileParams params,
    SportProfile existingSport,
  ) {
    var processedParams = params;

    // Business Rule: Update games played if wins/losses change
    if (params.gamesWon != null || params.gamesLost != null) {
      final newWins =
          params.gamesWon ?? 0; // Note: gamesWon doesn't exist in SportProfile
      final newLosses =
          params.gamesLost ??
          0; // Note: gamesLost doesn't exist in SportProfile
      final newGamesPlayed = params.gamesPlayed ?? existingSport.gamesPlayed;

      if (newWins + newLosses > newGamesPlayed) {
        processedParams = ManageSportsProfileParams(
          userId: params.userId,
          sportId: params.sportId,
          sportName: params.sportName,
          skillLevel: params.skillLevel,
          yearsOfExperience: params.yearsOfExperience,
          gamesPlayed: newWins + newLosses,
          gamesWon: params.gamesWon,
          gamesLost: params.gamesLost,
          averageRating: params.averageRating,
          achievements: params.achievements,
          preferredPosition: params.preferredPosition,
          isPrimarySport: params.isPrimarySport,
          isActive: params.isActive,
          customStats: params.customStats,
          action: params.action,
        );
      }
    }

    return processedParams;
  }

  /// Calculate changed fields
  Map<String, dynamic> _calculateChangedFields(
    SportProfile current,
    SportProfile updated,
  ) {
    final changes = <String, dynamic>{};

    if (current.skillLevel != updated.skillLevel) {
      changes['skill_level'] = {
        'old': current.skillLevel,
        'new': updated.skillLevel,
      };
    }

    if (current.gamesPlayed != updated.gamesPlayed) {
      changes['games_played'] = {
        'old': current.gamesPlayed,
        'new': updated.gamesPlayed,
      };
    }

    if (current.isPrimarySport != updated.isPrimarySport) {
      changes['is_primary_sport'] = {
        'old': current.isPrimarySport,
        'new': updated.isPrimarySport,
      };
    }

    return changes;
  }

  /// Calculate performance metrics
  Map<String, double> _calculatePerformanceMetrics(SportProfile sportProfile) {
    final metrics = <String, double>{};

    // Win rate - note: SportProfile doesn't have gamesWon/gamesLost, so we'll use gamesPlayed
    if (sportProfile.gamesPlayed > 0) {
      // Since we don't have win/loss data, we'll use a default calculation
      metrics['win_rate'] = 50.0; // Default to 50% without actual data
      metrics['loss_rate'] = 50.0; // Default to 50% without actual data
    } else {
      metrics['win_rate'] = 0.0;
      metrics['loss_rate'] = 0.0;
    }

    // Experience factor
    metrics['experience_factor'] = (sportProfile.yearsPlaying * 10).toDouble();

    // Rating performance
    metrics['rating_performance'] = (sportProfile.averageRating * 20);

    // Overall performance score
    metrics['overall_score'] =
        ((metrics['win_rate']! * 0.4) +
                (metrics['experience_factor']! * 0.3) +
                (metrics['rating_performance']! * 0.3))
            .clamp(0.0, 100.0);

    return metrics;
  }

  /// Generate warnings
  List<String> _generateWarnings(
    SportProfile sportProfile,
    Map<String, dynamic> changedFields,
  ) {
    final warnings = <String>[];

    // Low game activity
    if (sportProfile.gamesPlayed < 5) {
      warnings.add('Play more games to improve your profile statistics.');
    }

    // Low win rate - note: SportProfile doesn't have gamesWon, so we'll skip this check
    // final winRate = sportProfile.gamesPlayed > 0 ?
    //     (sportProfile.gamesWon / sportProfile.gamesPlayed) : 0.0;
    // if (winRate < 0.3 && sportProfile.gamesPlayed > 10) {
    //   warnings.add('Consider practicing more or adjusting your skill level.');
    // }

    // No achievements
    if (sportProfile.achievements.isEmpty && sportProfile.gamesPlayed > 20) {
      warnings.add(
        'You may be eligible for achievements based on your game history.',
      );
    }

    return warnings;
  }

  /// Parse skill level from string
  SkillLevel _parseSkillLevel(String skillLevel) {
    switch (skillLevel.toLowerCase()) {
      case 'beginner':
        return SkillLevel.beginner;
      case 'intermediate':
        return SkillLevel.intermediate;
      case 'advanced':
        return SkillLevel.advanced;
      case 'expert':
        return SkillLevel.expert;
      default:
        return SkillLevel.beginner;
    }
  }
}
