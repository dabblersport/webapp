// Social post validation utilities
import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import '../../constants/social_constants.dart';
import 'text_content_validator.dart';

/// Validator for social posts
class SocialPostValidator {
  static final TextContentValidator _textValidator = TextContentValidator();

  /// Validates a complete post before submission
  static TextValidationResult validatePost(
    PostModel post,
    UserProfile? author,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate content length
    final contentResult = _textValidator.validateLength(
      post.content,
      1,
      SocialConstants.maxPostLength,
    );

    if (!contentResult.isValid) {
      errors.addAll(contentResult.errors);
    }

    // Validate media count
    if (post.mediaUrls.length > SocialConstants.maxPostMediaCount) {
      errors.add(
        'Too many media files (max ${SocialConstants.maxPostMediaCount})',
      );
    }

    // Additional validations can be added here

    return TextValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Quick validation for real-time feedback
  static TextValidationResult quickValidate(String content) {
    return _textValidator.quickValidate(content, SocialConstants.maxPostLength);
  }
}
