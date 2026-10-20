import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-603: online / offline / poor, and the reconnect event. No UI.
void main() {
  late StreamController<List<ConnectivityResult>> os;
  late DateTime clock;
  late ConnectivityNotifier n;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> make({
    List<ConnectivityResult> initial = const [ConnectivityResult.wifi],
    Duration window = const Duration(seconds: 60),
  }) async {
    os = StreamController<List<ConnectivityResult>>.broadcast();
    clock = DateTime(2026, 10, 20, 12);
    n = ConnectivityNotifier(
      changes: os.stream,
      check: () async => initial,
      now: () => clock,
      poorWindow: window,
    );
    addTearDown(() {
      n.dispose();
      os.close();
    });
    await settle();
  }

  test('online when the OS reports a connection', () async {
    await make();
    expect(n.state, ConnectionStatus.online);
    expect(n.isOnline, isTrue);
  });

  test('offline when the OS reports none, at start and later', () async {
    await make(initial: [ConnectivityResult.none]);
    expect(n.state, ConnectionStatus.offline);
    os.add([ConnectivityResult.wifi]);
    await settle();
    expect(n.state, ConnectionStatus.online);
    os.add([ConnectivityResult.none]);
    await settle();
    expect(n.state, ConnectionStatus.offline);
  });

  test('a reconnect event fires when the connection returns', () async {
    await make(initial: [ConnectivityResult.none]);
    var events = 0;
    final sub = n.reconnects.listen((_) => events++);
    addTearDown(sub.cancel);
    os.add([ConnectivityResult.mobile]);
    await settle();
    expect(events, 1);
    // A change between two connected states is not a reconnect.
    os.add([ConnectivityResult.wifi]);
    await settle();
    expect(events, 1);
  });

  test('poor: a timeout or no-internet while the OS says connected', () async {
    await make();
    n.reportFailure(TimeoutException('x'));
    expect(n.state, ConnectionStatus.poor);
    n.reportSuccess();
    expect(n.state, ConnectionStatus.online);
    n.reportFailure(const SocketException('x'));
    expect(n.state, ConnectionStatus.poor);
    n.reportSuccess();
    n.reportFailure(const NetworkFailure());
    expect(n.state, ConnectionStatus.poor);
  });

  test('a server or auth failure says nothing about the link', () async {
    await make();
    n.reportFailure(const ServerFailure());
    expect(n.state, ConnectionStatus.online);
    n.reportFailure(const UnauthenticatedFailure());
    expect(n.state, ConnectionStatus.online);
  });

  test('offline stays offline: a failure does not turn it into poor', () async {
    await make(initial: [ConnectivityResult.none]);
    n.reportFailure(TimeoutException('x'));
    expect(n.state, ConnectionStatus.offline);
  });

  test('poor ends after its window', () async {
    await make(window: const Duration(milliseconds: 30));
    n.reportFailure(TimeoutException('x'));
    expect(n.state, ConnectionStatus.poor);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(n.state, ConnectionStatus.online);
  });

  test('poor survives an OS change to another connected network', () async {
    await make();
    n.reportFailure(TimeoutException('x'));
    os.add([ConnectivityResult.mobile]);
    await settle();
    expect(n.state, ConnectionStatus.poor);
  });

  test('the provider is exported from lib/providers.dart', () {
    final src = File('lib/providers.dart').readAsStringSync();
    expect(src, contains('core/services/connectivity_service.dart'));
  });
}
