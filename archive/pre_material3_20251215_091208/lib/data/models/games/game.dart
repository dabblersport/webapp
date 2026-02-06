enum GameStatus { draft, upcoming, inProgress, completed, cancelled }

class Game {
  final String id;
  final String title;
  final String description;
  final String sport;
  final String? venueId;
  final String? venueName; // Populated when venue data is joined

  // Date and time fields
  final DateTime scheduledDate;
  final String startTime; // Format: "HH:mm"
  final String endTime; // Format: "HH:mm"

  // Player management
  final int minPlayers;
  final int maxPlayers;
  final int currentPlayers;

  // Game details
  final String organizerId;
  final String skillLevel; // beginner, intermediate, advanced, mixed
  final double pricePerPlayer;
  final String currency; // USD, AED, EUR, etc.

  // Status and flags
  final GameStatus status;
  final bool isPublic;
  final bool allowsWaitlist;
  final bool checkInEnabled;

  // Cancellation policy
  final DateTime? cancellationDeadline;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const Game({
    required this.id,
    required this.title,
    required this.description,
    required this.sport,
    this.venueId,
    this.venueName,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.minPlayers,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.organizerId,
    required this.skillLevel,
    required this.pricePerPlayer,
    this.currency = 'USD',
    required this.status,
    required this.isPublic,
    required this.allowsWaitlist,
    required this.checkInEnabled,
    this.cancellationDeadline,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if players can join this game
  bool isJoinable() {
    return status == GameStatus.upcoming &&
        isPublic &&
        (currentPlayers < maxPlayers || allowsWaitlist) &&
        DateTime.now().isBefore(getScheduledStartDateTime());
  }

  /// Check if the game is at full capacity
  bool isFull() {
    return currentPlayers >= maxPlayers;
  }

  /// Check if the game can be cancelled
  bool canCancel() {
    if (status == GameStatus.completed || status == GameStatus.cancelled) {
      return false;
    }

    if (cancellationDeadline != null) {
      return DateTime.now().isBefore(cancellationDeadline!);
    }

    // Default: can cancel up to 2 hours before start time
    final startDateTime = getScheduledStartDateTime();
    return DateTime.now().isBefore(
      startDateTime.subtract(const Duration(hours: 2)),
    );
  }

  /// Get time remaining until game starts
  Duration timeUntilStart() {
    final startDateTime = getScheduledStartDateTime();
    final now = DateTime.now();

    if (now.isAfter(startDateTime)) {
      return Duration.zero;
    }

    return startDateTime.difference(now);
  }

  /// Get the full scheduled start DateTime
  DateTime getScheduledStartDateTime() {
    final timeParts = startTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );
  }

  /// Get the full scheduled end DateTime
  DateTime getScheduledEndDateTime() {
    final timeParts = endTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );
  }

  /// Get game duration in minutes
  int getDurationMinutes() {
    final start = getScheduledStartDateTime();
    final end = getScheduledEndDateTime();
    return end.difference(start).inMinutes;
  }

  /// Check if the game is happening today
  bool isToday() {
    final now = DateTime.now();
    return scheduledDate.year == now.year &&
        scheduledDate.month == now.month &&
        scheduledDate.day == now.day;
  }

  /// Check if check-in is available (typically 30 minutes before start)
  bool isCheckInAvailable() {
    if (!checkInEnabled || status != GameStatus.upcoming) {
      return false;
    }

    final startDateTime = getScheduledStartDateTime();
    final now = DateTime.now();
    final checkInWindow = startDateTime.subtract(const Duration(minutes: 30));

    return now.isAfter(checkInWindow) && now.isBefore(startDateTime);
  }

  Game copyWith({
    String? id,
    String? title,
    String? description,
    String? sport,
    String? venueId,
    String? venueName,
    DateTime? scheduledDate,
    String? startTime,
    String? endTime,
    int? minPlayers,
    int? maxPlayers,
    int? currentPlayers,
    String? organizerId,
    String? skillLevel,
    double? pricePerPlayer,
    GameStatus? status,
    bool? isPublic,
    bool? allowsWaitlist,
    bool? checkInEnabled,
    DateTime? cancellationDeadline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Game(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      sport: sport ?? this.sport,
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      organizerId: organizerId ?? this.organizerId,
      skillLevel: skillLevel ?? this.skillLevel,
      pricePerPlayer: pricePerPlayer ?? this.pricePerPlayer,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
      allowsWaitlist: allowsWaitlist ?? this.allowsWaitlist,
      checkInEnabled: checkInEnabled ?? this.checkInEnabled,
      cancellationDeadline: cancellationDeadline ?? this.cancellationDeadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Game && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Game{id: $id, title: $title, sport: $sport, status: $status}';
  }
}
