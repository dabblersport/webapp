/// Enumeration for game status throughout its lifecycle
enum GameStatus {
  /// Game is being created but not yet published
  draft,

  /// Game is published and accepting players
  open,

  /// Game is published but full (no more players can join)
  full,

  /// Game is starting soon (within check-in window)
  starting,

  /// Game is currently in progress
  inProgress,

  /// Game has finished successfully
  completed,

  /// Game was cancelled by organizer
  cancelled,

  /// Game was cancelled due to weather
  weatherCancelled,

  /// Game was cancelled due to venue issues
  venueCancelled,

  /// Game expired (start time passed with insufficient players)
  expired,
}

extension GameStatusExtension on GameStatus {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case GameStatus.draft:
        return 'Draft';
      case GameStatus.open:
        return 'Open';
      case GameStatus.full:
        return 'Full';
      case GameStatus.starting:
        return 'Starting Soon';
      case GameStatus.inProgress:
        return 'In Progress';
      case GameStatus.completed:
        return 'Completed';
      case GameStatus.cancelled:
        return 'Cancelled';
      case GameStatus.weatherCancelled:
        return 'Weather Cancelled';
      case GameStatus.venueCancelled:
        return 'Venue Cancelled';
      case GameStatus.expired:
        return 'Expired';
    }
  }

  /// Whether players can join this game
  bool get canJoin {
    return this == GameStatus.open;
  }

  /// Whether players can check in to this game
  bool get canCheckIn {
    return this == GameStatus.starting || this == GameStatus.inProgress;
  }

  /// Whether the game is active (not cancelled/expired)
  bool get isActive {
    return ![
      GameStatus.cancelled,
      GameStatus.weatherCancelled,
      GameStatus.venueCancelled,
      GameStatus.expired,
    ].contains(this);
  }

  /// Whether the game has ended
  bool get isEnded {
    return [
      GameStatus.completed,
      GameStatus.cancelled,
      GameStatus.weatherCancelled,
      GameStatus.venueCancelled,
      GameStatus.expired,
    ].contains(this);
  }
}

/// Player's status in relation to a specific game
enum PlayerStatus {
  /// Player has joined and confirmed attendance
  joined,

  /// Player is on the waitlist
  waitlisted,

  /// Player has checked in to the game
  checkedIn,

  /// Player attended and participated in the game
  attended,

  /// Player joined but didn't show up
  noShow,

  /// Player cancelled their participation
  cancelled,

  /// Player was removed by organizer
  removed,

  /// Player's participation is pending approval
  pendingApproval,
}

extension PlayerStatusExtension on PlayerStatus {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case PlayerStatus.joined:
        return 'Joined';
      case PlayerStatus.waitlisted:
        return 'Waitlisted';
      case PlayerStatus.checkedIn:
        return 'Checked In';
      case PlayerStatus.attended:
        return 'Attended';
      case PlayerStatus.noShow:
        return 'No Show';
      case PlayerStatus.cancelled:
        return 'Cancelled';
      case PlayerStatus.removed:
        return 'Removed';
      case PlayerStatus.pendingApproval:
        return 'Pending Approval';
    }
  }

  /// Whether this status represents an active participation
  bool get isActive {
    return [
      PlayerStatus.joined,
      PlayerStatus.waitlisted,
      PlayerStatus.checkedIn,
      PlayerStatus.pendingApproval,
    ].contains(this);
  }

  /// Whether the player actually participated
  bool get didParticipate {
    return [PlayerStatus.attended, PlayerStatus.checkedIn].contains(this);
  }
}

/// Status of venue booking for a game
enum BookingStatus {
  /// Booking is being processed
  pending,

  /// Booking is confirmed and active
  confirmed,

  /// Booking was cancelled by organizer
  cancelled,

  /// Booking was rejected by venue
  rejected,

  /// Booking expired due to non-payment
  expired,

  /// Booking is on hold pending payment
  paymentPending,

  /// Booking requires modification
  modificationRequired,
}

