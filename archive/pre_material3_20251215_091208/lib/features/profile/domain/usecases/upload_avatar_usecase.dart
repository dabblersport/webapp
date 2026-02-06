import 'dart:io';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import '../repositories/profile_repository.dart';

/// Parameters for avatar upload
class UploadAvatarParams {
  final String userId;
  final File imageFile;
  final bool deleteCurrentAvatar;

  const UploadAvatarParams({
    required this.userId,
    required this.imageFile,
    this.deleteCurrentAvatar = false,
  });
}

/// Result of avatar upload operation
class UploadAvatarResult {
  final UserProfile updatedProfile;
  final String avatarUrl;
  final List<String> warnings;
  final Map<String, dynamic> metadata;

  const UploadAvatarResult({
    required this.updatedProfile,
    required this.avatarUrl,
    required this.warnings,
    required this.metadata,
  });
}

/// Use case for uploading and managing user avatars with validation and optimization
class UploadAvatarUseCase {
  final ProfileRepository _profileRepository;

  UploadAvatarUseCase(this._profileRepository);

  Future<Either<Failure, UploadAvatarResult>> call(
    UploadAvatarParams params,
  ) async {
    try {
      // Validate input parameters
      final validationResult = await _validateParams(params);
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

      // Delete current avatar if requested
      if (params.deleteCurrentAvatar && currentProfile.avatarUrl != null) {
        final deleteResult = await _profileRepository.deleteAvatar(
          params.userId,
        );
        if (deleteResult.isLeft) {
          // Log warning but continue with upload
        }
      }

      // Upload new avatar with progress tracking
      String? newAvatarUrl;
      final uploadResult = await _profileRepository.uploadAvatar(
        params.userId,
        params.imageFile,
        onProgress: (progress) {
          // Progress callback can be used for UI updates
        },
      );

      if (uploadResult.isLeft) {
        return Left(uploadResult.leftOrNull()!);
      }

      newAvatarUrl = uploadResult.rightOrNull()!;

      // Get updated profile after avatar upload
      final updatedProfileResult = await _profileRepository.getProfile(
        params.userId,
      );
      if (updatedProfileResult.isLeft) {
        return Left(updatedProfileResult.leftOrNull()!);
      }

      final updatedProfile = updatedProfileResult.rightOrNull()!;

      // Generate metadata about the upload
      final metadata = await _generateMetadata(params.imageFile, newAvatarUrl);

      // Generate warnings
      final warnings = _generateWarnings(params.imageFile, metadata);

      return Right(
        UploadAvatarResult(
          updatedProfile: updatedProfile,
          avatarUrl: newAvatarUrl,
          warnings: warnings,
          metadata: metadata,
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Avatar upload failed: $e'));
    }
  }

  /// Validate input parameters
  Future<Either<Failure, void>> _validateParams(
    UploadAvatarParams params,
  ) async {
    final errors = <String>[];

    // Check if file exists
    if (!await params.imageFile.exists()) {
      errors.add('Image file does not exist');
      return Left(ValidationFailure(message: errors.join(', ')));
    }

    // Validate file size (max 10MB)
    final fileSizeBytes = await params.imageFile.length();
    const maxSizeBytes = 10 * 1024 * 1024; // 10MB
    if (fileSizeBytes > maxSizeBytes) {
      errors.add('Image file size cannot exceed 10MB');
    }

    // Validate file extension
    final fileName = params.imageFile.path.toLowerCase();
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final hasValidExtension = allowedExtensions.any(
      (ext) => fileName.endsWith(ext),
    );
    if (!hasValidExtension) {
      errors.add('Image must be in JPG, PNG, GIF, or WebP format');
    }

    // Basic image validation (check if it's actually an image)
    try {
      final bytes = await params.imageFile.readAsBytes();
      if (!_isValidImageBytes(bytes)) {
        errors.add('File does not appear to be a valid image');
      }
    } catch (e) {
      errors.add('Unable to read image file');
    }

    if (errors.isNotEmpty) {
      return Left(ValidationFailure(message: errors.join(', ')));
    }

    return const Right(null);
  }

  /// Generate metadata about the upload
  Future<Map<String, dynamic>> _generateMetadata(
    File imageFile,
    String avatarUrl,
  ) async {
    final metadata = <String, dynamic>{};

    try {
      // File information
      final fileSizeBytes = await imageFile.length();
      metadata['original_file_size'] = fileSizeBytes;
      metadata['original_file_name'] = imageFile.path.split('/').last;
      metadata['upload_timestamp'] = DateTime.now().toIso8601String();
      metadata['avatar_url'] = avatarUrl;

      // Image dimensions (basic estimation)
      final bytes = await imageFile.readAsBytes();
      final dimensions = _estimateImageDimensions(bytes);
      if (dimensions != null) {
        metadata['original_width'] = dimensions['width'];
        metadata['original_height'] = dimensions['height'];
        metadata['aspect_ratio'] =
            (dimensions['width']! / dimensions['height']!).toStringAsFixed(2);
      }

      // File format
      metadata['file_format'] = _detectImageFormat(bytes);

      // Quality assessment
      metadata['quality_score'] = _assessImageQuality(
        fileSizeBytes,
        dimensions,
      );
    } catch (e) {
      metadata['metadata_error'] = 'Failed to generate complete metadata: $e';
    }

    return metadata;
  }

  /// Generate warnings for the user
  List<String> _generateWarnings(
    File imageFile,
    Map<String, dynamic> metadata,
  ) {
    final warnings = <String>[];

    // File size warnings
    final fileSizeBytes = metadata['original_file_size'] as int? ?? 0;
    if (fileSizeBytes > 5 * 1024 * 1024) {
      // 5MB
      warnings.add('Large image file may take longer to load in the app.');
    }

    // Dimension warnings
    final width = metadata['original_width'] as int?;
    final height = metadata['original_height'] as int?;

    if (width != null && height != null) {
      if (width < 200 || height < 200) {
        warnings.add('Low resolution image may appear blurry when displayed.');
      }

      if (width > 2000 || height > 2000) {
        warnings.add(
          'High resolution image will be automatically resized for optimal performance.',
        );
      }

      // Aspect ratio warning
      final aspectRatio = width / height;
      if (aspectRatio < 0.8 || aspectRatio > 1.2) {
        warnings.add(
          'Non-square images will be cropped to fit profile picture format.',
        );
      }
    }

    // Quality warning
    final qualityScore = metadata['quality_score'] as double? ?? 0.0;
    if (qualityScore < 50) {
      warnings.add(
        'Image quality appears to be low and may not look good when displayed.',
      );
    }

    // Format warning
    final format = metadata['file_format'] as String?;
    if (format == 'gif') {
      warnings.add('Animated GIFs will be converted to static images.');
    }

    return warnings;
  }

  /// Check if bytes represent a valid image
  bool _isValidImageBytes(List<int> bytes) {
    if (bytes.length < 10) return false;

    // Check for common image file signatures
    // JPEG: FF D8 FF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }

    // GIF: 47 49 46 38 (GIF8)
    if (bytes.length >= 4 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }

    // WebP: 52 49 46 46 ... 57 45 42 50
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    return false;
  }

  /// Detect image format from bytes
  String _detectImageFormat(List<int> bytes) {
    if (bytes.length < 10) return 'unknown';

    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpeg';
    }

    // PNG
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }

    // GIF
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'gif';
    }

