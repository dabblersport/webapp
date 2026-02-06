import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/authentication/auth_session.dart';
import '../repositories/auth_repository.dart';
import 'usecase.dart';

class RegisterUseCase
    extends UseCase<Result<AuthSession, Failure>, RegisterParams> {
  final AuthRepository repository;
  RegisterUseCase(this.repository);

  @override
  Future<Result<AuthSession, Failure>> call(RegisterParams params) async {
    if (params.email.isEmpty || params.password.isEmpty) {
      return Err<AuthSession, Failure>(
        const AuthFailure(message: 'Email and password must not be empty'),
      );
    }
    return repository.signUp(email: params.email, password: params.password);
  }
}

class RegisterParams {
  final String email;
  final String password;
  RegisterParams({required this.email, required this.password});
}
