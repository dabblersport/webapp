// Text content validation utilities for social posts and comments
import '../../constants/social_constants.dart';

/// Result of text content validation
class TextValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> metadata;

  const TextValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    this.metadata = const {},
  });

  factory TextValidationResult.valid() {
    return const TextValidationResult(isValid: true, errors: [], warnings: []);
  }

  factory TextValidationResult.invalid(
    List<String> errors, [
    List<String>? warnings,
  ]) {
    return TextValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
    );
  }

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Text content validator for social posts
class TextContentValidator {
  // Prohibited words and phrases
  static const List<String> _prohibitedWords = [
    'gambling',
    'bet',
    'casino',
    'poker',
    'lottery',
    'porn',
    'xxx',
    'adult',
    'sex',
    'nude',
    'naked',
  ];

  // Common spam patterns
  static final List<RegExp> _spamPatterns = [
    RegExp(r'(.)\1{4,}'), // Repeated characters (aaaaa)
    RegExp(r'\b(\w+)\s+\1\s+\1\b', caseSensitive: false), // Repeated words
    RegExp(r'[A-Z]{10,}'), // All caps sequences
    RegExp(r'!!{3,}|\.{4,}|\?{3,}'), // Excessive punctuation
    RegExp(
      r'\b(FREE|WIN|PRIZE|MONEY|CASH|URGENT|CLICK|BUY NOW)\b',
      caseSensitive: false,
    ),
  ];

  // Suspicious URL patterns
  static final List<RegExp> _phishingPatterns = [
    RegExp(r'bit\.ly|tinyurl|t\.co|goo\.gl|ow\.ly', caseSensitive: false),
    RegExp(r'[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'), // IP addresses
    RegExp(
      r'(paypal|amazon|apple|microsoft|google|facebook).*\.(tk|ml|ga|cf)',
      caseSensitive: false,
    ),
    RegExp(
      r'(login|account|verify|update|security).*urgent',
      caseSensitive: false,
    ),
  ];

