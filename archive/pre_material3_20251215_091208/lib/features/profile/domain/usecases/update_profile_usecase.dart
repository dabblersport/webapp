import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import '../repositories/profile_repository.dart';

/// Parameters for updating profile
class UpdateProfileParams {
  final String userId;
  final String? username;
  final String? displayName;
  final String? bio;
  final String? email;
  final String? phoneNumber;
  final String? city;
  final String? country;
  final String? gender;
  final int? age;

  const UpdateProfileParams({
    required this.userId,
    this.username,
    this.displayName,
    this.bio,
    this.email,
    this.phoneNumber,
    this.city,
    this.country,
    this.gender,
    this.age,
  });

  bool get hasUpdates =>
      username != null ||
      displayName != null ||
      bio != null ||
      email != null ||
      phoneNumber != null ||
      city != null ||
      country != null ||
      gender != null ||
      age != null;
}

/// Result of profile update operation
class UpdateProfileResult {
  final UserProfile updatedProfile;
  final List<String> warnings;
  final Map<String, dynamic> changedFields;
  final double completionPercentage;

  const UpdateProfileResult({
    required this.updatedProfile,
    required this.warnings,
    required this.changedFields,
    required this.completionPercentage,
  });
}

/// Use case for updating user profile with comprehensive validation and business logic
class UpdateProfileUseCase {
  final ProfileRepository _profileRepository;

  UpdateProfileUseCase(this._profileRepository);

