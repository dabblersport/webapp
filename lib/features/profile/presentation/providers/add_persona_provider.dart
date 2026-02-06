import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/persona_rules.dart';

/// Data class for add persona flow
/// Holds the data being collected during the "Add Profile" flow from Settings
class AddPersonaData {
  final PersonaType targetPersona;
  final PersonaActionType actionType;
  final PersonaType? convertFrom;

  // Data collection fields
  final List<String>? interests; // up to 3 sports
  final String? primarySport; // single primary sport
  final String? displayName;
  final String? username;

  // Shared from existing profile (reused, not collected again)
  final int? age;
  final String? gender;
  final String?
  existingProfileId; // for conversion: the profile being deactivated

  const AddPersonaData({
    required this.targetPersona,
    required this.actionType,
    this.convertFrom,
    this.interests,
    this.primarySport,
    this.displayName,
    this.username,
    this.age,
    this.gender,
    this.existingProfileId,
  });

  AddPersonaData copyWith({
    PersonaType? targetPersona,
    PersonaActionType? actionType,
    PersonaType? convertFrom,
    List<String>? interests,
    String? primarySport,
    String? displayName,
    String? username,
    int? age,
    String? gender,
    String? existingProfileId,
  }) {
    return AddPersonaData(
      targetPersona: targetPersona ?? this.targetPersona,
      actionType: actionType ?? this.actionType,
      convertFrom: convertFrom ?? this.convertFrom,
      interests: interests ?? this.interests,
      primarySport: primarySport ?? this.primarySport,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      existingProfileId: existingProfileId ?? this.existingProfileId,
    );
  }

  /// Check if sports data is complete
  bool get hasSportsData => primarySport != null && primarySport!.isNotEmpty;

  /// Check if identity data is complete (display name and username)
  bool get hasIdentityData =>
      displayName != null &&
      displayName!.isNotEmpty &&
      username != null &&
      username!.isNotEmpty;

  /// Check if all required data is collected
  bool get isComplete => hasSportsData && hasIdentityData;

  /// Whether this is a conversion flow
  bool get isConversion => actionType == PersonaActionType.convert;

  /// Convert to Map for passing via GoRouter extra
  Map<String, dynamic> toMap() {
    return {
      'targetPersona': targetPersona.name,
      'actionType': actionType.name,
      'convertFrom': convertFrom?.name,
      'interests': interests,
      'primarySport': primarySport,
      'displayName': displayName,
      'username': username,
      'age': age,
      'gender': gender,
      'existingProfileId': existingProfileId,
    };
  }

  /// Create from Map (for restoring from GoRouter extra)
  static AddPersonaData fromMap(Map<String, dynamic> map) {
    return AddPersonaData(
      targetPersona:
          PersonaType.fromString(map['targetPersona'] as String?) ??
          PersonaType.player,
      actionType: PersonaActionType.values.firstWhere(
        (e) => e.name == map['actionType'],
        orElse: () => PersonaActionType.add,
      ),
      convertFrom: map['convertFrom'] != null
          ? PersonaType.fromString(map['convertFrom'] as String?)
          : null,
      interests: map['interests'] != null
          ? List<String>.from(map['interests'] as List)
          : null,
      primarySport: map['primarySport'] as String?,
      displayName: map['displayName'] as String?,
      username: map['username'] as String?,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      existingProfileId: map['existingProfileId'] as String?,
    );
  }
}

/// StateNotifier for managing add persona flow data
class AddPersonaDataNotifier extends StateNotifier<AddPersonaData?> {
  AddPersonaDataNotifier() : super(null);

  /// Initialize the add persona flow
  void init({
    required PersonaType targetPersona,
    required PersonaActionType actionType,
    PersonaType? convertFrom,
    int? age,
    String? gender,
    String? existingProfileId,
  }) {
    state = AddPersonaData(
      targetPersona: targetPersona,
      actionType: actionType,
      convertFrom: convertFrom,
      age: age,
      gender: gender,
      existingProfileId: existingProfileId,
    );
  }

  /// Update sports data (interests screen)
  void setInterests(List<String> interests) {
    if (state == null) return;
    state = state!.copyWith(interests: interests);
  }

  /// Update primary sport (primary sport screen)
  void setPrimarySport(String sport) {
    if (state == null) return;
    state = state!.copyWith(primarySport: sport);
  }

  /// Update identity data (set username screen)
  void setIdentity({required String displayName, required String username}) {
    if (state == null) return;
    state = state!.copyWith(displayName: displayName, username: username);
  }

  /// Clear all data (after completion or cancellation)
  void clear() {
    state = null;
  }

  /// Load from map (when navigating back)
  void loadFromMap(Map<String, dynamic> map) {
    state = AddPersonaData.fromMap(map);
  }
}

/// Provider for add persona data
final addPersonaDataProvider =
    StateNotifierProvider<AddPersonaDataNotifier, AddPersonaData?>((ref) {
      return AddPersonaDataNotifier();
    });