extension BookingStatusExtension on BookingStatus {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.expired:
        return 'Expired';
      case BookingStatus.paymentPending:
        return 'Payment Pending';
      case BookingStatus.modificationRequired:
        return 'Modification Required';
    }
  }

  /// Whether the booking is active
  bool get isActive {
    return [
      BookingStatus.confirmed,
      BookingStatus.pending,
      BookingStatus.paymentPending,
    ].contains(this);
  }
}

/// Payment status for game fees
enum PaymentStatus {
  /// No payment required
  notRequired,

  /// Payment is pending
  pending,

  /// Payment completed successfully
  completed,

  /// Payment failed
  failed,

  /// Payment was refunded
  refunded,

  /// Partial refund issued
  partialRefund,

  /// Payment is being processed
  processing,

  /// Payment requires manual review
  underReview,

  /// Payment was disputed/charged back
  disputed,
}

extension PaymentStatusExtension on PaymentStatus {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case PaymentStatus.notRequired:
        return 'Free';
      case PaymentStatus.pending:
        return 'Payment Pending';
      case PaymentStatus.completed:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.partialRefund:
        return 'Partially Refunded';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.underReview:
        return 'Under Review';
      case PaymentStatus.disputed:
        return 'Disputed';
    }
  }

  /// Whether payment is successful
  bool get isPaid {
    return this == PaymentStatus.completed;
  }

  /// Whether payment can be retried
  bool get canRetry {
    return [PaymentStatus.failed, PaymentStatus.pending].contains(this);
  }
}

/// Method used for checking in to games
enum CheckInMethod {
  /// Manual check-in by organizer
  manual,

  /// QR code scan
  qrCode,

  /// Location-based check-in (GPS)
  location,

  /// Check-in code entry
  code,

  /// NFC tap
  nfc,

  /// Bluetooth proximity
  bluetooth,

  /// Self check-in by player
  selfCheckIn,
}

extension CheckInMethodExtension on CheckInMethod {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case CheckInMethod.manual:
        return 'Manual Check-in';
      case CheckInMethod.qrCode:
        return 'QR Code';
      case CheckInMethod.location:
        return 'Location-based';
      case CheckInMethod.code:
        return 'Check-in Code';
      case CheckInMethod.nfc:
        return 'NFC Tap';
      case CheckInMethod.bluetooth:
        return 'Bluetooth';
      case CheckInMethod.selfCheckIn:
        return 'Self Check-in';
    }
  }

  /// Whether this method requires proximity to venue
  bool get requiresProximity {
    return [
      CheckInMethod.location,
      CheckInMethod.qrCode,
      CheckInMethod.nfc,
      CheckInMethod.bluetooth,
    ].contains(this);
  }
}

/// Weather conditions that might affect games
enum WeatherCondition {
  /// Clear and sunny
  clear,

  /// Partly cloudy
  partlyCloudy,

  /// Overcast/cloudy
  cloudy,

  /// Light rain
  lightRain,

  /// Heavy rain
  heavyRain,

  /// Thunderstorms
  thunderstorm,

  /// Snow
  snow,

  /// Extreme heat
  extremeHeat,

  /// Extreme cold
  extremeCold,

  /// High winds
  highWinds,

  /// Fog
  fog,

  /// Unknown/unavailable
  unknown,
}

