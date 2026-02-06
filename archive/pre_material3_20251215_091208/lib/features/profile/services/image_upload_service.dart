import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for handling image uploads with compression and processing
class ImageUploadService {
  final SupabaseClient _supabase;

  ImageUploadService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Upload profile image with compression and multiple sizes
  Future<ImageUploadResult> uploadProfileImage({
    required String userId,
    required String imagePath,
    Function(double)? onProgress,
  }) async {
    try {
      // Validate image file
      final file = File(imagePath);
      if (!await file.exists()) {
        throw ValidationException('Image file not found');
      }

      // Validate file size (max 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw ValidationException('Image file too large. Maximum size is 10MB');
      }

      // Validate image format
      final extension = path.extension(imagePath).toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
        throw ValidationException(
          'Unsupported image format. Use JPG, PNG, or WebP',
        );
      }

      onProgress?.call(0.1);

      // Read and process image
      final imageBytes = await file.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw ValidationException('Invalid image file');
      }

      onProgress?.call(0.3);

      // Generate different sizes
      final sizes = await _generateImageSizes(originalImage, userId);
      onProgress?.call(0.7);

      // Upload all sizes
      final uploadResults = <String, String>{};
      for (final sizeEntry in sizes.entries) {
        final sizeKey = sizeEntry.key;
        final imageData = sizeEntry.value;

        final fileName =
            '${userId}_${sizeKey}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = 'profiles/$fileName';

        // Upload to storage
        await _supabase.storage
            .from('avatars')
            .uploadBinary(
              filePath,
              imageData,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        // Get public URL
        final publicUrl = _supabase.storage
            .from('avatars')
            .getPublicUrl(filePath);

        uploadResults[sizeKey] = publicUrl;
      }

      onProgress?.call(1.0);

      // Clean up old images for this user
      await _cleanupOldImages(userId);

      final result = ImageUploadResult(
        url: uploadResults['large']!,
        thumbnailUrl: uploadResults['thumbnail'],
        mediumUrl: uploadResults['medium'],
        metadata: {
          'original_size': fileSize,
          'format': 'jpeg',
          'sizes': uploadResults,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );

      Logger.info('Profile image uploaded successfully for user $userId');
      return result;
    } catch (e) {
      Logger.error('Error uploading profile image for user $userId', e);
      rethrow;
    }
  }

  /// Generate multiple image sizes
  Future<Map<String, Uint8List>> _generateImageSizes(
    img.Image originalImage,
    String userId,
  ) async {
    final sizes = <String, Uint8List>{};

    // Define target sizes
    final sizeConfigs = {
      'thumbnail': 80,
      'small': 150,
      'medium': 300,
      'large': 500,
    };

    for (final config in sizeConfigs.entries) {
      final sizeKey = config.key;
      final targetSize = config.value;

      // Resize image maintaining aspect ratio
      img.Image resized;
      if (originalImage.width > originalImage.height) {
        resized = img.copyResize(originalImage, width: targetSize);
      } else {
        resized = img.copyResize(originalImage, height: targetSize);
      }

      // Crop to square if needed for thumbnails
      if (sizeKey == 'thumbnail') {
        final size = resized.width < resized.height
            ? resized.width
            : resized.height;
        resized = img.copyCrop(
          resized,
          x: (resized.width - size) ~/ 2,
          y: (resized.height - size) ~/ 2,
          width: size,
          height: size,
        );
      }

      // Convert to JPEG with quality based on size
      final quality = sizeKey == 'thumbnail' ? 70 : 85;
      final jpegBytes = img.encodeJpg(resized, quality: quality);
      sizes[sizeKey] = Uint8List.fromList(jpegBytes);
    }

    return sizes;
  }

  /// Clean up old images for a user
  Future<void> _cleanupOldImages(String userId) async {
    try {
      // List all files in user's profile folder
      final files = await _supabase.storage
          .from('avatars')
          .list(path: 'profiles');

      // Find files belonging to this user (older than current upload)
      final userFiles = files
          .where((file) => file.name.startsWith('${userId}_'))
          .toList();

      // Sort by creation time (newest first)
      userFiles.sort((a, b) {
        final aTime = a.createdAt is DateTime
            ? a.createdAt as DateTime
            : DateTime.now();
        final bTime = b.createdAt is DateTime
            ? b.createdAt as DateTime
            : DateTime.now();
        return bTime.compareTo(aTime);
      });

      // Keep only the most recent set (4 sizes), delete the rest
      if (userFiles.length > 4) {
        final filesToDelete = userFiles
            .skip(4)
            .map((file) => 'profiles/${file.name}')
            .toList();

        if (filesToDelete.isNotEmpty) {
          await _supabase.storage.from('avatars').remove(filesToDelete);
          Logger.info(
            'Cleaned up ${filesToDelete.length} old images for user $userId',
          );
        }
      }
    } catch (e) {
      Logger.warning('Error cleaning up old images for user $userId', e);
      // Don't fail the upload if cleanup fails
    }
  }

  /// Retry failed upload
  Future<ImageUploadResult> retryUpload({
    required String userId,
    required String imagePath,
    int maxRetries = 3,
    Function(double)? onProgress,
  }) async {
    var attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      try {
        attempt++;
        Logger.info('Upload attempt $attempt/$maxRetries for user $userId');

        return await uploadProfileImage(
          userId: userId,
          imagePath: imagePath,
          onProgress: onProgress,
        );
      } catch (e) {
        lastError = e as Exception;
        Logger.warning('Upload attempt $attempt failed for user $userId', e);

        if (attempt < maxRetries) {
          // Wait before retrying (exponential backoff)
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    throw lastError ?? Exception('Upload failed after $maxRetries attempts');
  }

  /// Validate image file before upload
  Future<ImageValidationResult> validateImage(String imagePath) async {
    try {
      final file = File(imagePath);

      if (!await file.exists()) {
        return ImageValidationResult(
          isValid: false,
          errors: ['File does not exist'],
        );
      }

      final errors = <String>[];
      final fileSize = await file.length();

      // Check file size
      if (fileSize > 10 * 1024 * 1024) {
        errors.add('File too large (max 10MB)');
      }

      if (fileSize < 1024) {
        errors.add('File too small (min 1KB)');
      }

      // Check file extension
      final extension = path.extension(imagePath).toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
        errors.add('Unsupported format (use JPG, PNG, or WebP)');
      }

      // Try to decode image
      try {
        final imageBytes = await file.readAsBytes();
        final image = img.decodeImage(imageBytes);

        if (image == null) {
          errors.add('Invalid or corrupted image file');
        } else {
          // Check dimensions
          if (image.width < 50 || image.height < 50) {
            errors.add('Image too small (minimum 50x50 pixels)');
          }

          if (image.width > 4000 || image.height > 4000) {
            errors.add('Image too large (maximum 4000x4000 pixels)');
          }
        }
      } catch (e) {
        errors.add('Unable to process image file');
      }

      return ImageValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        fileSize: fileSize,
        extension: extension,
      );
    } catch (e) {
      return ImageValidationResult(
        isValid: false,
        errors: ['Error validating image: ${e.toString()}'],
      );
    }
  }

  /// Delete user's profile images
  Future<void> deleteUserImages(String userId) async {
    try {
      final files = await _supabase.storage
          .from('avatars')
          .list(path: 'profiles');
      final userFiles = files
          .where((file) => file.name.startsWith('${userId}_'))
          .map((file) => 'profiles/${file.name}')
          .toList();

      if (userFiles.isNotEmpty) {
        await _supabase.storage.from('avatars').remove(userFiles);
        Logger.info('Deleted ${userFiles.length} images for user $userId');
      }
    } catch (e) {
      Logger.error('Error deleting images for user $userId', e);
      rethrow;
    }
  }
}

/// Result of image upload operation
class ImageUploadResult {
  final String url;
  final String? thumbnailUrl;
  final String? mediumUrl;
  final Map<String, dynamic> metadata;

  ImageUploadResult({
    required this.url,
    this.thumbnailUrl,
    this.mediumUrl,
    required this.metadata,
  });
}

/// Result of image validation
class ImageValidationResult {
  final bool isValid;
  final List<String> errors;
  final int? fileSize;
  final String? extension;

  ImageValidationResult({
    required this.isValid,
    required this.errors,
    this.fileSize,
    this.extension,
  });
}

/// Create some basic classes for dependencies that don't exist yet
class Logger {
  static void info(String message, [dynamic error]) {
    if (kDebugMode) {}
  }

  static void error(String message, [dynamic error]) {
    if (kDebugMode) {}
  }

  static void warning(String message, [dynamic error]) {
    if (kDebugMode) {}
  }
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Provider for image upload service
final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService();
});
