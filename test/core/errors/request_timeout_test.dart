import 'dart:async';

import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the documented default is 15 seconds', () {
    expect(kRequestTimeout, const Duration(seconds: 15));
    expect(kStartupBackstop, const Duration(seconds: 20));
    expect(kStartupBackstop, greaterThan(kRequestTimeout));
  });

  test('a call that hangs returns the timeout classification', () async {
    final r = await guardWithTimeout<int>(
      () => Completer<int>().future,
      timeout: const Duration(milliseconds: 20),
    );
    expect(r, isA<Err<int, Failure>>());
    final f = (r as Err<int, Failure>).error;
    expect(f, isA<TimeoutFailure>());
    expect(f.category, FailureCode.timeout);
  });

  test('a fast call returns its value', () async {
    final r = await guardWithTimeout<int>(() async => 7);
    expect((r as Ok<int, Failure>).value, 7);
  });

  test('another error is classified, not reported as a timeout', () async {
    final r = await guardWithTimeout<int>(() async => throw StateError('x'));
    expect((r as Err<int, Failure>).error.category, FailureCode.unknown);
  });
}