extension WeatherConditionExtension on WeatherCondition {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case WeatherCondition.clear:
        return 'Clear';
      case WeatherCondition.partlyCloudy:
        return 'Partly Cloudy';
      case WeatherCondition.cloudy:
        return 'Cloudy';
      case WeatherCondition.lightRain:
        return 'Light Rain';
      case WeatherCondition.heavyRain:
        return 'Heavy Rain';
      case WeatherCondition.thunderstorm:
        return 'Thunderstorm';
      case WeatherCondition.snow:
        return 'Snow';
      case WeatherCondition.extremeHeat:
        return 'Extreme Heat';
      case WeatherCondition.extremeCold:
        return 'Extreme Cold';
      case WeatherCondition.highWinds:
        return 'High Winds';
      case WeatherCondition.fog:
        return 'Fog';
      case WeatherCondition.unknown:
        return 'Unknown';
    }
  }

  /// Whether this weather condition is suitable for outdoor games
  bool get isSuitableForOutdoor {
    return [
      WeatherCondition.clear,
      WeatherCondition.partlyCloudy,
      WeatherCondition.cloudy,
    ].contains(this);
  }

  /// Whether this weather might require game cancellation
  bool get mightRequireCancellation {
    return [
      WeatherCondition.heavyRain,
      WeatherCondition.thunderstorm,
      WeatherCondition.snow,
      WeatherCondition.extremeHeat,
      WeatherCondition.extremeCold,
      WeatherCondition.highWinds,
    ].contains(this);
  }

  /// Weather severity level (0-3, where 3 is most severe)
  int get severityLevel {
    switch (this) {
      case WeatherCondition.clear:
      case WeatherCondition.partlyCloudy:
        return 0;
      case WeatherCondition.cloudy:
      case WeatherCondition.lightRain:
      case WeatherCondition.fog:
        return 1;
      case WeatherCondition.heavyRain:
      case WeatherCondition.snow:
      case WeatherCondition.highWinds:
        return 2;
      case WeatherCondition.thunderstorm:
      case WeatherCondition.extremeHeat:
      case WeatherCondition.extremeCold:
        return 3;
      case WeatherCondition.unknown:
        return 0;
    }
  }
}

/// Team assignment for team-based games
enum TeamAssignment {
  /// No team assignment (individual play)
  none,

  /// Automatically balanced teams
  autoBalanced,

  /// Teams chosen by captains
  captainsPick,

  /// Random team assignment
  random,

  /// Manual assignment by organizer
  manual,

  /// Self-selected teams
  selfSelected,

  /// Pre-formed teams
  preFormed,
}

extension TeamAssignmentExtension on TeamAssignment {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case TeamAssignment.none:
        return 'No Teams';
      case TeamAssignment.autoBalanced:
        return 'Auto-Balanced';
      case TeamAssignment.captainsPick:
        return 'Captains Pick';
      case TeamAssignment.random:
        return 'Random Teams';
      case TeamAssignment.manual:
        return 'Manual Assignment';
      case TeamAssignment.selfSelected:
        return 'Self-Selected';
      case TeamAssignment.preFormed:
        return 'Pre-Formed Teams';
    }
  }

  /// Whether teams are used in this assignment method
  bool get usesTeams {
    return this != TeamAssignment.none;
  }

  /// Whether assignment happens automatically
  bool get isAutomatic {
    return [TeamAssignment.autoBalanced, TeamAssignment.random].contains(this);
  }
}

/// Skill level for games and players
enum SkillLevel {
  /// Beginner level
  beginner,

  /// Intermediate level
  intermediate,

  /// Advanced level
  advanced,

  /// Professional/expert level
  expert,

  /// Mixed skill levels welcome
  mixed,
}

extension SkillLevelExtension on SkillLevel {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case SkillLevel.beginner:
        return 'Beginner';
      case SkillLevel.intermediate:
        return 'Intermediate';
      case SkillLevel.advanced:
        return 'Advanced';
      case SkillLevel.expert:
        return 'Expert';
      case SkillLevel.mixed:
        return 'Mixed Levels';
    }
  }

  /// Description of skill level
  String get description {
    switch (this) {
      case SkillLevel.beginner:
        return 'New to the sport or still learning basics';
      case SkillLevel.intermediate:
        return 'Comfortable with fundamentals, developing skills';
      case SkillLevel.advanced:
        return 'Strong player with good technique and strategy';
      case SkillLevel.expert:
        return 'Professional or near-professional level';
      case SkillLevel.mixed:
        return 'All skill levels welcome';
    }
  }

  /// Numeric value for sorting/comparison (1-5)
  int get numericValue {
    switch (this) {
      case SkillLevel.beginner:
        return 1;
      case SkillLevel.intermediate:
        return 2;
      case SkillLevel.advanced:
        return 3;
      case SkillLevel.expert:
        return 4;
      case SkillLevel.mixed:
        return 0; // Special case for mixed
    }
  }
}
