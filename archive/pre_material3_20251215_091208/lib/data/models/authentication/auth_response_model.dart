import 'package:meta/meta.dart';
import 'package:dabbler/data/models/authentication/auth_session.dart';
import 'package:dabbler/data/models/authentication/user.dart';
import 'user_model.dart';

@immutable
class AuthResponseModel {
  final UserModel? user;
  final AuthSession? session;
  final String? error;
  final Map<String, dynamic>? metadata;

  const AuthResponseModel({this.user, this.session, this.error, this.metadata});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      session: json['session'] != null
          ? AuthSession(
              accessToken: json['session']['access_token'] as String,
              refreshToken: json['session']['refresh_token'] as String,
              expiresAt: DateTime.fromMillisecondsSinceEpoch(
                (json['session']['expires_at'] as int) * 1000,
              ),
              user: json['user'] != null
                  ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
                        as User
                  : User(
                      id: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
            )
          : null,
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'user': user?.toJson(),
    'session': session != null
        ? {
            'access_token': session!.accessToken,
            'refresh_token': session!.refreshToken,
            'expires_at': session!.expiresAt.millisecondsSinceEpoch ~/ 1000,
            'user': user?.toJson(),
          }
        : null,
    'error': error,
    'metadata': metadata,
  };
}
