enum PlayerStatus { confirmed, waitlisted, cancelled, noShow }

enum TeamAssignment { teamA, teamB, unassigned }

class Player {
  final String id;
  final String playerId; // Reference to user ID
  final String gameId;
  final PlayerStatus status;

  // Team assignment
  final TeamAssignment teamAssignment;
  final String? position; // Optional position within the team

  // Player details
  final String playerName;
  final String? playerAvatar;
  final String? playerPhone;
  final String? playerEmail;

  // Timestamps
  final DateTime joinedAt;
  final DateTime? checkedInAt;
  final DateTime? cancelledAt;

  // Check-in functionality
  final String? checkInCode; // QR code or unique identifier for check-in
  final bool isOrganizer;

  // Rating system
  final double? playerRating; // Rating given to this player after the game
  final DateTime? ratedAt;
  final String? ratingComment;

  // Payment status
  final bool hasPaid;
  final double? amountPaid;
  final DateTime? paidAt;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const Player({
    required this.id,
    required this.playerId,
    required this.gameId,
    required this.status,
    required this.teamAssignment,
    this.position,
    required this.playerName,
    this.playerAvatar,
    this.playerPhone,
    this.playerEmail,
    required this.joinedAt,
    this.checkedInAt,
    this.cancelledAt,
    this.checkInCode,
    this.isOrganizer = false,
    this.playerRating,
    this.ratedAt,
    this.ratingComment,
    this.hasPaid = false,
    this.amountPaid,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if player is checked in
  bool get isCheckedIn => checkedInAt != null;

  /// Check if player is active (confirmed and not cancelled)
  bool get isActive => status == PlayerStatus.confirmed && cancelledAt == null;

  /// Check if player is on a team
  bool get isOnTeam => teamAssignment != TeamAssignment.unassigned;

  /// Check if player has been rated
  bool get hasBeenRated => playerRating != null && ratedAt != null;

  /// Check if player can be checked in
  bool canCheckIn() {
    return status == PlayerStatus.confirmed &&
        !isCheckedIn &&
        checkInCode != null;
  }

  /// Check if player can cancel
  bool canCancel() {
    return status == PlayerStatus.confirmed ||
        status == PlayerStatus.waitlisted;
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case PlayerStatus.confirmed:
        return isCheckedIn ? 'Checked In' : 'Confirmed';
      case PlayerStatus.waitlisted:
        return 'Waitlisted';
      case PlayerStatus.cancelled:
        return 'Cancelled';
      case PlayerStatus.noShow:
        return 'No Show';
    }
  }

  /// Get team display text
  String get teamText {
    switch (teamAssignment) {
      case TeamAssignment.teamA:
        return 'Team A';
      case TeamAssignment.teamB:
        return 'Team B';
      case TeamAssignment.unassigned:
        return 'Unassigned';
    }
  }

  /// Get display text for position
  String get positionText {
    if (position == null || position!.isEmpty) {
      return teamText;
    }
    return '$teamText - $position';
  }

  /// Get payment status text
  String get paymentStatusText {
    if (hasPaid) {
      return 'Paid${amountPaid != null ? ' (\$${amountPaid!.toStringAsFixed(2)})' : ''}';
    }
    return 'Unpaid';
  }

  /// Get rating display text
  String get ratingText {
    if (playerRating == null) return 'Not rated';
    return '${playerRating!.toStringAsFixed(1)}/5.0';
  }

  /// Generate a check-in code (typically called when player joins)
  static String generateCheckInCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp % 10000; // Last 4 digits
    return random.toString().padLeft(4, '0');
  }

  /// Calculate time since joining
  Duration timeSinceJoining() {
    return DateTime.now().difference(joinedAt);
  }

  /// Calculate time since check-in (if checked in)
  Duration? timeSinceCheckIn() {
    if (checkedInAt == null) return null;
    return DateTime.now().difference(checkedInAt!);
  }

  Player copyWith({
    String? id,
    String? playerId,
    String? gameId,
    PlayerStatus? status,
    TeamAssignment? teamAssignment,
    String? position,
    String? playerName,
    String? playerAvatar,
    String? playerPhone,
    String? playerEmail,
    DateTime? joinedAt,
    DateTime? checkedInAt,
    DateTime? cancelledAt,
    String? checkInCode,
    bool? isOrganizer,
    double? playerRating,
    DateTime? ratedAt,
    String? ratingComment,
    bool? hasPaid,
    double? amountPaid,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Player(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      gameId: gameId ?? this.gameId,
      status: status ?? this.status,
      teamAssignment: teamAssignment ?? this.teamAssignment,
      position: position ?? this.position,
      playerName: playerName ?? this.playerName,
      playerAvatar: playerAvatar ?? this.playerAvatar,
      playerPhone: playerPhone ?? this.playerPhone,
      playerEmail: playerEmail ?? this.playerEmail,
      joinedAt: joinedAt ?? this.joinedAt,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      checkInCode: checkInCode ?? this.checkInCode,
      isOrganizer: isOrganizer ?? this.isOrganizer,
      playerRating: playerRating ?? this.playerRating,
      ratedAt: ratedAt ?? this.ratedAt,
      ratingComment: ratingComment ?? this.ratingComment,
      hasPaid: hasPaid ?? this.hasPaid,
      amountPaid: amountPaid ?? this.amountPaid,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Player && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Player{id: $id, name: $playerName, status: $status, team: $teamAssignment}';
  }
}