  /// Validates post/comment length limits
  TextValidationResult validateLength(
    String content,
    int minLength,
    int maxLength,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    if (content.trim().isEmpty) {
      errors.add('Content cannot be empty');
    } else if (content.trim().length < minLength) {
      errors.add('Content must be at least $minLength characters');
    } else if (content.length > maxLength) {
      errors.add('Content must not exceed $maxLength characters');
    }

    // Warning for very short content
    if (content.trim().isNotEmpty && content.trim().length < minLength * 0.5) {
      warnings.add('Content is quite short. Consider adding more detail');
    }

    // Warning for approaching limit
    if (content.length > maxLength * 0.9) {
      warnings.add('Content is approaching character limit');
    }

    return TextValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: {
        'character_count': content.length,
        'word_count': _countWords(content),
      },
    );
  }

  /// Checks for prohibited words/phrases
  TextValidationResult validateProhibitedContent(String content) {
    final errors = <String>[];
    final warnings = <String>[];
    final foundProhibited = <String>[];

    final lowerContent = content.toLowerCase();

    // Check for exact prohibited words
    for (final word in _prohibitedWords) {
      if (lowerContent.contains(word.toLowerCase())) {
        foundProhibited.add(word);
      }
    }

    if (foundProhibited.isNotEmpty) {
      errors.add(
        'Content contains prohibited words: ${foundProhibited.join(', ')}',
      );
    }

    // Check for potential issues that warrant warnings
    if (lowerContent.contains('click here') ||
        lowerContent.contains('click now')) {
      warnings.add('Content contains suspicious call-to-action phrases');
    }

    if (RegExp(
      r'\bmoney\b.*\bfast\b|\bfast\b.*\bmoney\b',
      caseSensitive: false,
    ).hasMatch(content)) {
      warnings.add('Content may contain get-rich-quick messaging');
    }

    return TextValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: {
        'prohibited_words_found': foundProhibited,
        'suspicious_phrases': warnings.length,
      },
    );
  }

  /// Detects spam patterns (repeated characters, all caps)
  TextValidationResult validateSpamPatterns(String content) {
    final errors = <String>[];
    final warnings = <String>[];
    final detectedPatterns = <String>[];

    for (final pattern in _spamPatterns) {
      if (pattern.hasMatch(content)) {
        final match = pattern.firstMatch(content);
        if (match != null) {
          detectedPatterns.add(match.group(0) ?? 'unknown');
        }
      }
    }

    // Check for excessive repetition
    if (detectedPatterns.isNotEmpty) {
      // Severe patterns are errors
      if (content.contains(RegExp(r'(.)\1{8,}'))) {
        errors.add('Content contains excessive character repetition');
      } else if (content.contains(RegExp(r'[A-Z]{20,}'))) {
        errors.add('Content contains excessive capitalization');
      } else {
        warnings.add('Content may appear spammy due to repetitive patterns');
      }
    }

    // Check caps ratio
    final capsCount = content.replaceAll(RegExp(r'[^A-Z]'), '').length;
    final letterCount = content.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;

    if (letterCount > 0) {
      final capsRatio = capsCount / letterCount;
      if (capsRatio > 0.7 && letterCount > 10) {
        errors.add('Content contains too much capitalization');
      } else if (capsRatio > 0.5 && letterCount > 10) {
        warnings.add('Consider reducing capitalization for better readability');
      }
    }

    return TextValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: {
        'spam_patterns': detectedPatterns,
        'caps_ratio': letterCount > 0 ? capsCount / letterCount : 0.0,
      },
    );
  }

  /// Validates URL formats in content
  TextValidationResult validateUrls(String content) {
    final errors = <String>[];
    final warnings = <String>[];
    final urls = <String>[];

    // Extract URLs
    final urlRegex = RegExp(
      r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.[a-zA-Z]{2,}[^\s]*',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(content);
    for (final match in matches) {
      urls.add(match.group(0)!);
    }

    if (urls.length > SocialConstants.maxUrlsPerPost) {
      errors.add(
        'Too many URLs in content (max ${SocialConstants.maxUrlsPerPost})',
      );
    }

    // Validate each URL
    for (final url in urls) {
      // Check for suspicious URLs
      for (final pattern in _phishingPatterns) {
        if (pattern.hasMatch(url)) {
          warnings.add('URL may be suspicious: $url');
          break;
        }
      }

      // Check URL length
      if (url.length > 200) {
        warnings.add('Very long URL detected, consider using a URL shortener');
      }

      // Basic format validation
      if (!_isValidUrlFormat(url)) {
        errors.add('Invalid URL format: $url');
      }
    }

    return TextValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: {'urls_found': urls, 'url_count': urls.length},
    );
  }

  /// Checks mention format (@username)
  TextValidationResult validateMentions(String content) {
    final errors = <String>[];
    final warnings = <String>[];
    final mentions = <String>[];

    // Extract mentions
    final mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(content);

    for (final match in matches) {
      final username = match.group(1)!;
      mentions.add(username);

      // Validate username format
      if (username.length < 3) {
        errors.add('Username too short in mention: @$username');
      } else if (username.length > 20) {
        errors.add('Username too long in mention: @$username');
      } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        errors.add('Invalid characters in username: @$username');
      }
    }

    if (mentions.length > SocialConstants.maxMentionsPerPost) {
      errors.add(
        'Too many mentions (max ${SocialConstants.maxMentionsPerPost})',
      );
    }

    // Check for duplicate mentions
    final uniqueMentions = mentions.toSet();
    if (uniqueMentions.length != mentions.length) {
      warnings.add('Duplicate mentions detected');
    }

    return TextValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: {
        'mentions_found': mentions,
        'unique_mentions': uniqueMentions.length,
      },
    );
  }

  /// Validates hashtag format (#tag)
  TextValidationResult validateHashtags(String content) {
    final errors = <String>[];
    final warnings = <String>[];
    final hashtags = <String>[];

    // Extract hashtags
    final hashtagRegex = RegExp(r'#(\w+)');
    final matches = hashtagRegex.allMatches(content);

    for (final match in matches) {
      final tag = match.group(1)!;
      hashtags.add(tag);

      // Validate hashtag format
      if (tag.length < 2) {
        errors.add('Hashtag too short: #$tag');
      } else if (tag.length > 30) {
        errors.add('Hashtag too long: #$tag (max 30 characters)');
      } else if (RegExp(r'^\d+$').hasMatch(tag)) {
        warnings.add('Hashtag is only numbers: #$tag');
      }
    }

    if (hashtags.length > SocialConstants.maxHashtagsPerPost) {
      errors.add(
        'Too many hashtags (max ${SocialConstants.maxHashtagsPerPost})',
      );
    }

    // Check for duplicate hashtags
    final uniqueHashtags = hashtags.map((h) => h.toLowerCase()).toSet();
    if (uniqueHashtags.length != hashtags.length) {
      warnings.add('Duplicate hashtags detected');
    }

    return TextValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: {
        'hashtags_found': hashtags,
        'unique_hashtags': uniqueHashtags.length,
      },
    );
  }

  /// Detects and limits consecutive line breaks
  TextValidationResult validateLineBreaks(String content) {
    final errors = <String>[];
    final warnings = <String>[];

    // Count consecutive line breaks
    final consecutiveBreaks = RegExp(r'\n{3,}').allMatches(content);

    if (consecutiveBreaks.isNotEmpty) {
      final maxConsecutive = consecutiveBreaks
          .map((match) => match.group(0)!.length)
          .reduce((a, b) => a > b ? a : b);

      if (maxConsecutive > 5) {
        errors.add('Too many consecutive line breaks (max 2)');
      } else if (maxConsecutive > 2) {
        warnings.add(
          'Consider reducing consecutive line breaks for better formatting',
        );
      }
    }

    // Check total line break ratio
    final lineBreakCount = '\n'.allMatches(content).length;
    final contentLength = content.length;

    if (contentLength > 0 && (lineBreakCount / contentLength) > 0.3) {
      warnings.add('Content has many line breaks, may affect readability');
    }

    return TextValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: {
        'line_breaks_count': lineBreakCount,
        'max_consecutive_breaks': consecutiveBreaks.isNotEmpty
            ? consecutiveBreaks
                  .map((m) => m.group(0)!.length)
                  .reduce((a, b) => a > b ? a : b)
            : 0,
      },
    );
  }

  /// Validates emoji usage limits
  TextValidationResult validateEmojiUsage(String content) {
    final errors = <String>[];
    final warnings = <String>[];

    // Count emojis (simplified pattern)
    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|'
      r'[\u{1F700}-\u{1F77F}]|[\u{1F780}-\u{1F7FF}]|[\u{1F800}-\u{1F8FF}]|'
      r'[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
      unicode: true,
    );

    final emojiMatches = emojiRegex.allMatches(content);
    final emojiCount = emojiMatches.length;

    if (emojiCount > SocialConstants.maxEmojisPerPost) {
      errors.add('Too many emojis (max ${SocialConstants.maxEmojisPerPost})');
    }

    // Check emoji density
    final contentWithoutEmojis = content.replaceAll(emojiRegex, '');
    final textLength = contentWithoutEmojis.trim().length;

    if (textLength > 0) {
      final emojiRatio = emojiCount / textLength;
      if (emojiRatio > 0.5) {
        warnings.add('High emoji density may affect readability');
      }
    } else if (emojiCount > 3) {
      warnings.add('Content is mostly emojis, consider adding text');
    }

    return TextValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      metadata: {
        'emoji_count': emojiCount,
        'text_length': textLength,
        'emoji_ratio': textLength > 0 ? emojiCount / textLength : 0.0,
      },
    );
  }

  /// Comprehensive content validation
  TextValidationResult validateContent(
    String content, {
    int? minLength,
    int? maxLength,
    bool checkProhibited = true,
    bool checkSpam = true,
    bool checkUrls = true,
    bool checkMentions = true,
    bool checkHashtags = true,
    bool checkLineBreaks = true,
    bool checkEmojis = true,
  }) {
    final allErrors = <String>[];
    final allWarnings = <String>[];
    final allMetadata = <String, dynamic>{};

    // Length validation
    if (minLength != null || maxLength != null) {
      final lengthResult = validateLength(
        content,
        minLength ?? 1,
        maxLength ?? SocialConstants.maxPostLength,
      );
      allErrors.addAll(lengthResult.errors);
      allWarnings.addAll(lengthResult.warnings);
      allMetadata.addAll(lengthResult.metadata);
    }

    // Prohibited content
    if (checkProhibited) {
      final prohibitedResult = validateProhibitedContent(content);
      allErrors.addAll(prohibitedResult.errors);
      allWarnings.addAll(prohibitedResult.warnings);
      allMetadata.addAll(prohibitedResult.metadata);
    }

    // Spam patterns
    if (checkSpam) {
      final spamResult = validateSpamPatterns(content);
      allErrors.addAll(spamResult.errors);
      allWarnings.addAll(spamResult.warnings);
      allMetadata.addAll(spamResult.metadata);
    }

    // URLs
    if (checkUrls) {
      final urlResult = validateUrls(content);
      allErrors.addAll(urlResult.errors);
      allWarnings.addAll(urlResult.warnings);
      allMetadata.addAll(urlResult.metadata);
    }

    // Mentions
    if (checkMentions) {
      final mentionResult = validateMentions(content);
      allErrors.addAll(mentionResult.errors);
      allWarnings.addAll(mentionResult.warnings);
      allMetadata.addAll(mentionResult.metadata);
    }

    // Hashtags
    if (checkHashtags) {
      final hashtagResult = validateHashtags(content);
      allErrors.addAll(hashtagResult.errors);
      allWarnings.addAll(hashtagResult.warnings);
      allMetadata.addAll(hashtagResult.metadata);
    }

    // Line breaks
    if (checkLineBreaks) {
      final lineBreakResult = validateLineBreaks(content);
      allErrors.addAll(lineBreakResult.errors);
      allWarnings.addAll(lineBreakResult.warnings);
      allMetadata.addAll(lineBreakResult.metadata);
    }

    // Emojis
    if (checkEmojis) {
      final emojiResult = validateEmojiUsage(content);
      allErrors.addAll(emojiResult.errors);
      allWarnings.addAll(emojiResult.warnings);
      allMetadata.addAll(emojiResult.metadata);
    }

    return TextValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
      warnings: allWarnings,
      metadata: allMetadata,
    );
  }

  /// Helper method to count words
  int _countWords(String content) {
    return content
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  /// Helper method to validate URL format
  bool _isValidUrlFormat(String url) {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// Quick validation for real-time feedback
  TextValidationResult quickValidate(String content, int maxLength) {
    return validateContent(
      content,
      maxLength: maxLength,
      checkProhibited: false,
      checkSpam: false,
      checkUrls: false,
    );
  }
}