    // WebP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }

    return 'unknown';
  }

  /// Estimate image dimensions (basic implementation)
  Map<String, int>? _estimateImageDimensions(List<int> bytes) {
    try {
      // PNG dimensions
      if (bytes.length >= 24 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        final width =
            (bytes[16] << 24) |
            (bytes[17] << 16) |
            (bytes[18] << 8) |
            bytes[19];
        final height =
            (bytes[20] << 24) |
            (bytes[21] << 16) |
            (bytes[22] << 8) |
            bytes[23];
        return {'width': width, 'height': height};
      }

      // JPEG dimensions (basic SOF marker search)
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        for (int i = 2; i < bytes.length - 9; i++) {
          if (bytes[i] == 0xFF &&
              (bytes[i + 1] == 0xC0 || bytes[i + 1] == 0xC2)) {
            final height = (bytes[i + 5] << 8) | bytes[i + 6];
            final width = (bytes[i + 7] << 8) | bytes[i + 8];
            return {'width': width, 'height': height};
          }
        }
      }

      // GIF dimensions
      if (bytes.length >= 10 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38) {
        final width = bytes[6] | (bytes[7] << 8);
        final height = bytes[8] | (bytes[9] << 8);
        return {'width': width, 'height': height};
      }
    } catch (e) {
      // Return null if dimension detection fails
    }

    return null;
  }

  /// Assess image quality based on file size and dimensions
  double _assessImageQuality(int fileSizeBytes, Map<String, int>? dimensions) {
    double score = 50.0; // Base score

    // File size factor
    if (fileSizeBytes > 1024 * 1024) {
      // > 1MB
      score += 20.0;
    } else if (fileSizeBytes < 100 * 1024) {
      // < 100KB
      score -= 20.0;
    }

    // Dimension factor
    if (dimensions != null) {
      final width = dimensions['width']!;
      final height = dimensions['height']!;
      final pixels = width * height;

      if (pixels > 1000000) {
        // > 1MP
        score += 20.0;
      } else if (pixels < 40000) {
        // < 200x200
        score -= 30.0;
      }

      // Bytes per pixel ratio
      final bytesPerPixel = fileSizeBytes / pixels;
      if (bytesPerPixel > 2.0) {
        score += 10.0;
      } else if (bytesPerPixel < 0.5) {
        score -= 10.0;
      }
    }

    return score.clamp(0.0, 100.0);
  }
}
