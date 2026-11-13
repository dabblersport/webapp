import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dabbler/core/services/connectivity_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A [ConnectivityNotifier] that already holds [status] when it is built, so a
/// test never waits for the first OS read, and touches no plugin.
class _FixedConnectivity extends ConnectivityNotifier {
  _FixedConnectivity(ConnectionStatus status)
    : super(
        changes: const Stream<List<ConnectivityResult>>.empty(),
        check: () async => <ConnectivityResult>[
          status == ConnectionStatus.offline
              ? ConnectivityResult.none
              : ConnectivityResult.wifi,
        ],
      ) {
    state = status;
  }
}

/// KAN-612: the composers refuse Create while the device is offline, so they
/// read [connectivityProvider]. A test that does not care overrides it with
/// [onlineConnectivity] (no plugin is touched); the offline tests use
/// [offlineConnectivity].
Override onlineConnectivity() => connectivityProvider.overrideWith(
  (ref) => _FixedConnectivity(ConnectionStatus.online),
);

/// The OS reports no connection: Create is refused up front.
Override offlineConnectivity() => connectivityProvider.overrideWith(
  (ref) => _FixedConnectivity(ConnectionStatus.offline),
);
