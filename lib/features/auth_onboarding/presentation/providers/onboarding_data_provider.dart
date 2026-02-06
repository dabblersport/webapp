import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds temporary onboarding data during registration flow
/// Data is cleared after successful account creation
class OnboardingData {
  final String? email;
  final String? phone;
  final String? displayName;
  final int? age;
  final String? gender;
  final String? intention; // organise, compete, social
  final String? preferredSport; // single sport (required)
  final List<String>? interests; // up to 3 sports (optional)
  final String? username;

  OnboardingData({
    this.email,
    this.phone,
    this.displayName,
    this.age,
    this.gender,
    this.intention,
    this.preferredSport,
    this.interests,
    this.username,
  }) : assert(
         email != null || phone != null,
         'Either email or phone must be provided',
       );

  OnboardingData copyWith({
    String? email,
    String? phone,
    String? displayName,
    int? age,
    String? gender,
    String? intention,
    String? preferredSport,
    List<String>? interests,
    String? username,
  }) {
    return OnboardingData(
      email: email ?? this.email,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      intention: intention ?? this.intention,
      preferredSport: preferredSport ?? this.preferredSport,
      interests: interests ?? this.interests,
      username: username ?? this.username,
    );
  }

  /// Convert to Map for passing via GoRouter extra
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'displayName': displayName,
      'age': age,
      'gender': gender,
      'intention': intention,
      'preferredSport': preferredSport,
      'interests': interests,
      'username': username,
    };
  }

  /// Create from Map for receiving via GoRouter extra
  static OnboardingData fromMap(Map<String, dynamic> map) {
    return OnboardingData(
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      displayName: map['displayName'] as String?,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      intention: map['intention'] as String?,
      preferredSport: map['preferredSport'] as String?,
      interests: map['interests'] != null
          ? List<String>.from(map['interests'] as List)
          : null,
      username: map['username'] as String?,
    );
  }

  /// Check if user info screen is complete
  bool get hasUserInfo =>
      displayName != null && age != null && age! >= 16 && gender != null;

  /// Check if intention is selected
  bool get hasIntention => intention != null;

  /// Check if sports are selected
  bool get hasSports => preferredSport != null;

  /// Check if username is set
  bool get hasUsername => username != null && username!.isNotEmpty;

  /// Check if all onboarding data is complete (except password)
  bool get isComplete =>
      hasUserInfo && hasIntention && hasSports && hasUsername;

  /// Get profile_type based on intention
  /// organise -> organiser, compete/social -> player
  String get profileType {
    if (intention == 'organise') return 'organiser';
    return 'player';
  }

  /// Get interests as comma-separated string for database
  String? get interestsString {
    if (interests == null || interests!.isEmpty) return null;
    return interests!.join(',');
  }
}

/// StateNotifier to manage onboarding data
class OnboardingDataNotifier extends StateNotifier<OnboardingData?> {
  OnboardingDataNotifier() : super(null);

  /// Initialize with email
  void initWithEmail(String email) {
    state = OnboardingData(email: email);
  }

  /// Initialize with phone
  void initWithPhone(String phone) {
    state = OnboardingData(phone: phone);
  }

  /// Update user info (Screen 1)
  void setUserInfo({
    required String displayName,
    required int age,
    required String gender,
  }) {
    if (state == null) return;
    state = state!.copyWith(displayName: displayName, age: age, gender: gender);
  }

  /// Update intention (Screen 2)
  void setIntention(String intention) {
    if (state == null) return;
    state = state!.copyWith(intention: intention);
  }

  /// Update sports (Screen 3)
  void setSports({required String preferredSport, List<String>? interests}) {
    if (state == null) return;
    state = state!.copyWith(
      preferredSport: preferredSport,
      interests: interests,
    );
  }

  /// Update username (Screen 4)
  void setUsername(String username) {
    if (state == null) return;
    state = state!.copyWith(username: username);
  }

  /// Clear all data (after successful registration or cancellation)
  void clear() {
    state = null;
  }

  /// Load from map (when navigating back or restoring state)
  void loadFromMap(Map<String, dynamic> map) {
    state = OnboardingData.fromMap(map);
  }
}

/// Provider for onboarding data
final onboardingDataProvider =
    StateNotifierProvider<OnboardingDataNotifier, OnboardingData?>(
      (ref) => OnboardingDataNotifier(),
    );
