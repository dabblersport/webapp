import 'package:flutter/material.dart';

enum GameCreationStep {
  sportAndFormat,
  venueAndSlot,
  playerInvitation,
  participationAndPayment,
  reviewAndConfirm,
}

// Sport-specific format classes
abstract class GameFormat {
  String get name;
  String get description;
  int get totalPlayers;
  int get playersPerSide;
  Duration get defaultDuration;
}

// Football formats
class FootballFormat extends GameFormat {
  final String _name;
  final String _description;
  final int _totalPlayers;
  final int _playersPerSide;
  final Duration _defaultDuration;

  FootballFormat({
    required String name,
    required String description,
    required int totalPlayers,
    required int playersPerSide,
    required Duration defaultDuration,
  }) : _name = name,
       _description = description,
       _totalPlayers = totalPlayers,
       _playersPerSide = playersPerSide,
       _defaultDuration = defaultDuration;

  @override
  String get name => _name;
  @override
  String get description => _description;
  @override
  int get totalPlayers => _totalPlayers;
  @override
  int get playersPerSide => _playersPerSide;
  @override
  Duration get defaultDuration => _defaultDuration;

  static final futsal = FootballFormat(
    name: 'Futsal',
    description: '5 vs 5',
    totalPlayers: 10,
    playersPerSide: 5,
    defaultDuration: const Duration(minutes: 60),
  );

  static final competitive = FootballFormat(
    name: 'Competitive',
    description: '6 vs 6',
    totalPlayers: 12,
    playersPerSide: 6,
    defaultDuration: const Duration(minutes: 75),
  );

  static final substitutional = FootballFormat(
    name: 'Substitutional',
    description: '7 vs 7',
    totalPlayers: 14,
    playersPerSide: 7,
    defaultDuration: const Duration(minutes: 90),
  );

  static final association = FootballFormat(
    name: 'Association',
    description: '11 vs 11',
    totalPlayers: 22,
    playersPerSide: 11,
    defaultDuration: const Duration(minutes: 90),
  );

  static final List<FootballFormat> allFormats = [
    futsal,
    competitive,
    substitutional,
    association,
  ];
}

// Cricket formats
class CricketFormat extends GameFormat {
  final String _name;
  final String _description;
  final int _totalPlayers;
  final int _playersPerSide;
  final Duration _defaultDuration;

  CricketFormat({
    required String name,
    required String description,
    required int totalPlayers,
    required int playersPerSide,
    required Duration defaultDuration,
  }) : _name = name,
       _description = description,
       _totalPlayers = totalPlayers,
       _playersPerSide = playersPerSide,
       _defaultDuration = defaultDuration;

  @override
  String get name => _name;
  @override
  String get description => _description;
  @override
  int get totalPlayers => _totalPlayers;
  @override
  int get playersPerSide => _playersPerSide;
  @override
  Duration get defaultDuration => _defaultDuration;

  static final standard = CricketFormat(
    name: 'Standard',
    description: '11 vs 11',
    totalPlayers: 22,
    playersPerSide: 11,
    defaultDuration: const Duration(hours: 3),
  );

  static final tennisBall = CricketFormat(
    name: 'Tennis Ball',
    description: '8 vs 8',
    totalPlayers: 16,
    playersPerSide: 8,
    defaultDuration: const Duration(hours: 2),
  );

  static final boxCricket = CricketFormat(
    name: 'Box Cricket',
    description: '6 vs 6',
    totalPlayers: 12,
    playersPerSide: 6,
    defaultDuration: const Duration(minutes: 90),
  );

  static final List<CricketFormat> allFormats = [
    standard,
    tennisBall,
    boxCricket,
  ];
}

// Padel formats
class PadelFormat extends GameFormat {
  final String _name;
  final String _description;
  final int _totalPlayers;
  final int _playersPerSide;
  final Duration _defaultDuration;

