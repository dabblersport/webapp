import 'package:meta/meta.dart';
import 'user.dart';

@immutable
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final User user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  bool get isValid => DateTime.now().isBefore(expiresAt);

  Duration get remainingTime => expiresAt.difference(DateTime.now());

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    User? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      user: user ?? this.user,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          expiresAt == other.expiresAt &&
          user == other.user;

  @override
  int get hashCode =>
      accessToken.hashCode ^
      refreshToken.hashCode ^
      expiresAt.hashCode ^
      user.hashCode;

  @override
  String toString() {
    return 'AuthSession(accessToken: $accessToken, refreshToken: $refreshToken, expiresAt: $expiresAt, user: $user)';
  }
}
