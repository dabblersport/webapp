import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/bench/data/bench_repository.dart';
import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which write last ran.
enum BenchAction { save, end }

/// The bench write state: what is in flight, and what last failed.
class BenchActionState {
  const BenchActionState({this.submitting, this.failedAction, this.failure});

  /// The write in flight, if any.
  final BenchAction? submitting;

  /// The write that last failed, cleared by the next attempt.
  final BenchAction? failedAction;
  final Failure? failure;

  bool get isSubmitting => submitting != null;
}

/// Runs the bench writes. Every success calls [onWritten], which invalidates
/// the status provider (KAN-706 behaviour 8). Never throws.
class BenchController extends StateNotifier<BenchActionState> {
  BenchController({required this.repository, required this.onWritten})
    : super(const BenchActionState());

  final BenchRepository repository;
  final void Function() onWritten;

  BenchSettings? _lastSettings;

  /// The settings of the last save, for a retry.
  BenchSettings? get lastSettings => _lastSettings;

  /// Starts a bench, or saves an edit (the toggle-bench RPC, benched true).
  Future<bool> save(BenchSettings settings) {
    _lastSettings = settings;
    return _run(BenchAction.save, () => repository.save(settings));
  }

  /// Ends the bench (end-bench RPC).
  Future<bool> end() => _run(BenchAction.end, repository.end);

  /// Clears a shown failure.
  void clearFailure() {
    if (state.failure != null) state = const BenchActionState();
  }

  Future<bool> _run(
    BenchAction action,
    Future<Result<Unit, Failure>> Function() write,
  ) async {
    if (state.isSubmitting) return false;
    state = BenchActionState(submitting: action);
    final result = await write();
    if (!mounted) return false;
    return result.fold(
      (failure) {
        state = BenchActionState(failedAction: action, failure: failure);
        return false;
      },
      (_) {
        state = const BenchActionState();
        onWritten();
        return true;
      },
    );
  }
}
