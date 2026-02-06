import 'package:dabbler/data/models/authentication/user_model.dart';
import 'package:dabbler/data/models/authentication/auth_response_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> signInWithEmail({
    required String email,
    required String password,
  });
  Future<AuthResponseModel> signInWithPhone({required String phone});
  Future<AuthResponseModel> signUp({
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<UserModel> getCurrentUser();
  Future<AuthResponseModel> getCurrentSession();
  Future<void> resetPassword({required String email});
  Future<void> updatePassword({required String newPassword});
  Future<AuthResponseModel> verifyOTP({
    required String phone,
    required String token,
  });
}
