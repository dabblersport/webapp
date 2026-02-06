import 'result.dart';
import 'failure.dart';

/// Guard an async call and convert thrown errors to Failure using Failure.from.
Future<Result<T, Failure>> guardResult<T>(Future<T> Function() body) async {
  try {
    final v = await body();
    return Ok<T, Failure>(v);
  } catch (e, st) {
    if (e is Failure) {
      return Err<T, Failure>(e);
    }
    return Err<T, Failure>(Failure.from(e, st));
  }
}
