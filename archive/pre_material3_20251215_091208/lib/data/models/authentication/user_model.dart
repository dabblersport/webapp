import 'package:meta/meta.dart';
import 'package:dabbler/data/models/authentication/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

@immutable
class UserModel extends User {
  const UserModel({
    required super.id,
    super.email,
    super.username,
    super.fullName,
    super.avatarUrl,
    super.phoneNumber,
    super.isEmailVerified,
    super.isPhoneVerified,
    super.isProfileComplete,
    required super.createdAt,
    required super.updatedAt,
  });

  // Compatibility getters for legacy UI code expecting these names.
  String get displayName => fullName ?? username ?? email ?? id;
  String? get profileImageUrl => avatarUrl;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      username: json['username'] as String?,
      fullName: json['fullName'] as String? ?? json['full_name'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      phoneNumber:
          json['phoneNumber'] as String? ?? json['phone_number'] as String?,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? false,
      isProfileComplete: json['isProfileComplete'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] ?? json['updated_at'] ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'fullName': fullName,
    'avatarUrl': avatarUrl,
    'phoneNumber': phoneNumber,
    'isEmailVerified': isEmailVerified,
    'isPhoneVerified': isPhoneVerified,
    'isProfileComplete': isProfileComplete,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserModel.fromSupabaseUser(supabase.User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      username: user.userMetadata?['username'] as String?,
      fullName: user.userMetadata?['full_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      phoneNumber: user.phone,
      isEmailVerified: user.emailConfirmedAt != null,
      isPhoneVerified: user.phoneConfirmedAt != null,
      isProfileComplete:
          user.userMetadata?['is_profile_complete'] as bool? ?? false,
      createdAt: user.createdAt is DateTime
          ? user.createdAt as DateTime
          : DateTime.now(),
      updatedAt: user.updatedAt is DateTime
          ? user.updatedAt as DateTime
          : DateTime.now(),
    );
  }
}