  PadelFormat({
    required String name,
    required String description,
    required int totalPlayers,
    required int playersPerSide,
    required Duration defaultDuration,
  }) : _name = name,
       _description = description,
       _totalPlayers = totalPlayers,
       _playersPerSide = playersPerSide,
       _defaultDuration = defaultDuration;

  @override
  String get name => _name;
  @override
  String get description => _description;
  @override
  int get totalPlayers => _totalPlayers;
  @override
  int get playersPerSide => _playersPerSide;
  @override
  Duration get defaultDuration => _defaultDuration;

  static final single = PadelFormat(
    name: 'Single',
    description: '1 vs 1',
    totalPlayers: 2,
    playersPerSide: 1,
    defaultDuration: const Duration(minutes: 60),
  );

  static final double = PadelFormat(
    name: 'Double',
    description: '2 vs 2',
    totalPlayers: 4,
    playersPerSide: 2,
    defaultDuration: const Duration(minutes: 90),
  );

  static final List<PadelFormat> allFormats = [single, double];
}

enum ParticipationMode {
  public, // Open to anyone
  private, // Invite only
  hybrid, // Mix of invited and open spots
}

enum PaymentSplit {
  organizer, // Organizer pays everything
  equal, // Split equally among all players
  perPlayer, // Each player pays their share
  custom, // Custom split percentages
}

class TimeSlot {
  final DateTime startTime;
  final Duration duration;
  final double price;
  final bool isAvailable;
  final String? restrictions;

  const TimeSlot({
    required this.startTime,
    required this.duration,
    required this.price,
    this.isAvailable = true,
    this.restrictions,
  });

  DateTime get endTime => startTime.add(duration);

  String get formattedTime {
    final start = TimeOfDay.fromDateTime(startTime);
    final end = TimeOfDay.fromDateTime(endTime);
    return '${start.format24Hour} - ${end.format24Hour}';
  }
}

class VenueSlot {
  final String venueId;
  final String venueName;
  final String location;
  final TimeSlot timeSlot;
  final Map<String, dynamic>? amenities;
  final double rating;
  final String? imageUrl;

  const VenueSlot({
    required this.venueId,
    required this.venueName,
    required this.location,
    required this.timeSlot,
    this.amenities,
    this.rating = 0.0,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'venueId': venueId,
      'venueName': venueName,
      'location': location,
      'timeSlot': {
        'startTime': timeSlot.startTime.toIso8601String(),
        'duration': timeSlot.duration.inMinutes,
        'price': timeSlot.price,
        'isAvailable': timeSlot.isAvailable,
        'restrictions': timeSlot.restrictions,
      },
      'amenities': amenities,
      'rating': rating,
      'imageUrl': imageUrl,
    };
  }
}

class GameCreationModel {
  // Current step
  final GameCreationStep currentStep;

  // Sport & Format Selection
  final String? selectedSport;
  final GameFormat? selectedFormat;
  final String? skillLevel;
  final int? maxPlayers;
  final int? gameDuration; // in minutes
  final String? gameType; // pickup, training, league

  // Venue & Slot Selection
  final VenueSlot? selectedVenueSlot;
  final List<String>? amenityFilters;
  final List<String>? venueFilters;
  final double? maxDistance;

  // Participation & Payment
  final ParticipationMode? participationMode;
  final PaymentSplit? paymentSplit;
  final double? totalCost;
  final Map<String, double>? customPaymentSplit;
  final String? gameDescription;
  final bool? allowWaitlist;
  final int? maxWaitlistSize;
  final bool? allowSpectators;

  // Player Invitation
  final List<String>? invitedPlayerIds;
  final List<String>? invitedPlayerEmails;
  final bool? allowFriendsToInvite;
  final String? invitationMessage;

  // Review & Confirm
  final String? gameTitle;
  final bool? agreeToTerms;
  final bool? sendReminders;
  final DateTime? reminderTime;

  // Draft functionality
  final String? draftId;
  final DateTime? lastSaved;
  final bool isDraft;

