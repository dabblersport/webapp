/// DEPRECATED: This file is obsolete.
/// Use SocialRepository.uploadPostMedia instead.
///
/// MediaService was an intermediate refactor step that has been superseded
/// by SocialRepository, which provides unified social operations including
/// media uploads, post creation, and feed management.
@Deprecated('Use SocialRepository from lib/data/social/social_repository.dart')
library;

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DEPRECATED: Use SocialRepository.uploadPostMedia instead.
@Deprecated('Use SocialRepository.uploadPostMedia')
class MediaService {
  MediaService({SupabaseClient? client});

  /// DEPRECATED: Use SocialRepository.uploadPostMedia instead.
  @Deprecated('Use SocialRepository.uploadPostMedia')
  Future<Map<String, dynamic>> uploadPostMedia(XFile file) async {
    throw UnimplementedError(
      'MediaService is deprecated. '
      'Use SocialRepository.uploadPostMedia instead.',
    );
  }
}
