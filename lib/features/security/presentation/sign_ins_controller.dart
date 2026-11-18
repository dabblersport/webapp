// KAN-1003 (W2-F6): the viewer's sign-in ledger and the one answer in
// flight. Both screens (review, list) read it. A refusal is returned and the
// row stays as the server has it; a second tap while a call runs is dropped.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/security/data/security_repository.dart';
import 'package:dabbler/features/security/domain/security_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class SignInsState {
  const SignInsState({
    this.rows,
    this.loading = true,
    this.loadFailure,
    this.busyId,
  });

  final List<SecuritySignIn>? rows;
  final bool loading;
  final Failure? loadFailure;

  /// The sign-in whose answer is in flight.
  final String? busyId;

  SecuritySignIn? byId(String id) {
    for (final r in rows ?? const <SecuritySignIn>[]) {
      if (r.id == id) return r;
    }
    return null;
  }

  SignInsState copyWith({
    List<SecuritySignIn>? rows,
    bool? loading,
    Failure? loadFailure,
    String? busyId,
    bool clearBusy = false,
  }) => SignInsState(
    rows: rows ?? this.rows,
    loading: loading ?? this.loading,
    loadFailure: loadFailure,
    busyId: clearBusy ? null : (busyId ?? this.busyId),
  );
}

class SignInsController extends StateNotifier<SignInsState> {
  SignInsController(this._repo) : super(const SignInsState()) {
    load();
  }

  final SecurityRepository _repo;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final r = await _repo.signIns();
    if (!mounted) return;
    r.fold(
      (f) => state = state.copyWith(loading: false, loadFailure: f),
      (rows) => state = state.copyWith(loading: false, rows: rows),
    );
  }

  /// "This was me". Null on success; the failure otherwise (`busy` when
  /// dropped as a second tap).
  Future<Failure?> confirm(String id) =>
      _answer(id, () => _repo.confirm(id), SignInState.confirmed);

  /// "Not me" / Sign out: that one device only.
  Future<Failure?> notMe(String id) =>
      _answer(id, () => _repo.notMe(id), SignInState.secured);

  Future<Failure?> _answer(
    String id,
    Future<Result<void, Failure>> Function() call,
    SignInState done,
  ) async {
    if (state.busyId != null) return const Failure(code: 'busy');
    state = state.copyWith(busyId: id);
    final r = await call();
    if (!mounted) return null;
    return r.fold(
      (f) {
        state = state.copyWith(clearBusy: true);
        // The row moved on elsewhere: read it again.
        if (f.code == '22023' || f.code == 'P0002') load();
        return f;
      },
      (_) {
        state = state.copyWith(
          clearBusy: true,
          rows: [
            for (final row in state.rows ?? const <SecuritySignIn>[])
              row.id == id
                  ? row.copyWith(
                      state: done,
                      isActive: done == SignInState.secured
                          ? false
                          : row.isActive,
                    )
                  : row,
          ],
        );
        return null;
      },
    );
  }
}

final signInsProvider =
    StateNotifierProvider.autoDispose<SignInsController, SignInsState>(
      (ref) => SignInsController(ref.watch(securityRepositoryProvider)),
    );
