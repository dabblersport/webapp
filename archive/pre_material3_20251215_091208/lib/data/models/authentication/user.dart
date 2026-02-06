import 'package:meta/meta.dart';

@immutable
class User {
  final String id;
  final String? email;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final String? phoneNumber;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isProfileComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    this.email,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.phoneNumber,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.isProfileComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get needsProfileCompletion => !isProfileComplete;

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? phoneNumber,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    bool? isProfileComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          username == other.username &&
          fullName == other.fullName &&
          avatarUrl == other.avatarUrl &&
          phoneNumber == other.phoneNumber &&
          isEmailVerified == other.isEmailVerified &&
          isPhoneVerified == other.isPhoneVerified &&
          isProfileComplete == other.isProfileComplete &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      (email?.hashCode ?? 0) ^
      (username?.hashCode ?? 0) ^
      (fullName?.hashCode ?? 0) ^
      (avatarUrl?.hashCode ?? 0) ^
      (phoneNumber?.hashCode ?? 0) ^
      isEmailVerified.hashCode ^
      isPhoneVerified.hashCode ^
      isProfileComplete.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'User(id: $id, email: $email, username: $username, fullName: $fullName, avatarUrl: $avatarUrl, phoneNumber: $phoneNumber, isEmailVerified: $isEmailVerified, isPhoneVerified: $isPhoneVerified, isProfileComplete: $isProfileComplete, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
