/// Lightweight client-side language detection for post body text.
///
/// Uses Unicode script ranges to identify the dominant script, then
/// maps it to an ISO 639-1 language code. This is a best-effort
/// heuristic — no external packages required.
library;

/// Detect the most likely ISO 639-1 language code from [text].
///
/// Returns `'en'` as the default fallback when no strong signal is found.
String detectLanguage(String text) {
  if (text.trim().isEmpty) return 'en';

  int arabic = 0;
  int latin = 0;
  int cjk = 0;
  int devanagari = 0;
  int cyrillic = 0;
  int hangul = 0;
  int thai = 0;
  int total = 0;

  for (final codeUnit in text.runes) {
    if (_isWhitespace(codeUnit) || _isPunctuation(codeUnit)) continue;
    total++;
    if (_isArabic(codeUnit)) {
      arabic++;
    } else if (_isLatin(codeUnit)) {
      latin++;
    } else if (_isCJK(codeUnit)) {
      cjk++;
    } else if (_isDevanagari(codeUnit)) {
      devanagari++;
    } else if (_isCyrillic(codeUnit)) {
      cyrillic++;
    } else if (_isHangul(codeUnit)) {
      hangul++;
    } else if (_isThai(codeUnit)) {
      thai++;
    }
  }

  if (total == 0) return 'en';

  // Determine dominant script (>= 40% of total letters).
  final threshold = total * 0.4;

  if (arabic >= threshold) return 'ar';
  if (cyrillic >= threshold) return 'ru';
  if (devanagari >= threshold) return 'hi';
  if (hangul >= threshold) return 'ko';
  if (thai >= threshold) return 'th';
  if (cjk >= threshold) {
    // Heuristic: if text contains hiragana/katakana → Japanese, else Chinese.
    for (final r in text.runes) {
      if ((r >= 0x3040 && r <= 0x309F) || (r >= 0x30A0 && r <= 0x30FF)) {
        return 'ja';
      }
    }
    return 'zh';
  }

  // Latin-script heuristics based on common diacritical/character patterns.
  if (latin >= threshold) {
    final lower = text.toLowerCase();
    // Spanish indicators
    if (RegExp(
      r'[ñ¿¡]|(?:\bel\b|\blos\b|\bque\b|\bdel\b|\bpara\b)',
    ).hasMatch(lower)) {
      return 'es';
    }
    // French indicators
    if (RegExp(
      r'[çœæ]|(?:\bles\b|\bdes\b|\bune?\b|\best\b|\bpas\b)',
    ).hasMatch(lower)) {
      return 'fr';
    }
    // German indicators
    if (RegExp(
      r'[äöüß]|(?:\bund\b|\bder\b|\bdie\b|\bdas\b|\bist\b)',
    ).hasMatch(lower)) {
      return 'de';
    }
    // Portuguese indicators
    if (RegExp(
      r'[ãõç]|(?:\buma?\b|\bnão\b|\bcom\b|\bpara\b)',
    ).hasMatch(lower)) {
      return 'pt';
    }
    // Turkish indicators
    if (RegExp(
      r'[ğışçöü]|(?:\bbir\b|\bve\b|\biçin\b|\bbu\b)',
    ).hasMatch(lower)) {
      return 'tr';
    }
    return 'en';
  }

  return 'en';
}

/// Extract hashtags from the body text.
///
/// Matches `#tag` patterns and returns the tag strings without the `#`.
List<String> extractHashtags(String text) {
  final regex = RegExp(r'#(\w+)', unicode: true);
  return regex.allMatches(text).map((m) => m.group(1)!).toSet().toList();
}

/// Returns true when [text] contains at least one word token that is not a
/// hashtag token.
///
/// This mirrors DB constraint `posts_body_has_non_hashtag_word` so the app can
/// validate before insert and provide a friendly error message.
bool hasNonHashtagWord(String text) {
  final tokens = text.trim().split(RegExp(r'\s+'));

  bool containsWordRune(String token) {
    for (final c in token.runes) {
      final isDigit = c >= 0x30 && c <= 0x39;
      if (isDigit ||
          _isArabic(c) ||
          _isLatin(c) ||
          _isCJK(c) ||
          _isDevanagari(c) ||
          _isCyrillic(c) ||
          _isHangul(c) ||
          _isThai(c)) {
        return true;
      }
    }
    return false;
  }

  for (final raw in tokens) {
    final token = raw.trim();
    if (token.isEmpty) continue;
    if (token.startsWith('#')) continue;
    if (containsWordRune(token)) return true;
  }

  return false;
}

// ── Unicode range checkers ───────────────────────────────────────────

bool _isWhitespace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

bool _isPunctuation(int c) =>
    (c >= 0x21 && c <= 0x2F) ||
    (c >= 0x3A && c <= 0x40) ||
    (c >= 0x5B && c <= 0x60) ||
    (c >= 0x7B && c <= 0x7E);

bool _isArabic(int c) =>
    (c >= 0x0600 && c <= 0x06FF) ||
    (c >= 0x0750 && c <= 0x077F) ||
    (c >= 0xFB50 && c <= 0xFDFF) ||
    (c >= 0xFE70 && c <= 0xFEFF);

bool _isLatin(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0x00C0 && c <= 0x024F) ||
    (c >= 0x1E00 && c <= 0x1EFF);

bool _isCJK(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0x3040 && c <= 0x309F) ||
    (c >= 0x30A0 && c <= 0x30FF);

bool _isDevanagari(int c) => c >= 0x0900 && c <= 0x097F;

bool _isCyrillic(int c) =>
    (c >= 0x0400 && c <= 0x04FF) || (c >= 0x0500 && c <= 0x052F);

bool _isHangul(int c) =>
    (c >= 0xAC00 && c <= 0xD7AF) || (c >= 0x1100 && c <= 0x11FF);

bool _isThai(int c) => c >= 0x0E00 && c <= 0x0E7F;
