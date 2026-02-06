import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/register_usecase.dart';
import 'package:dabbler/data/models/authentication/auth_session.dart';
import 'package:dabbler/data/models/authentication/user.dart';

class RegisterFormState {
  final String email;
  final String password;
  final bool isLoading;
  final String? error;
  final AuthSession? session;
  final User? user;
  const RegisterFormState({
    this.email = '',
    this.password = '',
    this.isLoading = false,
    this.error,
    this.session,
    this.user,
  });

  RegisterFormState copyWith({
    String? email,
    String? password,
    bool? isLoading,
    String? error,
    AuthSession? session,
    User? user,
  }) => RegisterFormState(
    email: email ?? this.email,
    password: password ?? this.password,
    isLoading: isLoading ?? this.isLoading,
    error: error,
    session: session ?? this.session,
    user: user ?? this.user,
  );
}

class RegisterController extends StateNotifier<RegisterFormState> {
  final RegisterUseCase registerUseCase;
  RegisterController(this.registerUseCase) : super(const RegisterFormState());

  Future<void> register() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await registerUseCase(
      RegisterParams(email: state.email, password: state.password),
    );
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (session) => state = state.copyWith(
        isLoading: false,
        session: session,
        error: null,
      ),
    );
  }

  void updateEmail(String email) => state = state.copyWith(email: email);
  void updatePassword(String password) =>
      state = state.copyWith(password: password);
}
