import 'package:dabbler/core/errors/exceptions.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/result_guard.dart';
import 'package:dabbler/data/models/authentication/auth_session.dart';
import 'package:dabbler/data/models/authentication/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  User? _cachedUser;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Result<AuthSession, Failure>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return Err<AuthSession, Failure>(
        const NetworkFailure(message: 'No internet connection'),
      );
    }

    final responseResult = await guardResult(() async {
      try {
        return await remoteDataSource.signInWithEmail(
          email: email,
          password: password,
        );
      } on InvalidCredentialsException {
        throw const AuthFailure(message: 'Invalid credentials');
      } on UnverifiedEmailException {
        throw const AuthFailure(message: 'Email not verified');
      } on NetworkException {
        throw const NetworkFailure(message: 'Network error');
      } on AuthException catch (e) {
        throw AuthFailure(message: e.message);
      }
    });

    if (responseResult.isFailure) {
      return Err(responseResult.requireError);
    }

    final response = responseResult.requireValue;
    _cacheUser(response.user);
    final session = response.session;
    if (session == null) {
      return Err<AuthSession, Failure>(
        const AuthFailure(message: 'No session returned from authentication'),
      );
    }
    return Ok<AuthSession, Failure>(session);
  }

  @override
  Future<Result<AuthSession, Failure>> signInWithPhone({
    required String phone,
  }) async {
    if (!await networkInfo.isConnected) {
      return Err<AuthSession, Failure>(
        const NetworkFailure(message: 'No internet connection'),
      );
    }

    final responseResult = await guardResult(() async {
      try {
        return await remoteDataSource.signInWithPhone(phone: phone);
      } on AuthException catch (e) {
        throw AuthFailure(message: e.message);
      }
    });

    if (responseResult.isFailure) {
      return Err(responseResult.requireError);
    }

    final response = responseResult.requireValue;
    _cacheUser(response.user);
    final session = response.session;
    if (session == null) {
      return Err<AuthSession, Failure>(
        const AuthFailure(message: 'No session returned from authentication'),
      );
    }
    return Ok<AuthSession, Failure>(session);
  }

  @override
  Future<Result<AuthSession, Failure>> signUp({
    required String email,
    required String password,
  }) async {
    if (!await networkInfo.isConnected) {
      return Err<AuthSession, Failure>(
        const NetworkFailure(message: 'No internet connection'),
      );
    }

    final responseResult = await guardResult(() async {
      try {
        return await remoteDataSource.signUp(email: email, password: password);
      } on EmailAlreadyExistsException {
        throw const ConflictFailure(message: 'Email already exists');
      } on WeakPasswordException {
        throw const ValidationFailure(message: 'Password is too weak');
      } on AuthException catch (e) {
        throw AuthFailure(message: e.message);
      }
    });

    if (responseResult.isFailure) {
      return Err(responseResult.requireError);
    }

    final response = responseResult.requireValue;
    _cacheUser(response.user);
    final session = response.session;
    if (session == null) {
      return Err<AuthSession, Failure>(
        const AuthFailure(message: 'No session returned from authentication'),
      );
    }
    return Ok<AuthSession, Failure>(session);
  }

  @override
  Future<Result<void, Failure>> signOut() async {
    final result = await guardResult<void>(() async {
      await remoteDataSource.signOut();
      _cachedUser = null;
    });
    return result;
  }

  @override
  Future<Result<User, Failure>> getCurrentUser() async {
    if (_cachedUser != null) {
      return Ok<User, Failure>(_cachedUser!);
    }

    final userResult = await guardResult(() async {
      try {
        return await remoteDataSource.getCurrentUser();
      } on AuthException catch (e) {
        throw AuthFailure(message: e.message);
      }
    });

    if (userResult.isFailure) {
      return Err(userResult.requireError);
    }

    final user = userResult.requireValue as User;
    _cacheUser(user);
    return Ok<User, Failure>(user);
  }

  @override
  Future<Result<AuthSession, Failure>> getCurrentSession() async {
    final sessionResult = await guardResult(() async {
      try {
        return await remoteDataSource.getCurrentSession();
      } on AuthException catch (e) {
        throw AuthFailure(message: e.message);
      }
    });

    if (sessionResult.isFailure) {
      return Err(sessionResult.requireError);
    }

    final response = sessionResult.requireValue;
    final session = response.session;
    if (session == null) {
      return Err<AuthSession, Failure>(
        const AuthFailure(message: 'No active session'),
      );
    }
    return Ok<AuthSession, Failure>(session);
  }

  @override
  Future<Result<void, Failure>> resetPassword({required String email}) async {
    return guardResult<void>(() async {
      try {
        await remoteDataSource.resetPassword(email: email);
      } on AuthException catch (e) {
        throw AuthFailure(message: e.message);
      }
    });
  }

  @override
  Future<Result<void, Failure>> updatePassword({
    required String newPassword,
  }) async {
    return guardResult<void>(() async {
      try {
        await remoteDataSource.updatePassword(newPassword: newPassword);
      } on WeakPasswordException {
        throw const ValidationFailure(message: 'Password is too weak');
      } on AuthException catch (e) {
        throw AuthFailure(message: e.message);
      }
    });
  }

  @override
  Future<Result<AuthSession, Failure>> verifyOTP({
    required String phone,
    required String token,
  }) async {
    final responseResult = await guardResult(() async {
      try {
        return await remoteDataSource.verifyOTP(phone: phone, token: token);
      } on AuthException catch (e) {
        throw AuthFailure(message: e.message);
      }
    });

    if (responseResult.isFailure) {
      return Err(responseResult.requireError);
    }

    final response = responseResult.requireValue;
    _cacheUser(response.user);
    final session = response.session;
    if (session == null) {
      return Err<AuthSession, Failure>(
        const AuthFailure(message: 'OTP verification failed: no session'),
      );
    }
    return Ok<AuthSession, Failure>(session);
  }

  void _cacheUser(User? user) {
    if (user != null) {
      _cachedUser = user;
    }
  }
}