  // Step-specific local state for draft resume
  final DateTime? selectedDate;
  final String? selectedTimeSlot;
  final List<String>? selectedPlayers;
  final Map<String, dynamic>? stepLocalState;

  // Computed properties
  final bool isLoading;
  final String? error;

  const GameCreationModel({
    // Current step
    this.currentStep = GameCreationStep.sportAndFormat,

    // Sport & Format Selection
    this.selectedSport,
    this.selectedFormat,
    this.skillLevel,
    this.maxPlayers,
    this.gameDuration,
    this.gameType,

    // Venue & Slot Selection
    this.selectedVenueSlot,
    this.amenityFilters,
    this.venueFilters,
    this.maxDistance,

    // Participation & Payment
    this.participationMode,
    this.paymentSplit,
    this.totalCost,
    this.customPaymentSplit,
    this.gameDescription,
    this.allowWaitlist,
    this.maxWaitlistSize,
    this.allowSpectators,

    // Player Invitation
    this.invitedPlayerIds,
    this.invitedPlayerEmails,
    this.allowFriendsToInvite,
    this.invitationMessage,

    // Review & Confirm
    this.gameTitle,
    this.agreeToTerms,
    this.sendReminders,
    this.reminderTime,

    // Draft functionality
    this.draftId,
    this.lastSaved,
    this.isDraft = false,

    // Step-specific local state for draft resume
    this.selectedDate,
    this.selectedTimeSlot,
    this.selectedPlayers,
    this.stepLocalState,

    // Computed properties
    this.isLoading = false,
    this.error,
  });

  factory GameCreationModel.initial() {
    return const GameCreationModel();
  }

