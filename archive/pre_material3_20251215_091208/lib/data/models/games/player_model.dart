import 'package:dabbler/data/models/games/player.dart';

class PlayerModel extends Player {
  const PlayerModel({
    required super.id,
    required super.playerId,
    required super.gameId,
    required super.status,
    required super.teamAssignment,
    super.position,
    required super.playerName,
    super.playerAvatar,
    super.playerPhone,
    super.playerEmail,
    required super.joinedAt,
    super.checkedInAt,
    super.cancelledAt,
    super.checkInCode,
    required super.isOrganizer,
    super.playerRating,
    super.ratedAt,
    super.ratingComment,
    required super.hasPaid,
    super.amountPaid,
    super.paidAt,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String? ?? json['user_id'] as String,
      gameId: json['game_id'] as String,
      status: _parsePlayerStatus(json['status']),
      teamAssignment: _parseTeamAssignment(json['team_assignment']),
      position: json['position'] as String?,
      playerName:
          json['player_name'] as String? ??
          json['name'] as String? ??
          'Unknown Player',
      playerAvatar:
          json['player_avatar'] as String? ?? json['avatar_url'] as String?,
      playerPhone: json['player_phone'] as String? ?? json['phone'] as String?,
      playerEmail: json['player_email'] as String? ?? json['email'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      checkInCode: json['check_in_code'] as String?,
      isOrganizer: json['is_organizer'] as bool? ?? false,
      playerRating: (json['player_rating'] as num?)?.toDouble(),
      ratedAt: json['rated_at'] != null
          ? DateTime.parse(json['rated_at'] as String)
          : null,
      ratingComment: json['rating_comment'] as String?,
      hasPaid: json['has_paid'] as bool? ?? false,
      amountPaid: (json['amount_paid'] as num?)?.toDouble(),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static PlayerStatus _parsePlayerStatus(dynamic statusData) {
    if (statusData == null) return PlayerStatus.confirmed;

    if (statusData is String) {
      final statusLower = statusData.toLowerCase();

      // Map database status values to PlayerStatus enum
      // Database uses 'active' for joined players, we determine waitlist separately
      if (statusLower == 'active') {
        return PlayerStatus
            .confirmed; // Will be overridden by waitlist logic if needed
      }
      if (statusLower == 'left' || statusLower == 'kicked') {
        return PlayerStatus.cancelled;
      }

      // Try to match enum values directly
      try {
        return PlayerStatus.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == statusLower,
          orElse: () => PlayerStatus.confirmed,
        );
      } catch (e) {
        return PlayerStatus.confirmed;
      }
    }

    return PlayerStatus.confirmed;
  }

  static TeamAssignment _parseTeamAssignment(dynamic teamData) {
    if (teamData == null) return TeamAssignment.unassigned;

    if (teamData is String) {
      try {
        return TeamAssignment.values.firstWhere(
          (e) =>
              e.toString().split('.').last.toLowerCase() ==
              teamData.toLowerCase(),
          orElse: () => TeamAssignment.unassigned,
        );
      } catch (e) {
        return TeamAssignment.unassigned;
      }
    }

    return TeamAssignment.unassigned;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      'game_id': gameId,
      'status': status.toString().split('.').last,
      'team_assignment': teamAssignment.toString().split('.').last,
      'position': position,
      'player_name': playerName,
      'player_avatar': playerAvatar,
      'player_phone': playerPhone,
      'player_email': playerEmail,
      'joined_at': joinedAt.toIso8601String(),
      'checked_in_at': checkedInAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'check_in_code': checkInCode,
      'is_organizer': isOrganizer,
      'player_rating': playerRating,
      'rated_at': ratedAt?.toIso8601String(),
      'rating_comment': ratingComment,
      'has_paid': hasPaid,
      'amount_paid': amountPaid,
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'player_id': playerId,
      'game_id': gameId,
      'status': status.toString().split('.').last,
      'team_assignment': teamAssignment.toString().split('.').last,
      'position': position,
      'player_name': playerName,
      'player_avatar': playerAvatar,
      'player_phone': playerPhone,
      'player_email': playerEmail,
      'check_in_code': checkInCode,
      'is_organizer': isOrganizer,
      'has_paid': hasPaid,
      'amount_paid': amountPaid,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'status': status.toString().split('.').last,
      'team_assignment': teamAssignment.toString().split('.').last,
      'position': position,
      'player_name': playerName,
      'player_avatar': playerAvatar,
      'player_phone': playerPhone,
      'player_email': playerEmail,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'check_in_code': checkInCode,
      'player_rating': playerRating,
      'rated_at': ratedAt?.toIso8601String(),
      'rating_comment': ratingComment,
      'has_paid': hasPaid,
      'amount_paid': amountPaid,
      'paid_at': paidAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Get status display text
  String get statusDisplay {
    switch (status) {
      case PlayerStatus.confirmed:
        return 'Confirmed';
      case PlayerStatus.waitlisted:
        return 'Waitlisted';
      case PlayerStatus.cancelled:
        return 'Cancelled';
      case PlayerStatus.noShow:
        return 'No Show';
    }
  }

  // Get team assignment display text
  String get teamDisplay {
    switch (teamAssignment) {
      case TeamAssignment.teamA:
        return 'Team A';
      case TeamAssignment.teamB:
        return 'Team B';
      case TeamAssignment.unassigned:
        return 'Unassigned';
    }
  }

  // Get payment status display
  String get paymentDisplay {
    return hasPaid ? 'Paid' : 'Payment Pending';
  }

  // Get rating display
  String get ratingDisplay {
    if (playerRating == null) return 'No rating';
    return '${playerRating!.toStringAsFixed(1)}/5.0';
  }

  // Get check-in status
  String get checkInStatus {
    if (checkedInAt != null) return 'Checked In';
    return 'Not Checked In';
  }

  // Check if player has valid profile data
  bool get hasCompleteProfile {
    return playerName.isNotEmpty &&
        (playerEmail != null && playerEmail!.isNotEmpty);
  }

  // Get player avatar URL or default
  String get displayAvatarUrl {
    return playerAvatar ?? 'assets/Avatar/default-avatar.png';
  }

  // Get player display name
  String get displayName {
    return playerName.isNotEmpty ? playerName : 'Anonymous Player';
  }

  // Get payment amount display
  String get paymentAmountDisplay {
    if (amountPaid == null) return 'No payment';
    return '\$${amountPaid!.toStringAsFixed(2)}';
  }

  factory PlayerModel.fromPlayer(Player player) {
    return PlayerModel(
      id: player.id,
      playerId: player.playerId,
      gameId: player.gameId,
      status: player.status,
      teamAssignment: player.teamAssignment,
      position: player.position,
      playerName: player.playerName,
      playerAvatar: player.playerAvatar,
      playerPhone: player.playerPhone,
      playerEmail: player.playerEmail,
      joinedAt: player.joinedAt,
      checkedInAt: player.checkedInAt,
      cancelledAt: player.cancelledAt,
      checkInCode: player.checkInCode,
      isOrganizer: player.isOrganizer,
      playerRating: player.playerRating,
      ratedAt: player.ratedAt,
      ratingComment: player.ratingComment,
      hasPaid: player.hasPaid,
      amountPaid: player.amountPaid,
      paidAt: player.paidAt,
      createdAt: player.createdAt,
      updatedAt: player.updatedAt,
    );
  }

  @override
  PlayerModel copyWith({
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
    return PlayerModel(
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
}
