import 'dart:async';

/// Lightweight Result type to avoid throwing across boundaries.
abstract class Result<T, E> {
  const Result();
  bool get isSuccess => this is Ok<T, E>;
  bool get isFailure => this is Err<T, E>;

  T get requireValue {
    final self = this;
    if (self is Ok<T, E>) return self.value;
    throw StateError('Tried to read value from Err');
  }

  E get requireError {
    final self = this;
    if (self is Err<T, E>) return self.error;
    throw StateError('Tried to read error from Ok');
  }

  R fold<R>(R Function(E err) onErr, R Function(T val) onOk) => this is Ok<T, E>
      ? onOk((this as Ok<T, E>).value)
      : onErr((this as Err<T, E>).error);

  Result<R, E> map<R>(R Function(T val) f) => this is Ok<T, E>
      ? Ok<R, E>(f((this as Ok<T, E>).value))
      : Err<R, E>((this as Err<T, E>).error);

  Future<Result<R, E>> then<R>(FutureOr<R> Function(T val) f) async =>
      this is Ok<T, E>
      ? Ok<R, E>(await f((this as Ok<T, E>).value))
      : Err<R, E>((this as Err<T, E>).error);

  static Future<Result<T, E>> guard<T, E>(
    Future<T> Function() body,
    E Function(Object error) mapError,
  ) async {
    try {
      return Ok<T, E>(await body());
    } catch (e) {
      return Err<T, E>(mapError(e));
    }
  }
}

class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}

class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);
}

/// Convenience “unit” for side-effect results.
class Unit {
  const Unit();
}

const unit = Unit();

extension ResultConvenience<T, E> on Result<T, E> {
  /// Mirrors legacy Either.match signature where failure handler comes first.
  R match<R>(R Function(E err) onErr, R Function(T val) onOk) =>
      fold(onErr, onOk);

  /// Backwards-compatible aliases for success/failure checks.
  bool get isRight => isSuccess;
  bool get isLeft => isFailure;

  /// Maps the error side while keeping the success value untouched.
  Result<T, R> mapError<R>(R Function(E err) transform) => this is Err<T, E>
      ? Err<T, R>(transform((this as Err<T, E>).error))
      : Ok<T, R>((this as Ok<T, E>).value);
}
