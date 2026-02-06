/// Persona types supported by the application
/// Maps directly to database `persona_type` values
enum PersonaType {
  player,
  organiser,
  hoster,
  socialiser;

  String get displayName {
    switch (this) {
      case PersonaType.player:
        return 'Player';
      case PersonaType.organiser:
        return 'Organiser';
      case PersonaType.hoster:
        return 'Hoster';
      case PersonaType.socialiser:
        return 'Socialiser';
    }
  }

  String get description {
    switch (this) {
      case PersonaType.player:
        return 'Find and join games in your area';
      case PersonaType.organiser:
        return 'Create and manage sports events';
      case PersonaType.hoster:
        return 'List your venue for sports activities';
      case PersonaType.socialiser:
        return 'Connect with other sports enthusiasts';
    }
  }

  /// Convert from database string value
  static PersonaType? fromString(String? value) {
    if (value == null) return null;
    return PersonaType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PersonaType.player,
    );
  }
}

/// Result of persona rule evaluation
enum PersonaActionType {
  /// Can add this persona alongside existing ones
  add,

  /// Must convert from current persona (deactivate old, create new)
  convert,

  /// Cannot have this persona with current setup
  forbidden,

  /// Already has this persona
  alreadyActive,
}

/// Describes what action is available for a target persona
class PersonaAvailability {
  final PersonaType targetPersona;
  final PersonaActionType actionType;
  final PersonaType? convertFrom; // Only set when actionType == convert
  final String? reason; // Human-readable explanation

  const PersonaAvailability({
    required this.targetPersona,
    required this.actionType,
    this.convertFrom,
    this.reason,
  });

  bool get canProceed =>
      actionType == PersonaActionType.add ||
      actionType == PersonaActionType.convert;
}

/// Core business rules for persona coexistence and transitions
///
/// PROFILE LIMIT RULE:
/// - A user can have at most 2 active profiles at any time
/// - This rule has higher priority than persona coexistence rules
///
/// ADD RULES:
/// - player ↔ organiser: Can coexist (user can be both)
/// - hoster ↔ socialiser: Can coexist (user can be both)
///
/// CONVERSION RULES:
/// - socialiser → player: Conversion allowed (deactivate socialiser profile, create player)
/// - socialiser → organiser: Conversion allowed (deactivate socialiser profile, create organiser)
///
/// ABSOLUTE FORBIDDEN STATES (never allowed):
/// - player + socialiser
/// - organiser + socialiser
/// - player + hoster
/// - organiser + hoster
class PersonaRules {
  /// Maximum number of active profiles a user can have
  static const int maxActiveProfiles = 2;

  /// Message shown when user is at profile limit
  static const String profileLimitMessage =
      'You can have up to 2 profiles. To create a new one, deactivate an existing profile.';

  /// Check if user is at the maximum active profile limit
  static bool isAtProfileLimit(int activeProfileCount) {
    return activeProfileCount >= maxActiveProfiles;
  }

  /// Check if user can add a new profile (not at limit)
  static bool canAddNewProfile(int activeProfileCount) {
    return activeProfileCount < maxActiveProfiles;
  }

  /// Personas that can coexist together
  static const Map<PersonaType, Set<PersonaType>> _coexistenceRules = {
    PersonaType.player: {PersonaType.organiser},
    PersonaType.organiser: {PersonaType.player},
    PersonaType.hoster: {PersonaType.socialiser},
    PersonaType.socialiser: {PersonaType.hoster},
  };

  /// Valid conversion paths (from → to)
  static const Map<PersonaType, Set<PersonaType>> _conversionPaths = {
    PersonaType.socialiser: {PersonaType.player, PersonaType.organiser},
  };

  /// Absolutely forbidden combinations (never allowed to coexist)
  static const List<Set<PersonaType>> _forbiddenCombinations = [
    {PersonaType.player, PersonaType.socialiser},
    {PersonaType.organiser, PersonaType.socialiser},
    {PersonaType.player, PersonaType.hoster},
    {PersonaType.organiser, PersonaType.hoster},
  ];

  /// Check if two personas can coexist
  static bool canCoexist(PersonaType a, PersonaType b) {
    if (a == b) return true; // Same persona
    return _coexistenceRules[a]?.contains(b) ?? false;
  }

