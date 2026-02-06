import 'package:dabbler/core/utils/validators.dart';

/// Enum to represent identifier type
enum IdentifierType { email, phone }

/// Result of identifier detection
class IdentifierDetectionResult {
  final IdentifierType type;
  final String normalizedValue;

  IdentifierDetectionResult({
    required this.type,
    required this.normalizedValue,
  });
}

/// Utility class to detect and normalize email vs phone identifiers
class IdentifierDetector {
  /// Detects if the input is an email or phone number
  /// Returns IdentifierDetectionResult with type and normalized value
  static IdentifierDetectionResult detect(String input) {
    final trimmed = input.trim();

    // Check if it's an email (contains @ and matches email regex)
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (emailRegex.hasMatch(trimmed)) {
      // Normalize email: lowercase, remove invisible chars
      final normalized = _normalizeEmail(trimmed);
      return IdentifierDetectionResult(
        type: IdentifierType.email,
        normalizedValue: normalized,
      );
    }

    // Otherwise, treat as phone number
    // Normalize phone: remove all non-digit characters except +
    final normalized = _normalizePhone(trimmed);
    return IdentifierDetectionResult(
      type: IdentifierType.phone,
      normalizedValue: normalized,
    );
  }

  /// Normalize email address
  static String _normalizeEmail(String email) {
    // Remove zero-width and BOM chars, collapse/strip whitespace, and lowercase
    final noInvisible = email.replaceAll(RegExp(r"[\u200B-\u200D\uFEFF]"), "");
    final noSpaces = noInvisible.replaceAll(RegExp(r"\s+"), "");
    return noSpaces.trim().toLowerCase();
  }

  /// Normalize phone number
  static String _normalizePhone(String phone) {
    // Remove all non-digit characters except +
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Ensure it starts with + if it doesn't already
    if (!cleaned.startsWith('+')) {
      // If it starts with 0, remove it and add default country code
      if (cleaned.startsWith('0')) {
        return '+971${cleaned.substring(1)}'; // Default to UAE
      }
      // Otherwise, assume it's missing country code - add default
      return '+971$cleaned'; // Default to UAE
    }

    return cleaned;
  }

  /// Validate identifier based on its detected type
  static String? validate(String input) {
    final result = detect(input);

    switch (result.type) {
      case IdentifierType.email:
        return AppValidators.validateEmail(result.normalizedValue);
      case IdentifierType.phone:
        return AppValidators.validatePhoneNumber(result.normalizedValue);
    }
  }
}