  GameCreationModel copyWith({
    // Current step
    GameCreationStep? currentStep,

    // Sport & Format Selection
    String? selectedSport,
    GameFormat? selectedFormat,
    String? skillLevel,
    int? maxPlayers,
    int? gameDuration,
    String? gameType,

    // Venue & Slot Selection
    VenueSlot? selectedVenueSlot,
    List<String>? amenityFilters,
    List<String>? venueFilters,
    double? maxDistance,

    // Participation & Payment
    ParticipationMode? participationMode,
    PaymentSplit? paymentSplit,
    double? totalCost,
    Map<String, double>? customPaymentSplit,
    String? gameDescription,
    bool? allowWaitlist,
    int? maxWaitlistSize,
    bool? allowSpectators,

    // Player Invitation
    List<String>? invitedPlayerIds,
    List<String>? invitedPlayerEmails,
    bool? allowFriendsToInvite,
    String? invitationMessage,

    // Review & Confirm
    String? gameTitle,
    bool? agreeToTerms,
    bool? sendReminders,
    DateTime? reminderTime,

    // Draft functionality
    String? draftId,
    DateTime? lastSaved,
    bool? isDraft,

    // Step-specific local state for draft resume
    DateTime? selectedDate,
    String? selectedTimeSlot,
    List<String>? selectedPlayers,
    Map<String, dynamic>? stepLocalState,

    // Computed properties
    bool? isLoading,
    String? error,
  }) {
    return GameCreationModel(
      // Current step
      currentStep: currentStep ?? this.currentStep,

      // Sport & Format Selection
      selectedSport: selectedSport ?? this.selectedSport,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      skillLevel: skillLevel ?? this.skillLevel,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      gameDuration: gameDuration ?? this.gameDuration,
      gameType: gameType ?? this.gameType,

      // Venue & Slot Selection
      selectedVenueSlot: selectedVenueSlot ?? this.selectedVenueSlot,
      amenityFilters: amenityFilters ?? this.amenityFilters,
      venueFilters: venueFilters ?? this.venueFilters,
      maxDistance: maxDistance ?? this.maxDistance,

      // Participation & Payment
      participationMode: participationMode ?? this.participationMode,
      paymentSplit: paymentSplit ?? this.paymentSplit,
      totalCost: totalCost ?? this.totalCost,
      customPaymentSplit: customPaymentSplit ?? this.customPaymentSplit,
      gameDescription: gameDescription ?? this.gameDescription,
      allowWaitlist: allowWaitlist ?? this.allowWaitlist,
      maxWaitlistSize: maxWaitlistSize ?? this.maxWaitlistSize,
      allowSpectators: allowSpectators ?? this.allowSpectators,

      // Player Invitation
      invitedPlayerIds: invitedPlayerIds ?? this.invitedPlayerIds,
      invitedPlayerEmails: invitedPlayerEmails ?? this.invitedPlayerEmails,
      allowFriendsToInvite: allowFriendsToInvite ?? this.allowFriendsToInvite,
      invitationMessage: invitationMessage ?? this.invitationMessage,

      // Review & Confirm
      gameTitle: gameTitle ?? this.gameTitle,
      agreeToTerms: agreeToTerms ?? this.agreeToTerms,
      sendReminders: sendReminders ?? this.sendReminders,
      reminderTime: reminderTime ?? this.reminderTime,

      // Draft functionality
      draftId: draftId ?? this.draftId,
      lastSaved: lastSaved ?? this.lastSaved,
      isDraft: isDraft ?? this.isDraft,

      // Step-specific local state for draft resume
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTimeSlot: selectedTimeSlot ?? this.selectedTimeSlot,
      selectedPlayers: selectedPlayers ?? this.selectedPlayers,
      stepLocalState: stepLocalState ?? this.stepLocalState,

      // Computed properties
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Navigation helpers
  GameCreationStep? get nextStep {
    switch (currentStep) {
      case GameCreationStep.sportAndFormat:
        return GameCreationStep.venueAndSlot;
      case GameCreationStep.venueAndSlot:
        return GameCreationStep.playerInvitation;
      case GameCreationStep.playerInvitation:
        return GameCreationStep.participationAndPayment;
      case GameCreationStep.participationAndPayment:
        return GameCreationStep.reviewAndConfirm;
      case GameCreationStep.reviewAndConfirm:
        return null;
    }
  }

  GameCreationStep? get previousStep {
    switch (currentStep) {
      case GameCreationStep.sportAndFormat:
        return null;
      case GameCreationStep.venueAndSlot:
        return GameCreationStep.sportAndFormat;
      case GameCreationStep.playerInvitation:
        return GameCreationStep.venueAndSlot;
      case GameCreationStep.participationAndPayment:
        return GameCreationStep.playerInvitation;
      case GameCreationStep.reviewAndConfirm:
        return GameCreationStep.participationAndPayment;
    }
  }

  double get progress {
    switch (currentStep) {
      case GameCreationStep.sportAndFormat:
        return 0.2;
      case GameCreationStep.venueAndSlot:
        return 0.4;
      case GameCreationStep.playerInvitation:
        return 0.6;
      case GameCreationStep.participationAndPayment:
        return 0.8;
      case GameCreationStep.reviewAndConfirm:
        return 1.0;
    }
  }

  int get stepIndex {
    return GameCreationStep.values.indexOf(currentStep);
  }

  int get totalSteps => GameCreationStep.values.length;

  String get stepTitle {
    switch (currentStep) {
      case GameCreationStep.sportAndFormat:
        return 'Sport & Format';
      case GameCreationStep.venueAndSlot:
        return 'Venue & Time';
      case GameCreationStep.playerInvitation:
        return 'Invite Players';
      case GameCreationStep.participationAndPayment:
        return 'Payment Settings';
      case GameCreationStep.reviewAndConfirm:
        return 'Review & Create';
    }
  }

  // Validation helpers
  bool get isStep1Valid =>
      selectedSport != null &&
      selectedFormat != null &&
      gameType != null &&
      skillLevel != null &&
      maxPlayers != null &&
      selectedDate != null &&
      selectedTimeSlot != null &&
      gameDuration != null;
  bool get isStep2Valid => selectedVenueSlot != null;
  bool get isStep3Valid => true; // Player invitation is optional
  bool get isStep4Valid => participationMode != null && paymentSplit != null;
  bool get isStep5Valid =>
      agreeToTerms == true && gameTitle?.isNotEmpty == true;

  bool get canProceedToNextStep {
    switch (currentStep) {
      case GameCreationStep.sportAndFormat:
        return isStep1Valid;
      case GameCreationStep.venueAndSlot:
        return isStep2Valid;
      case GameCreationStep.playerInvitation:
        return isStep3Valid;
      case GameCreationStep.participationAndPayment:
        return isStep4Valid;
      case GameCreationStep.reviewAndConfirm:
        return isStep5Valid;
    }
  }

  /// Returns a list of missing required fields for the current step
  List<String> getMissingRequiredFields() {
    switch (currentStep) {
      case GameCreationStep.sportAndFormat:
        final missing = <String>[];
        if (selectedSport == null) missing.add('Sport');
        if (selectedFormat == null) missing.add('Match Format');
        if (gameType == null) missing.add('Game Type');
        if (skillLevel == null) missing.add('Skill Level');
        if (maxPlayers == null) missing.add('Player Count');
        if (selectedDate == null) missing.add('Date');
        if (selectedTimeSlot == null) missing.add('Time Slot');
        if (gameDuration == null) missing.add('Game Duration');
        return missing;
      case GameCreationStep.venueAndSlot:
        if (selectedVenueSlot == null) return ['Venue'];
        return [];
      case GameCreationStep.playerInvitation:
        return []; // Optional step
      case GameCreationStep.participationAndPayment:
        final missing = <String>[];
        if (participationMode == null) missing.add('Participation Mode');
        if (paymentSplit == null) missing.add('Payment Split');
        return missing;
      case GameCreationStep.reviewAndConfirm:
        final missing = <String>[];
        if (gameTitle == null || gameTitle!.isEmpty) missing.add('Game Title');
        if (agreeToTerms != true) missing.add('Terms Agreement');
        return missing;
    }
  }

  bool get canSaveAsDraft {
    // Can save as draft if at least sport is selected
    return selectedSport != null;
  }

  Map<String, dynamic> toJson() {
    return {
      'currentStep': currentStep.name,
      'selectedSport': selectedSport,
      'selectedFormat': selectedFormat?.name,
      'skillLevel': skillLevel,
      'maxPlayers': maxPlayers,
      'gameDuration': gameDuration,
      'gameType': gameType,
      'selectedVenueSlot': selectedVenueSlot?.toJson(),
      'amenityFilters': amenityFilters,
      'participationMode': participationMode?.name,
      'paymentSplit': paymentSplit?.name,
      'gameDescription': gameDescription,
      'allowWaitlist': allowWaitlist,
      'maxWaitlistSize': maxWaitlistSize,
      'allowSpectators': allowSpectators,
      'invitedPlayerIds': invitedPlayerIds,
      'invitedPlayerEmails': invitedPlayerEmails,
      'allowFriendsToInvite': allowFriendsToInvite,
      'invitationMessage': invitationMessage,
      'gameTitle': gameTitle,
      'agreeToTerms': agreeToTerms,
      'sendReminders': sendReminders,
      'isLoading': isLoading,
      'error': error,
      'totalCost': totalCost,
      'draftId': draftId,
      'lastSaved': lastSaved?.toIso8601String(),
      'isDraft': isDraft,
      // Step-specific local state for draft resume
      'selectedDate': selectedDate?.toIso8601String(),
      'selectedTimeSlot': selectedTimeSlot,
      'selectedPlayers': selectedPlayers,
      'stepLocalState': stepLocalState,
    };
  }

  @override
  String toString() {
    return 'GameCreationModel(currentStep: $currentStep, sport: $selectedSport, format: ${selectedFormat?.name})';
  }
}

// Extension for TimeOfDay formatting
extension TimeOfDayFormat on TimeOfDay {
  String get format24Hour {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