  /// Check if user can convert from one persona to another
  static bool canConvert(PersonaType from, PersonaType to) {
    return _conversionPaths[from]?.contains(to) ?? false;
  }

  /// Check if a combination is absolutely forbidden
  static bool isForbiddenCombination(Set<PersonaType> personas) {
    for (final forbidden in _forbiddenCombinations) {
      if (forbidden.difference(personas).isEmpty &&
          personas.difference(forbidden).isEmpty) {
        // Exact match
        return true;
      }
      // Check if personas contains the forbidden combination
      if (forbidden.every((p) => personas.contains(p))) {
        return true;
      }
    }
    return false;
  }

  /// Evaluate what action is available for a target persona given current active personas
  ///
  /// [currentPersonas] - Set of currently active persona types for the user
  /// [targetPersona] - The persona the user wants to add/become
  static PersonaAvailability evaluateAvailability({
    required Set<PersonaType> currentPersonas,
    required PersonaType targetPersona,
  }) {
    // Already has this persona
    if (currentPersonas.contains(targetPersona)) {
      return PersonaAvailability(
        targetPersona: targetPersona,
        actionType: PersonaActionType.alreadyActive,
        reason: 'You already have a ${targetPersona.displayName} profile',
      );
    }

    // Check if adding would create a forbidden combination
    final potentialCombination = {...currentPersonas, targetPersona};
    if (isForbiddenCombination(potentialCombination)) {
      // Check if conversion is possible
      for (final current in currentPersonas) {
        if (canConvert(current, targetPersona)) {
          return PersonaAvailability(
            targetPersona: targetPersona,
            actionType: PersonaActionType.convert,
            convertFrom: current,
            reason:
                'Convert from ${current.displayName} to ${targetPersona.displayName}',
          );
        }
      }

      // No conversion path - forbidden
      return PersonaAvailability(
        targetPersona: targetPersona,
        actionType: PersonaActionType.forbidden,
        reason:
            '${targetPersona.displayName} cannot be added with your current profile',
      );
    }

    // Check if target can coexist with all current personas
    final canAddDirectly =
        currentPersonas.isEmpty ||
        currentPersonas.every((current) => canCoexist(current, targetPersona));

    if (canAddDirectly) {
      return PersonaAvailability(
        targetPersona: targetPersona,
        actionType: PersonaActionType.add,
        reason: 'Add ${targetPersona.displayName} profile',
      );
    }

    // Check conversion paths
    for (final current in currentPersonas) {
      if (canConvert(current, targetPersona)) {
        return PersonaAvailability(
          targetPersona: targetPersona,
          actionType: PersonaActionType.convert,
          convertFrom: current,
          reason:
              'Convert from ${current.displayName} to ${targetPersona.displayName}',
        );
      }
    }

    // Default to forbidden
    return PersonaAvailability(
      targetPersona: targetPersona,
      actionType: PersonaActionType.forbidden,
      reason:
          '${targetPersona.displayName} cannot be combined with your current profile',
    );
  }

  /// Get all personas available to add/convert for a user
  ///
  /// Returns only personas that are:
  /// - Not already active
  /// - Either can be added OR can be converted to
  ///
  /// Forbidden personas are NOT returned (hidden from UI)
  static List<PersonaAvailability> getAvailablePersonas({
    required Set<PersonaType> currentPersonas,
  }) {
    final results = <PersonaAvailability>[];

    for (final persona in PersonaType.values) {
      final availability = evaluateAvailability(
        currentPersonas: currentPersonas,
        targetPersona: persona,
      );

      // Only include if action is possible (add or convert)
      // Skip already active and forbidden
      if (availability.canProceed) {
        results.add(availability);
      }
    }

    return results;
  }

  /// Get personas that require conversion (for UI distinction)
  static List<PersonaAvailability> getConversionOptions({
    required Set<PersonaType> currentPersonas,
  }) {
    return getAvailablePersonas(
      currentPersonas: currentPersonas,
    ).where((a) => a.actionType == PersonaActionType.convert).toList();
  }

  /// Get personas that can be directly added (for UI distinction)
  static List<PersonaAvailability> getAddOptions({
    required Set<PersonaType> currentPersonas,
  }) {
    return getAvailablePersonas(
      currentPersonas: currentPersonas,
    ).where((a) => a.actionType == PersonaActionType.add).toList();
  }
}
