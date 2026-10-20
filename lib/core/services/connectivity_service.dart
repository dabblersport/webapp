import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';

/// Am I online (KAN-603): the one source of truth.
///
/// - [offline]: the OS reports no connection.
/// - [poor]: the OS says connected, but a request recently timed out or failed
///   with no-internet (Wi-Fi with a dead uplink, a very bad link).
/// - [online]: connected and nothing recently failed.
enum ConnectionStatus { online, offline, poor }

/// How long a failed request keeps the state at [ConnectionStatus.poor] unless
/// a request succeeds first.
final Duration kPoorConnectionWindow = DabblerMotion.timeoutNetwork * 6;

/// Reads connectivity and classifies it. No UI: screens decide what to show.
class ConnectivityNotifier extends StateNotifier<ConnectionStatus> {
  ConnectivityNotifier({
    Stream<List<ConnectivityResult>>? changes,
    Future<List<ConnectivityResult>> Function()? check,
    DateTime Function()? now,
    Duration? poorWindow,
  }) : _now = now ?? DateTime.now,
       _poorWindow = poorWindow ?? kPoorConnectionWindow,
       _check = check ?? (() => Connectivity().checkConnectivity()),
       super(ConnectionStatus.online) {
    _sub = (changes ?? Connectivity().onConnectivityChanged).listen(
      _onOsChange,
      onError: (Object _) {},
    );
    unawaited(_initial());
  }

  final DateTime Function() _now;
  final Duration _poorWindow;
  final Future<List<ConnectivityResult>> Function() _check;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  final StreamController<void> _reconnects = StreamController<void>.broadcast();
  bool _osConnected = true;
  DateTime? _lastFailure;
  Timer? _poorTimer;

  /// Fires each time the connection comes back after being offline.
  Stream<void> get reconnects => _reconnects.stream;

  bool get isOnline => state != ConnectionStatus.offline;

  Future<void> _initial() async {
    try {
      _onOsChange(await _check());
    } catch (_) {
      // Unknown: stay optimistic; requests will report their own failures.
    }
  }

  static bool _connected(List<ConnectivityResult> r) =>
      r.any((ConnectivityResult c) => c != ConnectivityResult.none);

  void _onOsChange(List<ConnectivityResult> results) {
    final bool wasOffline = state == ConnectionStatus.offline;
    _osConnected = _connected(results);
    if (!_osConnected) {
      _poorTimer?.cancel();
      state = ConnectionStatus.offline;
      return;
    }
    state = _recentFailure ? ConnectionStatus.poor : ConnectionStatus.online;
    if (wasOffline) _reconnects.add(null);
  }

  bool get _recentFailure {
    final DateTime? at = _lastFailure;
    return at != null && _now().difference(at) < _poorWindow;
  }

  /// A request failed. A timeout or no-internet while the OS reports a
  /// connection means the link is poor. Other failures (server, auth) say
  /// nothing about the link.
  void reportFailure(Object error) {
    final FailureCode code = error is Failure
        ? error.category
        : classifyError(error);
    if (code != FailureCode.timeout &&
        code != FailureCode.noInternet &&
        code != FailureCode.network) {
      return;
    }
    if (!_osConnected) return;
    _lastFailure = _now();
    state = ConnectionStatus.poor;
    _poorTimer?.cancel();
    _poorTimer = Timer(_poorWindow, () {
      if (state == ConnectionStatus.poor) state = ConnectionStatus.online;
    });
  }

  /// A request succeeded: the link works.
  void reportSuccess() {
    _lastFailure = null;
    _poorTimer?.cancel();
    if (state == ConnectionStatus.poor) state = ConnectionStatus.online;
  }

  @override
  void dispose() {
    _poorTimer?.cancel();
    _sub.cancel();
    _reconnects.close();
    super.dispose();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectionStatus>(
      (ref) => ConnectivityNotifier(),
    );

/// Emits each time the connection returns after being offline.
final connectivityReconnectProvider = StreamProvider<void>((ref) {
  return ref.watch(connectivityProvider.notifier).reconnects;
});
