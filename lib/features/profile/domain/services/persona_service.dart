import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/persona_rules.dart';

/// Data class representing a user's active persona profile
class ActivePersonaProfile {
  final String profileId;
  final PersonaType personaType;
  final String? displayName;
  final String? username;
  final int? age;
  final String? gender;
  final bool isActive;

  const ActivePersonaProfile({
    required this.profileId,
    required this.personaType,
    this.displayName,
    this.username,
    this.age,
    this.gender,
    this.isActive = true,
  });

  factory ActivePersonaProfile.fromJson(Map<String, dynamic> json) {
    return ActivePersonaProfile(
      profileId: json['id'] as String,
      personaType:
          PersonaType.fromString(json['intention'] as String?) ??
          PersonaType.player,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// State class for persona management
class PersonaState {
  final List<ActivePersonaProfile> activeProfiles;
  final bool isLoading;
  final String? errorMessage;

  const PersonaState({
    this.activeProfiles = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  /// Get the set of active persona types
  Set<PersonaType> get activePersonaTypes =>
      activeProfiles.where((p) => p.isActive).map((p) => p.personaType).toSet();

  /// Get available personas based on current active personas
  List<PersonaAvailability> get availablePersonas =>
      PersonaRules.getAvailablePersonas(currentPersonas: activePersonaTypes);

  /// Get personas that can be directly added
  List<PersonaAvailability> get addOptions =>
      PersonaRules.getAddOptions(currentPersonas: activePersonaTypes);

  /// Get personas that require conversion
  List<PersonaAvailability> get conversionOptions =>
      PersonaRules.getConversionOptions(currentPersonas: activePersonaTypes);

  /// Check if user has any active profiles
  bool get hasAnyProfile => activeProfiles.any((p) => p.isActive);

  /// Count of active profiles (is_active = true)
  int get activeProfileCount => activeProfiles.where((p) => p.isActive).length;

  /// Check if user is at the maximum profile limit (2 active profiles)
  bool get isAtProfileLimit =>
      PersonaRules.isAtProfileLimit(activeProfileCount);

  /// Check if user can add a new profile
  bool get canAddNewProfile =>
      PersonaRules.canAddNewProfile(activeProfileCount);

  /// Get primary (first active) profile for shared data reuse
  ActivePersonaProfile? get primaryProfile =>
      activeProfiles.where((p) => p.isActive).firstOrNull;

  PersonaState copyWith({
    List<ActivePersonaProfile>? activeProfiles,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PersonaState(
      activeProfiles: activeProfiles ?? this.activeProfiles,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// StateNotifier for managing persona state
class PersonaServiceNotifier extends StateNotifier<PersonaState> {
  final SupabaseClient _client;

  PersonaServiceNotifier(this._client) : super(const PersonaState());

  /// Fetch all active profiles for the current user
  Future<void> fetchUserPersonas() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Not authenticated',
        );
        return;
      }

      // Fetch all profiles for this user (can have multiple with different intentions)
      final response = await _client
          .from('profiles')
          .select(
            'id, intention, display_name, username, age, gender, is_active',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final profiles = (response as List)
          .map(
            (json) =>
                ActivePersonaProfile.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();

      state = state.copyWith(activeProfiles: profiles, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch profiles: $e',
      );
    }
  }

  /// Check availability for a specific target persona
  PersonaAvailability checkAvailability(PersonaType targetPersona) {
    return PersonaRules.evaluateAvailability(
      currentPersonas: state.activePersonaTypes,
      targetPersona: targetPersona,
    );
  }

  /// Deactivate a profile (for conversion flow)
  Future<bool> deactivateProfile(String profileId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('profiles')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profileId)
          .eq('user_id', userId);

      // Refresh state
      await fetchUserPersonas();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to deactivate profile: $e');
      return false;
    }
  }
}

/// Provider for PersonaService
final personaServiceProvider =
    StateNotifierProvider<PersonaServiceNotifier, PersonaState>((ref) {
      final client = Supabase.instance.client;
      return PersonaServiceNotifier(client);
    });

/// Provider for available personas (derived from personaServiceProvider)
final availablePersonasProvider = Provider<List<PersonaAvailability>>((ref) {
  final state = ref.watch(personaServiceProvider);
  return state.availablePersonas;
});

/// Provider for add options only
final addPersonaOptionsProvider = Provider<List<PersonaAvailability>>((ref) {
  final state = ref.watch(personaServiceProvider);
  return state.addOptions;
});

/// Provider for conversion options only
final conversionOptionsProvider = Provider<List<PersonaAvailability>>((ref) {
  final state = ref.watch(personaServiceProvider);
  return state.conversionOptions;
});
