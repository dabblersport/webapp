import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

/// The longest the app waits on a call that can hang it (KAN-603): launch
/// theme hydration, the startup bootstrap, the router profile check, sign-out
/// network calls and shared Supabase data calls. 15 s is long enough for a
/// slow mobile connection and short enough that a dead network (Wi-Fi up, no
/// data) never looks like a frozen app. No measurement argued for another
/// value.
///
/// Expressed from the design system's network-timeout token (10 s) so the app
/// has one timing vocabulary: 1.5 x that token is 15 s.
final Duration kRequestTimeout = DabblerMotion.timeoutNetwork * 1.5;

/// The startup splash gives up on the bootstrap after this long (KAN-603).
/// The bootstrap contains one bounded wait of [kRequestTimeout] (theme
/// hydration), so the backstop outlives it by a grace period; it fires only if
/// something else in the bootstrap hangs.
final Duration kStartupBackstop =
    kRequestTimeout + DabblerMotion.timeoutNetwork * 0.5;

/// Runs [body] and gives up after [timeout]: the result is an [Err] whose
/// failure is a [TimeoutFailure] (category timeout), distinct from no-internet.
/// Any other error is classified by [Failure.from].
Future<Result<T, Failure>> guardWithTimeout<T>(
  Future<T> Function() body, {
  Duration? timeout,
}) {
  return Result.guard<T, Failure>(
    () => body().timeout(timeout ?? kRequestTimeout),
    (Object error) => error is TimeoutException
        ? TimeoutFailure(message: 'The request timed out', cause: error)
        : Failure.from(error),
  );
}
