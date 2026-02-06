import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/authentication/user.dart';
import '../repositories/auth_repository.dart';
import 'usecase.dart';

class GetCurrentUserUseCase extends UseCase<Result<User, Failure>, NoParams> {
  final AuthRepository repository;
  GetCurrentUserUseCase(this.repository);

  @override
  Future<Result<User, Failure>> call(NoParams params) {
    return repository.getCurrentUser();
  }
}
