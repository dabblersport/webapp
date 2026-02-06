/// Game utility functions and helpers
class GameHelpers {
  // DURATION FORMATTING

  /// Format game duration into human-readable string
  static String formatGameDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;

    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    if (hours == 1) {
      return '1 hour $minutes min';
    }

    return '$hours hours $minutes min';
  }

  /// Get suggested duration options for sport
  static List<Duration> getSuggestedDurations(String sport) {
    final suggestions = <Duration>[];

    switch (sport.toLowerCase()) {
      case 'basketball':
        suggestions.addAll([
          const Duration(minutes: 60), // 1 hour
          const Duration(minutes: 90), // 1.5 hours
          const Duration(minutes: 120), // 2 hours
        ]);
        break;
      case 'soccer':
      case 'football':
        suggestions.addAll([
          const Duration(minutes: 90), // 1.5 hours
          const Duration(minutes: 120), // 2 hours
          const Duration(minutes: 150), // 2.5 hours
        ]);
        break;
      case 'tennis':
        suggestions.addAll([
          const Duration(minutes: 60), // 1 hour
          const Duration(minutes: 90), // 1.5 hours
          const Duration(minutes: 120), // 2 hours
        ]);
        break;
      case 'volleyball':
        suggestions.addAll([
          const Duration(minutes: 75), // 1.25 hours
          const Duration(minutes: 90), // 1.5 hours
          const Duration(minutes: 120), // 2 hours
        ]);
        break;
      default:
        suggestions.addAll([
          const Duration(minutes: 60), // 1 hour
          const Duration(minutes: 90), // 1.5 hours
          const Duration(minutes: 120), // 2 hours
          const Duration(minutes: 180), // 3 hours
        ]);
    }

    return suggestions;
  }

  // SPOTS CALCULATION

  /// Calculate remaining spots in a game
  static int calculateSpotsRemaining({
    required int maxPlayers,
    required int currentPlayers,
    int waitlistCount = 0,
  }) {
    final remaining = maxPlayers - currentPlayers;
    return remaining < 0 ? 0 : remaining;
  }

  /// Get spots status message
  static String getSpotsStatusMessage({
    required int maxPlayers,
    required int currentPlayers,
    int waitlistCount = 0,
  }) {
    final remaining = calculateSpotsRemaining(
      maxPlayers: maxPlayers,
      currentPlayers: currentPlayers,
      waitlistCount: waitlistCount,
    );

    if (remaining == 0) {
      return waitlistCount > 0
          ? 'Game full • $waitlistCount on waitlist'
          : 'Game full';
    }

    if (remaining == 1) {
      return '1 spot left';
    }

    if (remaining <= 3) {
      return '$remaining spots left';
    }

    return '$remaining spots available';
  }

  /// Check if game is nearly full (≤3 spots remaining)
  static bool isGameNearlyFull({
    required int maxPlayers,
    required int currentPlayers,
  }) {
    final remaining = calculateSpotsRemaining(
      maxPlayers: maxPlayers,
      currentPlayers: currentPlayers,
    );
    return remaining <= 3 && remaining > 0;
  }

  /// Check if game is full
  static bool isGameFull({
    required int maxPlayers,
    required int currentPlayers,
  }) {
    return calculateSpotsRemaining(
          maxPlayers: maxPlayers,
          currentPlayers: currentPlayers,
        ) ==
        0;
  }

  // GAME TITLE GENERATION

  /// Generate game title from components
  static String generateGameTitle({
    required String sport,
    required String skillLevel,
    String? venueName,
    DateTime? dateTime,
    String? customTitle,
  }) {
    // Use custom title if provided
    if (customTitle != null && customTitle.trim().isNotEmpty) {
      return customTitle.trim();
    }

    final buffer = StringBuffer();

    // Start with skill level and sport
    buffer.write('${_capitalizeFirst(skillLevel)} ${_capitalizeFirst(sport)}');

    // Add venue if provided
    if (venueName != null && venueName.isNotEmpty) {
      buffer.write(' at $venueName');
    }

    // Add time context if provided
    if (dateTime != null) {
      final now = DateTime.now();
      final difference = dateTime.difference(now);

      if (difference.inDays == 0) {
        buffer.write(' Today');
      } else if (difference.inDays == 1) {
        buffer.write(' Tomorrow');
      } else if (difference.inDays <= 7) {
        buffer.write(' This ${_getDayName(dateTime.weekday)}');
      }
    }

    return buffer.toString();
  }

  /// Generate short game title for cards/lists
  static String generateShortTitle({
    required String sport,
    required String skillLevel,
    String? customTitle,
  }) {
    if (customTitle != null && customTitle.trim().isNotEmpty) {
      return customTitle.trim().length > 25
          ? '${customTitle.trim().substring(0, 22)}...'
          : customTitle.trim();
    }

    return '${_capitalizeFirst(skillLevel)} ${_capitalizeFirst(sport)}';
  }

  // PRICE FORMATTING

  /// Format price display with currency
  static String formatPrice(double price, {String currency = 'USD'}) {
    if (price == 0) {
      return 'Free';
    }

    final symbol = _getCurrencySymbol(currency);

    if (price == price.roundToDouble()) {
      return '$symbol${price.round()}';
    }

    return '$symbol${price.toStringAsFixed(2)}';
  }

  /// Format price per person
  static String formatPricePerPerson(
    double totalPrice,
    int numberOfPlayers, {
    String currency = 'USD',
  }) {
    if (totalPrice == 0) {
      return 'Free';
    }

    if (numberOfPlayers <= 0) {
      return formatPrice(totalPrice, currency: currency);
    }

    final pricePerPerson = totalPrice / numberOfPlayers;
    final symbol = _getCurrencySymbol(currency);

    return '$symbol${pricePerPerson.toStringAsFixed(2)} per person';
  }

  /// Format price range
  static String formatPriceRange(
    double minPrice,
    double maxPrice, {
    String currency = 'USD',
  }) {
    if (minPrice == maxPrice) {
      return formatPrice(minPrice, currency: currency);
    }

    final symbol = _getCurrencySymbol(currency);
    final min = minPrice == minPrice.roundToDouble()
        ? minPrice.round().toString()
        : minPrice.toStringAsFixed(2);
    final max = maxPrice == maxPrice.roundToDouble()
        ? maxPrice.round().toString()
        : maxPrice.toStringAsFixed(2);

    return '$symbol$min - $symbol$max';
  }

  // TIME CALCULATIONS

  /// Calculate game end time
  static DateTime calculateGameEndTime({
    required DateTime startTime,
    required Duration duration,
  }) {
    return startTime.add(duration);
  }

  /// Get time until game starts
  static Duration getTimeUntilGame(DateTime gameTime) {
    return gameTime.difference(DateTime.now());
  }

  /// Check if game is starting soon (within 2 hours)
  static bool isGameStartingSoon(DateTime gameTime) {
    final timeUntil = getTimeUntilGame(gameTime);
    return timeUntil.inHours <= 2 && timeUntil.inMinutes > 0;
  }

  /// Check if game is happening now
  static bool isGameHappeningNow({
    required DateTime startTime,
    required Duration duration,
  }) {
    final now = DateTime.now();
    final endTime = calculateGameEndTime(
      startTime: startTime,
      duration: duration,
    );

    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Check if game has ended
  static bool hasGameEnded({
    required DateTime startTime,
    required Duration duration,
  }) {
    final endTime = calculateGameEndTime(
      startTime: startTime,
      duration: duration,
    );

    return DateTime.now().isAfter(endTime);
  }

  /// Format time until game
  static String formatTimeUntilGame(DateTime gameTime) {
    final duration = getTimeUntilGame(gameTime);

    if (duration.isNegative) {
      return 'Game started';
    }

    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }

    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }

    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }

    return 'Starting now';
  }

  // SHARING AND DEEP LINKS

  /// Generate shareable game link
  static String generateGameShareLink({
    required String gameId,
    String baseUrl = 'https://dabbler.app',
  }) {
    return '$baseUrl/games/$gameId';
  }

  /// Generate join game link
  static String generateJoinGameLink({
    required String gameId,
    String baseUrl = 'https://dabbler.app',
  }) {
    return '$baseUrl/games/$gameId/join';
  }

  /// Generate shareable text for game
  static String generateShareText({
    required String gameTitle,
    required String sport,
    required DateTime dateTime,
    required String venueName,
    String? skillLevel,
    double? price,
  }) {
    final buffer = StringBuffer();

    buffer.write('Join me for $gameTitle! 🏀\n\n');
    buffer.write('📍 $venueName\n');
    buffer.write('📅 ${_formatShareDateTime(dateTime)}\n');

    if (skillLevel != null) {
      buffer.write('🎯 ${_capitalizeFirst(skillLevel)} level\n');
    }

    if (price != null && price > 0) {
      buffer.write('💰 ${formatPrice(price)}\n');
    }

    buffer.write('\nTap the link to join!');

    return buffer.toString();
  }

  // CALENDAR INTEGRATION

  /// Create calendar event data
  static Map<String, dynamic> createCalendarEventData({
    required String title,
    required DateTime startTime,
    required Duration duration,
    required String venueName,
    String? venueAddress,
    String? description,
    String? gameId,
  }) {
    final endTime = calculateGameEndTime(
      startTime: startTime,
      duration: duration,
    );

    return {
      'title': title,
      'description': description ?? 'Game organized through Dabbler',
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'location': venueAddress ?? venueName,
      'url': gameId != null ? generateGameShareLink(gameId: gameId) : null,
      'reminder': [
        {'minutes': 60}, // 1 hour before
        {'minutes': 15}, // 15 minutes before
      ],
    };
  }

  /// Generate calendar event URL (Google Calendar)
  static String generateCalendarEventUrl({
    required String title,
    required DateTime startTime,
    required Duration duration,
    required String venueName,
    String? venueAddress,
    String? description,
  }) {
    final endTime = calculateGameEndTime(
      startTime: startTime,
      duration: duration,
    );

    final params = <String, String>{
      'action': 'TEMPLATE',
      'text': Uri.encodeComponent(title),
      'dates':
          '${_formatCalendarDate(startTime)}/${_formatCalendarDate(endTime)}',
      'location': Uri.encodeComponent(venueAddress ?? venueName),
      'details': Uri.encodeComponent(
        description ?? 'Game organized through Dabbler',
      ),
    };

    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'https://calendar.google.com/calendar/render?$query';
  }

  // VALIDATION HELPERS

  /// Validate if date is in the future
  static bool isValidFutureDate(DateTime dateTime) {
    return dateTime.isAfter(DateTime.now());
  }

  /// Validate if date is within booking window (not too far in future)
  static bool isWithinBookingWindow(
    DateTime dateTime, {
    int maxDaysInFuture = 90,
  }) {
    final now = DateTime.now();
    final maxDate = now.add(Duration(days: maxDaysInFuture));

    return dateTime.isAfter(now) && dateTime.isBefore(maxDate);
  }

  /// Get minimum advance booking time for sport
  static Duration getMinimumAdvanceBooking(String sport) {
    // Most sports need at least 2 hours advance booking
    switch (sport.toLowerCase()) {
      case 'basketball':
      case 'tennis':
        return const Duration(hours: 2);
      case 'soccer':
      case 'football':
        return const Duration(hours: 4); // More setup time needed
      default:
        return const Duration(hours: 2);
    }
  }

  // PRIVATE HELPER METHODS

  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  static String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      default:
        return '\$';
    }
  }

  static String _formatShareDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${_formatTime(dateTime)}';
    } else if (difference.inDays <= 7) {
      return '${_getDayName(dateTime.weekday)} at ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.month}/${dateTime.day} at ${_formatTime(dateTime)}';
    }
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return '$displayHour:$displayMinute $period';
  }

  static String _formatCalendarDate(DateTime dateTime) {
    return '${dateTime.toUtc().toIso8601String().replaceAll(RegExp(r'[-:.]'), '').replaceAll('T', 'T').substring(0, 15)}Z';
  }
}

/// Extension methods for game-related calculations
extension GameCalculationExtensions on DateTime {
  /// Check if this date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if this date is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  /// Check if this date is within the current week
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        isBefore(endOfWeek.add(const Duration(days: 1)));
  }
}
