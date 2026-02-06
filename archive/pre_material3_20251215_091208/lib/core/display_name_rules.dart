/// Display name helpers used by repositories and UI.
///
/// Normalization: lowercase, trim, collapse internal whitespace to single spaces.
class DisplayNameRules {
  static String normalize(String input) {
    final trimmed = input.trim();
    // Collapse any sequence of whitespace to a single space
    final collapsed = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.toLowerCase();
  }

  /// Local length validation per DB CHECK (2..50).
  static bool isLengthValid(String input) {
    final len = input.trim().length;
    return len >= 2 && len <= 50;
  }
}
