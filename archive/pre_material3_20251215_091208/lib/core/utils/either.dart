/// A discriminated union that represents a value that can be either a failure (Left) or a success (Right).
/// This is commonly used for error handling in functional programming.
abstract class Either<L, R> {
  const Either();

  /// Returns true if this is a Left (failure) instance
  bool get isLeft => this is Left<L, R>;

  /// Returns true if this is a Right (success) instance
  bool get isRight => this is Right<L, R>;

  /// Transforms the right value using the provided function
  Either<L, T> map<T>(T Function(R) f) {
    if (this is Left<L, R>) {
      return Left((this as Left<L, R>).value);
    } else {
      return Right(f((this as Right<L, R>).value));
    }
  }

  /// Transforms the left value using the provided function
  Either<T, R> mapLeft<T>(T Function(L) f) {
    if (this is Left<L, R>) {
      return Left(f((this as Left<L, R>).value));
    } else {
      return Right((this as Right<L, R>).value);
    }
  }

  /// Transforms the right value using a function that returns an Either
  Either<L, T> flatMap<T>(Either<L, T> Function(R) f) {
    if (this is Left<L, R>) {
      return Left((this as Left<L, R>).value);
    } else {
      return f((this as Right<L, R>).value);
    }
  }

  /// Executes one of the provided functions based on whether this is Left or Right
  T fold<T>(T Function(L) leftFn, T Function(R) rightFn) {
    if (this is Left<L, R>) {
      return leftFn((this as Left<L, R>).value);
    } else {
      return rightFn((this as Right<L, R>).value);
    }
  }

  /// Returns the right value if this is Right, otherwise returns the provided default value
  R getOrElse(R Function() defaultValue) {
    if (this is Right<L, R>) {
      return (this as Right<L, R>).value;
    } else {
      return defaultValue();
    }
  }

  /// Returns the right value if this is Right, otherwise throws an exception with the left value
  R getOrThrow() {
    if (this is Right<L, R>) {
      return (this as Right<L, R>).value;
    } else {
      final leftValue = (this as Left<L, R>).value;
      if (leftValue is Exception) {
        throw leftValue;
      } else if (leftValue is Error) {
        throw leftValue;
      } else {
        throw Exception(leftValue.toString());
      }
    }
  }

  /// Returns the left value if this is Left, otherwise returns null
  L? leftOrNull() {
    if (this is Left<L, R>) {
      return (this as Left<L, R>).value;
    }
    return null;
  }

  /// Returns the right value if this is Right, otherwise returns null
  R? rightOrNull() {
    if (this is Right<L, R>) {
      return (this as Right<L, R>).value;
    }
    return null;
  }
}

/// Represents a failure (left) value in an Either
class Left<L, R> extends Either<L, R> {
  final L value;

  const Left(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Left<L, R> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Left($value)';
}

/// Represents a success (right) value in an Either
class Right<L, R> extends Either<L, R> {
  final R value;

  const Right(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Right<L, R> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Right($value)';
}

/// Extension methods for Either to provide additional utility functions
extension EitherExtensions<L, R> on Either<L, R> {
  /// Swaps Left and Right
  Either<R, L> swap() {
    if (this is Left<L, R>) {
      return Right((this as Left<L, R>).value);
    } else {
      return Left((this as Right<L, R>).value);
    }
  }

  /// Executes the provided function if this is Right, ignoring the result
  void forEach(void Function(R) f) {
    if (this is Right<L, R>) {
      f((this as Right<L, R>).value);
    }
  }

  /// Executes the provided function if this is Left, ignoring the result
  void forEachLeft(void Function(L) f) {
    if (this is Left<L, R>) {
      f((this as Left<L, R>).value);
    }
  }
}

/// Utility functions for working with Either
class EitherUtils {
  /// Creates a Left value
  static Either<L, R> left<L, R>(L value) => Left(value);

  /// Creates a Right value
  static Either<L, R> right<L, R>(R value) => Right(value);

  /// Tries to execute a function and returns Either based on whether it throws or not
  static Either<Exception, T> tryCatch<T>(T Function() fn) {
    try {
      return Right(fn());
    } catch (e) {
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Tries to execute an async function and returns Either based on whether it throws or not
  static Future<Either<Exception, T>> tryCatchAsync<T>(
    Future<T> Function() fn,
  ) async {
    try {
      final result = await fn();
      return Right(result);
    } catch (e) {
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Combines a list of Either values, returning Right with all values if all are Right,
  /// or Left with the first failure encountered
  static Either<L, List<R>> sequence<L, R>(List<Either<L, R>> eithers) {
    final results = <R>[];
    for (final either in eithers) {
      if (either is Left<L, R>) {
        return Left(either.value);
      } else {
        results.add((either as Right<L, R>).value);
      }
    }
    return Right(results);
  }

  /// Traverses a list of values, applying a function that returns Either to each,
  /// and returns Either of a list if all succeed, or the first failure
  static Either<L, List<R>> traverse<L, R, T>(
    List<T> values,
    Either<L, R> Function(T) f,
  ) {
    final results = <R>[];
    for (final value in values) {
      final either = f(value);
      if (either is Left<L, R>) {
        return Left(either.value);
      } else {
        results.add((either as Right<L, R>).value);
      }
    }
    return Right(results);
  }
}
