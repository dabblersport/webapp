import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The location introduction shown after Welcome / Welcome Back (KAN-489).
///
/// The system permission prompt is asked for ONLY when the user taps
/// "Use my location" ([LocationIntroController.useMyLocation]); eligibility
/// and every re-check read the permission without requesting it.

/// The permission seam: reads never prompt, [request] does.
abstract class LocationPermissionGateway {
  Future<LocationPermission> check();
  Future<LocationPermission> request();
  Future<bool> servicesEnabled();

  /// App / browser settings (false where the platform has none).
  Future<bool> openAppSettings();

  /// The device's location-services settings (false where unsupported).
  Future<bool> openLocationSettings();
}

class GeolocatorPermissionGateway implements LocationPermissionGateway {
  const GeolocatorPermissionGateway();

  @override
  Future<LocationPermission> check() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> request() => Geolocator.requestPermission();

  @override
  Future<bool> servicesEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}

bool locationPermissionGranted(LocationPermission p) =>
    p == LocationPermission.whileInUse || p == LocationPermission.always;

/// Remembers, per user on this device, that the introduction was presented.
/// Local only; another account on the device has its own flag.
class LocationIntroStore {
  const LocationIntroStore();

  static String _key(String userId) => 'location_intro_seen_$userId';

  Future<bool> seen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  Future<void> markSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }
}

final locationPermissionGatewayProvider = Provider<LocationPermissionGateway>(
  (ref) => const GeolocatorPermissionGateway(),
);

/// The signed-in user the introduction is recorded for (overridable in tests).
final locationIntroUserIdProvider = Provider<String?>(
  (ref) => Supabase.instance.client.auth.currentUser?.id,
);

final locationIntroStoreProvider = Provider<LocationIntroStore>(
  (ref) => const LocationIntroStore(),
);

/// Whether to show the introduction to [userId] now: never for a signed-out
/// user, never twice, never when the permission is already granted. Reads the
/// permission without requesting it.
Future<bool> shouldShowLocationIntro({
  required String? userId,
  required LocationPermissionGateway gateway,
  required LocationIntroStore store,
}) async {
  if (userId == null || userId.isEmpty) return false;
  if (await store.seen(userId)) return false;
  try {
    if (locationPermissionGranted(await gateway.check())) return false;
  } catch (_) {
    // An unreadable permission must not trap the user: skip the page.
    return false;
  }
  return true;
}

/// What the screen shows.
enum LocationIntroPhase {
  /// The introduction, waiting for the user.
  idle,

  /// A permission / lookup call is in flight (the CTA is busy).
  working,

  /// Permission was refused at the prompt (it can still be asked later).
  denied,

  /// Permission is blocked: only the app / browser settings can change it.
  deniedForever,

  /// The device's location services are off.
  serviceOff,

  /// Permission was granted but the position could not be read in time.
  lookupFailed,

  /// Done: continue to the destination.
  done,
}

class LocationIntroState {
  const LocationIntroState(this.phase, {this.canOpenSettings = false});
  final LocationIntroPhase phase;

  /// Whether a settings action is offered (the platform has one).
  final bool canOpenSettings;
}

typedef LocationLookup = Future<bool> Function();

class LocationIntroController extends StateNotifier<LocationIntroState> {
  LocationIntroController(this._gateway, this._lookup)
    : super(const LocationIntroState(LocationIntroPhase.idle));

  final LocationPermissionGateway _gateway;

  /// Reads the position and applies it to the active location; true when it
  /// worked. Runs only after the permission was granted by the user.
  final LocationLookup _lookup;

  bool _busy = false;

  /// The primary action: the only place the system prompt is requested.
  Future<void> useMyLocation() async {
    if (_busy) return;
    _busy = true;
    state = const LocationIntroState(LocationIntroPhase.working);
    try {
      if (!await _gateway.servicesEnabled()) {
        state = const LocationIntroState(
          LocationIntroPhase.serviceOff,
          canOpenSettings: !kIsWeb,
        );
        return;
      }
      var permission = await _gateway.check();
      if (permission == LocationPermission.denied) {
        permission = await _gateway.request();
      }
      if (permission == LocationPermission.deniedForever) {
        state = const LocationIntroState(
          LocationIntroPhase.deniedForever,
          canOpenSettings: !kIsWeb,
        );
        return;
      }
      if (!locationPermissionGranted(permission)) {
        state = const LocationIntroState(LocationIntroPhase.denied);
        return;
      }
      await _locate();
    } catch (_) {
      // Never block access: carry on without a position.
      state = const LocationIntroState(LocationIntroPhase.lookupFailed);
    } finally {
      _busy = false;
    }
  }

  Future<void> _locate() async {
    final ok = await _lookup();
    state = LocationIntroState(
      ok ? LocationIntroPhase.done : LocationIntroPhase.lookupFailed,
    );
  }

  /// The user came back from the settings app: re-check WITHOUT requesting.
  /// Granted now -> read the position and finish; otherwise the guidance
  /// stays (and nothing is asked again automatically).
  Future<void> recheckAfterSettings() async {
    if (_busy) return;
    final phase = state.phase;
    if (phase != LocationIntroPhase.deniedForever &&
        phase != LocationIntroPhase.serviceOff) {
      return;
    }
    _busy = true;
    try {
      final enabled = await _gateway.servicesEnabled();
      final permission = await _gateway.check();
      if (enabled && locationPermissionGranted(permission)) {
        state = const LocationIntroState(LocationIntroPhase.working);
        await _locate();
      } else if (!enabled) {
        state = const LocationIntroState(
          LocationIntroPhase.serviceOff,
          canOpenSettings: !kIsWeb,
        );
      } else if (permission == LocationPermission.deniedForever) {
        state = const LocationIntroState(
          LocationIntroPhase.deniedForever,
          canOpenSettings: !kIsWeb,
        );
      }
    } catch (_) {
      // Keep the guidance on screen.
    } finally {
      _busy = false;
    }
  }

  /// Opens the settings the guidance points at (app / browser settings for a
  /// blocked permission, the device's location settings when services are off).
  Future<void> openSettings() async {
    if (state.phase == LocationIntroPhase.serviceOff) {
      await _gateway.openLocationSettings();
    } else {
      await _gateway.openAppSettings();
    }
  }
}

/// The controller as the screen uses it: a successful position is applied to
/// the active location through the existing notifier.
final locationIntroControllerProvider =
    StateNotifierProvider.autoDispose<
      LocationIntroController,
      LocationIntroState
    >((ref) {
      return LocationIntroController(
        ref.watch(locationPermissionGatewayProvider),
        () async {
          final notifier = ref.read(activeLocationProvider.notifier);
          await notifier.useGpsLocation();
          return ref.read(activeLocationProvider).valueOrNull
              is ActiveLocationReady;
        },
      );
    });
