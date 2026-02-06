import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:dabbler/data/models/authentication/user.dart';
import 'package:dabbler/data/models/authentication/auth_session.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'package:dabbler/core/services/auth_service.dart';

class AuthState {
  final User? user;
  final AuthSession? session;
  final bool isLoading;
  final String? error;
  const AuthState({
    this.user,
    this.session,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null && session != null;
  AuthState copyWith({
    User? user,
    AuthSession? session,
    bool? isLoading,
    String? error,
  }) => AuthState(
    user: user ?? this.user,
    session: session ?? this.session,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class AuthController extends StateNotifier<AuthState> {
  final GetCurrentUserUseCase getCurrentUser;
  late final StreamSubscription<supa.AuthState> _authSub;

  AuthController({required this.getCurrentUser}) : super(const AuthState()) {
    _init();
    // Listen to Supabase auth changes to keep session & user in sync
    _authSub = supa.Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final event = data.event;
      final session = data.session;
      // Debug
      // print('[AuthController] Auth event: $event session=${session != null}');
      if (event == supa.AuthChangeEvent.signedIn ||
          event == supa.AuthChangeEvent.tokenRefreshed ||
          event == supa.AuthChangeEvent.userUpdated) {
        final supaUser =
            session?.user ?? supa.Supabase.instance.client.auth.currentUser;
        if (supaUser != null) {
          // Map Supabase user to domain user via repository call (reuse getCurrentUser)
          final userResult = await getCurrentUser(NoParams());
          userResult.fold((_) {}, (user) {
            state = state.copyWith(
              user: user,
              session: session != null
                  ? _convertSession(session, user)
                  : state.session,
              isLoading: false,
              error: null,
            );
          });
        }
      }
      if (event == supa.AuthChangeEvent.signedOut) {
        state = const AuthState();
      }
    });
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    // Fetch current user
    final userResult = await getCurrentUser(NoParams());
    userResult.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (user) async {
        // Try to also fetch current session so isAuthenticated can become true
        final supaSession = supa.Supabase.instance.client.auth.currentSession;
        if (supaSession != null) {
          state = state.copyWith(
            user: user,
            session: _convertSession(supaSession, user),
            isLoading: false,
            error: null,
          );
        } else {
          state = state.copyWith(user: user, isLoading: false, error: null);
        }
      },
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await AuthService().signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh authentication state (useful after signup/signin)
  Future<void> refreshAuthState() async {
    await _init();
  }

  AuthSession _convertSession(supa.Session session, User user) {
    return AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (session.expiresAt ?? 0) * 1000,
      ),
      user: user,
    );
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