  Future<Either<Failure, UpdateProfileResult>> call(
    UpdateProfileParams params,
  ) async {
    try {
      // Validate input parameters
      final validationResult = _validateParams(params);
      if (validationResult.isLeft) {
        return Left(validationResult.leftOrNull()!);
      }

      // Get current profile for comparison
      final currentProfileResult = await _profileRepository.getProfile(
        params.userId,
      );
      if (currentProfileResult.isLeft) {
        return Left(currentProfileResult.leftOrNull()!);
      }

      final currentProfile = currentProfileResult.rightOrNull()!;

      // Sanitize input data
      final sanitizedParams = _sanitizeParams(params);

      // Apply business rules and constraints
      final processedParams = _applyBusinessRules(
        sanitizedParams,
        currentProfile,
      );
      if (processedParams.isLeft) {
        return Left(processedParams.leftOrNull()!);
      }

      final finalParams = processedParams.rightOrNull()!;

      // Create updated profile with new values
      final updatedProfile = UserProfile(
        id: currentProfile.id,
        userId: currentProfile.userId,
        username: finalParams.username ?? currentProfile.username,
        displayName: finalParams.displayName ?? currentProfile.displayName,
        email: finalParams.email ?? currentProfile.email,
        avatarUrl: currentProfile.avatarUrl,
        createdAt: currentProfile.createdAt,
        updatedAt: DateTime.now(),
        bio: finalParams.bio ?? currentProfile.bio,
        age: finalParams.age ?? currentProfile.age,
        city: finalParams.city ?? currentProfile.city,
        country: finalParams.country ?? currentProfile.country,
        phoneNumber: finalParams.phoneNumber ?? currentProfile.phoneNumber,
        gender: finalParams.gender ?? currentProfile.gender,
        profileType: currentProfile.profileType,
        intention: currentProfile.intention,
        preferredSport: currentProfile.preferredSport,
        interests: currentProfile.interests,
        language: currentProfile.language,
        verified: currentProfile.verified,
        isActive: currentProfile.isActive,
        geoLat: currentProfile.geoLat,
        geoLng: currentProfile.geoLng,
        sportsProfiles: currentProfile.sportsProfiles,
        statistics: currentProfile.statistics,
        privacySettings: currentProfile.privacySettings,
        preferences: currentProfile.preferences,
        settings: currentProfile.settings,
      );

      // Perform the update
      final updateResult = await _profileRepository.updateProfile(
        updatedProfile,
      );
      if (updateResult.isLeft) {
        return Left(updateResult.leftOrNull()!);
      }

      final finalUpdatedProfile = updateResult.rightOrNull()!;

      // Calculate changed fields
      final changedFields = _calculateChangedFields(
        currentProfile,
        finalUpdatedProfile,
      );

      // Calculate completion percentage
      final completionPercentage = _calculateCompletionPercentage(
        finalUpdatedProfile,
      );

      // Generate warnings
      final warnings = _generateWarnings(finalUpdatedProfile, changedFields);

      return Right(
        UpdateProfileResult(
          updatedProfile: finalUpdatedProfile,
          warnings: warnings,
          changedFields: changedFields,
          completionPercentage: completionPercentage,
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Profile update failed: $e'));
    }
  }

  /// Validate input parameters
  Either<Failure, void> _validateParams(UpdateProfileParams params) {
    final errors = <String>[];

    // Validate display name
    if (params.displayName != null) {
      if (params.displayName!.trim().isEmpty) {
        errors.add('Display name cannot be empty');
      } else if (params.displayName!.length < 2) {
        errors.add('Display name must be at least 2 characters');
      } else if (params.displayName!.length > 50) {
        errors.add('Display name cannot exceed 50 characters');
      } else if (!_isValidDisplayName(params.displayName!)) {
        errors.add('Display name contains invalid characters');
      }
    }

    // Validate email
    if (params.email != null && params.email!.isNotEmpty) {
      if (!_isValidEmail(params.email!)) {
        errors.add('Invalid email format');
      }
    }

    // Validate phone number
    if (params.phoneNumber != null && params.phoneNumber!.isNotEmpty) {
      if (!_isValidPhoneNumber(params.phoneNumber!)) {
        errors.add('Invalid phone number format');
      }
    }

    // Validate bio
    if (params.bio != null && params.bio!.length > 500) {
      errors.add('Bio cannot exceed 500 characters');
    }

    // Validate location
    if (params.city != null && params.city!.length > 100) {
      errors.add('Location cannot exceed 100 characters');
    }

    // Validate first name
    if (params.username != null && params.username!.length > 50) {
      errors.add('First name cannot exceed 50 characters');
    }

    // Validate last name
    if (params.displayName != null && params.displayName!.length > 50) {
      errors.add('Last name cannot exceed 50 characters');
    }

    // Validate gender
    if (params.gender != null && params.gender!.isNotEmpty) {
      const validGenders = [
        'male',
        'female',
        'non-binary',
        'prefer_not_to_say',
        'other',
      ];
      if (!validGenders.contains(params.gender!.toLowerCase())) {
        errors.add('Invalid gender value');
      }
    }

    // Validate age
    if (params.age != null) {
      if (params.age! < 13) {
        errors.add('Minimum age requirement is 13 years');
      }
      if (params.age! > 120) {
        errors.add('Please enter a valid age');
      }
    }

    if (errors.isNotEmpty) {
      return Left(ValidationFailure(message: errors.join(', ')));
    }

    return const Right(null);
  }

  /// Sanitize input parameters
  UpdateProfileParams _sanitizeParams(UpdateProfileParams params) {
    return UpdateProfileParams(
      userId: params.userId,
      displayName: params.displayName?.trim(),
      bio: params.bio?.trim(),
      email: params.email?.trim().toLowerCase(),
      phoneNumber: params.phoneNumber?.trim(),
      city: params.city?.trim(),
      country: params.country?.trim(),
      username: params.username?.trim(),
      gender: params.gender?.trim().toLowerCase(),
      age: params.age,
    );
  }

  /// Apply business rules and constraints
  Either<Failure, UpdateProfileParams> _applyBusinessRules(
    UpdateProfileParams params,
    UserProfile currentProfile,
  ) {
    var processedParams = params;

    // Business Rule: Display name profanity filter
    if (params.displayName != null) {
      final cleanDisplayName = _filterProfanity(params.displayName!);
      if (cleanDisplayName != params.displayName) {
        processedParams = UpdateProfileParams(
          userId: params.userId,
          displayName: cleanDisplayName,
          bio: params.bio,
          email: params.email,
          phoneNumber: params.phoneNumber,
          city: params.city,
          country: params.country,
          username: params.username,
          gender: params.gender,
          age: params.age,
        );
      }
    }

    // Business Rule: Bio profanity filter
    if (params.bio != null) {
      final cleanBio = _filterProfanity(params.bio!);
      if (cleanBio != params.bio) {
        processedParams = UpdateProfileParams(
          userId: processedParams.userId,
          displayName: processedParams.displayName,
          bio: cleanBio,
          email: processedParams.email,
          phoneNumber: processedParams.phoneNumber,
          city: processedParams.city,
          country: processedParams.country,
          username: processedParams.username,
          gender: processedParams.gender,
          age: processedParams.age,
        );
      }
    }

    return Right(processedParams);
  }

  /// Calculate which fields have changed
  Map<String, dynamic> _calculateChangedFields(
    UserProfile current,
    UserProfile updated,
  ) {
    final changes = <String, dynamic>{};

    if (current.displayName != updated.displayName) {
      changes['display_name'] = {
        'old': current.displayName,
        'new': updated.displayName,
      };
    }

    if (current.bio != updated.bio) {
      changes['bio'] = {'old': current.bio, 'new': updated.bio};
    }

    if (current.email != updated.email) {
      changes['email'] = {'old': current.email, 'new': updated.email};
    }

    if (current.phoneNumber != updated.phoneNumber) {
      changes['phone_number'] = {
        'old': current.phoneNumber,
        'new': updated.phoneNumber,
      };
    }

    if (current.city != updated.city) {
      changes['location'] = {'old': current.city, 'new': updated.city};
    }

    if (current.username != updated.username) {
      changes['first_name'] = {
        'old': current.username,
        'new': updated.username,
      };
    }

    if (current.displayName != updated.displayName) {
      changes['last_name'] = {
        'old': current.displayName,
        'new': updated.displayName,
      };
    }

    if (current.gender != updated.gender) {
      changes['gender'] = {'old': current.gender, 'new': updated.gender};
    }

    if (current.age != updated.age) {
      changes['date_of_birth'] = {'old': current.age, 'new': updated.age};
    }

    return changes;
  }

  /// Calculate profile completion percentage
  double _calculateCompletionPercentage(UserProfile profile) {
    final requiredFields = [
      profile.displayName.isNotEmpty,
      profile.email?.isNotEmpty ?? false,
      profile.bio?.isNotEmpty == true,
      profile.city?.isNotEmpty == true,
      profile.age != null,
      profile.avatarUrl?.isNotEmpty == true,
      profile.username?.isNotEmpty == true,
      profile.displayName.isNotEmpty == true,
    ];

    final optionalFields = [
      profile.phoneNumber?.isNotEmpty == true,
      profile.gender?.isNotEmpty == true,
      profile.sportsProfiles.isNotEmpty,
    ];

    final completedRequired = requiredFields.where((field) => field).length;
    final completedOptional = optionalFields.where((field) => field).length;

    // Weight required fields more heavily
    final totalPossible =
        (requiredFields.length * 0.8) + (optionalFields.length * 0.2);
    final totalCompleted =
        (completedRequired * 0.8) + (completedOptional * 0.2);

    return (totalCompleted / totalPossible * 100).clamp(0.0, 100.0);
  }

  /// Generate warnings for the user
  List<String> _generateWarnings(
    UserProfile profile,
    Map<String, dynamic> changedFields,
  ) {
    final warnings = <String>[];

    // Warning: Profile completion
    final completion = _calculateCompletionPercentage(profile);
    if (completion < 80) {
      warnings.add(
        'Profile is ${completion.toStringAsFixed(0)}% complete. Consider adding more information.',
      );
    }

    // Warning: Missing avatar
    if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
      warnings.add(
        'Consider adding a profile photo to help others recognize you.',
      );
    }

    // Warning: Short bio
    if (profile.bio != null && profile.bio!.length < 50) {
      warnings.add(
        'A longer bio helps others understand your interests better.',
      );
    }

    // Warning: No location
    if (profile.city == null || profile.city!.isEmpty) {
      warnings.add('Adding your location helps find nearby games and players.');
    }

    // Warning: Privacy implications
    if (changedFields.containsKey('email')) {
      warnings.add('Email changes may affect your login and notifications.');
    }

    return warnings;
  }

  // Validation helper methods
  bool _isValidDisplayName(String name) {
    // Allow letters, numbers, spaces, and common punctuation
    return RegExp(r'^[a-zA-Z0-9\s\-_.]+$').hasMatch(name);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhoneNumber(String phone) {
    // Basic phone number validation (international format)
    return RegExp(
      r'^\+?[1-9]\d{1,14}$',
    ).hasMatch(phone.replaceAll(RegExp(r'[\s\-()]'), ''));
  }

  String _filterProfanity(String text) {
    // Simple profanity filter - in production, use a proper service
    const profanityWords = [
      'spam',
      'scam',
      'fake',
    ]; // Add actual profanity list
    var cleanText = text;

    for (final word in profanityWords) {
      cleanText = cleanText.replaceAll(
        RegExp(word, caseSensitive: false),
        '*' * word.length,
      );
    }

    return cleanText;
  }
}
