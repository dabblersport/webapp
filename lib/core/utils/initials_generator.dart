/// Utility for generating user initials from display names
/// Provides consistent 2-character initial extraction across the app
library;

class InitialsGenerator {
  InitialsGenerator._();

  /// Generates 2-character initials from a display name
  ///
  /// Rules:
  /// - Null or empty → 'U'
  /// - Single word → First two characters uppercase (e.g., 'Moataz' → 'MO')
  /// - Multiple words → First character of first and last word, uppercase
  /// - Whitespace trimmed and filtered
  ///
  /// Examples:
  /// - 'John Doe' → 'JD'
  /// - 'Moataz' → 'MO'
  /// - 'Mary Jane Watson' → 'MW'
  /// - 'J' → 'J'
  /// - '  ' → 'U'
  /// - null → 'U'
  static String generate(String? displayName) {
    // Handle null or empty
    if (displayName == null || displayName.trim().isEmpty) {
      return 'U';
    }

    // Split by whitespace and filter empty parts
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    // No valid parts after filtering
    if (parts.isEmpty) {
      return 'U';
    }

    // Single word - return first two characters
    if (parts.length == 1) {
      final word = parts[0];
      return word.substring(0, word.length.clamp(0, 2)).toUpperCase();
    }

    // Multiple words - first char of first word + first char of last word
    final firstInitial = parts.first[0];
    final lastInitial = parts.last[0];

    return '$firstInitial$lastInitial'.toUpperCase();
  }

  /// Validates if a string is a valid initial (1-2 uppercase letters)
  static bool isValidInitial(String? initials) {
    if (initials == null || initials.isEmpty) return false;
    final pattern = RegExp(r'^[A-Z]{1,2}$');
    return pattern.hasMatch(initials);
  }
}
