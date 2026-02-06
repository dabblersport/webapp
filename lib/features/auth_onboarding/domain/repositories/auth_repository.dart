import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/authentication/auth_session.dart';
import 'package:dabbler/data/models/authentication/user.dart';

abstract class AuthRepository {
  Future<Result<AuthSession, Failure>> signInWithEmail({
    required String email,
    required String password,
  });
  Future<Result<AuthSession, Failure>> signInWithPhone({required String phone});
  Future<Result<AuthSession, Failure>> signUp({
    required String email,
    required String password,
  });
  Future<Result<void, Failure>> signOut();
  Future<Result<User, Failure>> getCurrentUser();
  Future<Result<AuthSession, Failure>> getCurrentSession();
  Future<Result<void, Failure>> resetPassword({required String email});
  Future<Result<void, Failure>> updatePassword({required String newPassword});
  Future<Result<AuthSession, Failure>> verifyOTP({
    required String phone,
    required String token,
  });
}
