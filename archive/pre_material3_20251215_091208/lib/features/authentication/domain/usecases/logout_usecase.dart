import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import '../repositories/auth_repository.dart';
import 'usecase.dart';

class LogoutUseCase extends UseCase<Result<void, Failure>, NoParams> {
  final AuthRepository repository;
  LogoutUseCase(this.repository);

  @override
  Future<Result<void, Failure>> call(NoParams params) {
    return repository.signOut();
  }
}
