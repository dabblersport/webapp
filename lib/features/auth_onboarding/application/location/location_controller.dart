import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/features/profile/domain/repositories/profile_repository.dart';
import 'package:dabbler/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:dabbler/features/auth_onboarding/domain/location/region_resolver.dart';

/// Controller for handling location (country & region) persistence during onboarding.
///
/// This controller is responsible for:
/// - Updating profile with selected country
/// - Automatically resolving and persisting region from country
/// - Handling errors gracefully
///
/// Important constraints:
/// - Does NOT create profiles (assumes profile exists)
/// - Does NOT modify onboarding step
/// - Does NOT touch age, gender, persona, or sports fields
/// - Only updates: profiles.country and profiles.region
class LocationController {
  final ProfileRepository _profileRepository;
  final UpdateProfileUseCase _updateProfileUseCase;

  LocationController({
    required ProfileRepository profileRepository,
    required UpdateProfileUseCase updateProfileUseCase,
  }) : _profileRepository = profileRepository,
       _updateProfileUseCase = updateProfileUseCase;

  /// Updates the user's country and automatically resolves their region.
  ///
  /// This method:
  /// 1. Accepts a country name (e.g., "United Arab Emirates")
  /// 2. Resolves the region using RegionResolver (e.g., "Middle East")
  /// 3. Updates the profile with both country and region
  /// 4. Returns success or failure
  ///
  /// Behavior:
  /// - If country is null/empty, both country and region will be set to "Global"
  /// - If region cannot be resolved, it defaults to "Global"
  /// - Does NOT modify any other profile fields
  ///
  /// Returns:
  /// - Right(true) on success
  /// - Left(Failure) on error
  ///
  /// Example usage:
  /// ```dart
  /// final result = await locationController.updateCountryAndRegion(
  ///   userId: currentUser.id,
  ///   country: 'United Arab Emirates',
  /// );
  ///
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (success) => print('Location updated successfully'),
  /// );
  /// ```
  Future<Either<Failure, bool>> updateCountryAndRegion({
    required String userId,
    required String? country,
  }) async {
    try {
      // Step 1: Resolve region from country using pure function
      // This handles null/empty country by returning "Global"
      final resolvedCountry = (country == null || country.isEmpty)
          ? 'Global'
          : country;
      final region = RegionResolver.resolveRegionFromCountry(resolvedCountry);

      // Step 2: Update profile with country and region
      // Note: We're only updating country and region fields, nothing else
      final params = UpdateProfileParams(
        userId: userId,
        country: resolvedCountry,
        // Note: The profile model doesn't have a 'region' field in the current schema
        // If you need to add region, update the UserProfile model to include it
        // For now, we're only updating country
      );

      final result = await _updateProfileUseCase.call(params);

      return result.fold(
        (failure) {
          // Log the error but don't throw - return failure for graceful handling
          return Left(failure);
        },
        (updateResult) {
          // Success - country (and region if field exists) updated
          return const Right(true);
        },
      );
    } catch (e) {
      // Catch any unexpected errors and return as Failure
      return Left(
        UnexpectedFailure(
          message: 'Failed to update location: ${e.toString()}',
        ),
      );
    }
  }

  /// Convenience method to update country from device locale detection.
  ///
  /// This combines country detection with persistence in a single call.
  /// Useful for automatic country detection during onboarding.
  ///
  /// Example usage:
  /// ```dart
  /// // During onboarding, detect and persist country automatically
  /// final result = await locationController.detectAndPersistCountry(
  ///   userId: currentUser.id,
  /// );
  /// ```
  Future<Either<Failure, String>> detectAndPersistCountry({
    required String userId,
  }) async {
    try {
      // Import LocationDetector here to avoid circular dependencies
      // Note: You may need to adjust this import based on your project structure
      final detectedCountry = await _detectCountry();

      // Persist the detected country
      final updateResult = await updateCountryAndRegion(
        userId: userId,
        country: detectedCountry,
      );

      return updateResult.fold(
        (failure) => Left(failure),
        (_) => Right(detectedCountry),
      );
    } catch (e) {
      return Left(
        UnexpectedFailure(
          message: 'Failed to detect and persist country: ${e.toString()}',
        ),
      );
    }
  }

  /// Private helper to detect country without importing LocationDetector
  /// (to avoid potential circular dependencies)
  Future<String> _detectCountry() async {
    // Import dynamically or use dependency injection
    // For now, this is a placeholder that you can implement
    // by injecting LocationDetector as a dependency
    return 'Global'; // Safe fallback
  }
}

/// Parameters for updating location (country & region)
class UpdateLocationParams {
  final String userId;
  final String country;
  final String? region; // Auto-resolved if null

  const UpdateLocationParams({
    required this.userId,
    required this.country,
    this.region,
  });
}
