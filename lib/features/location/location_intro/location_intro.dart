import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dabbler/core/services/location_permission_state.dart';
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
  Future<LocationPermission> request() => LocationPermissionState.requestOnce(
    request: () => Geolocator.requestPermission(),
    current: () => Geolocator.checkPermission(),
  );

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
final locationIntroUserIdProvider = Provider.autoDispose<String?>(
  (ref) => Supabase.instance.client.auth.currentUser?.id,
);

final locationIntroStoreProvider = Provider<LocationIntroStore>(
  (ref) => const LocationIntroStore(),
);

/// Why the introduction is shown or skipped (logged, so a skip is explainable).
enum LocationIntroDecision {
  show,
  skipNoUser,
  skipAlreadySeen,
  skipPermissionGranted,
}

/// Decides whether to show the introduction to [userId] now: never for a
/// signed-out user, never twice, never when the permission is already granted.
/// Reads the permission without requesting it. A permission that cannot be
/// read (the browser's Permissions API throwing or being unsupported) counts
/// as "not granted": the page is shown, the user can skip it.
Future<LocationIntroDecision> decideLocationIntro({
  required String? userId,
  required LocationPermissionGateway gateway,
  required LocationIntroStore store,
}) async {
  if (userId == null || userId.isEmpty) {
    return LocationIntroDecision.skipNoUser;
  }
  if (await store.seen(userId)) return LocationIntroDecision.skipAlreadySeen;
  try {
    if (locationPermissionGranted(await gateway.check())) {
      return LocationIntroDecision.skipPermissionGranted;
    }
  } catch (_) {
    // Unreadable permission: not granted.
  }
  return LocationIntroDecision.show;
}

Future<bool> shouldShowLocationIntro({
  required String? userId,
  required LocationPermissionGateway gateway,
  required LocationIntroStore store,
}) async {
  final decision = await decideLocationIntro(
    userId: userId,
    gateway: gateway,
    store: store,
  );
  debugPrint('[LocationIntro] ${decision.name}');
  return decision == LocationIntroDecision.show;
}

/// What the screen shows.
enum LocationIntroPhase {
  /// The introduction, waiting for the user.
  idle,

  /// The system permission prompt is up (the user is answering it). Nothing is
  /// shown: no spinner, no banner.
  requesting,

  /// The user answered (or the permission could not be read): continue to the
  /// destination now. Carries the [LocationIntroOutcome].
  done,
}

/// How the permission question ended.
enum LocationIntroOutcome {
  /// Allowed: the position is read afterwards, in the background.
  granted,

  /// Refused at the prompt (it can still be asked for later).
  denied,

  /// Blocked: only the app / browser settings can change it.
  deniedForever,

  /// The device's location services are off.
  serviceOff,

  /// The permission could not be read or asked for.
  unavailable,
}

class LocationIntroState {
  const LocationIntroState(this.phase, {this.outcome});
  final LocationIntroPhase phase;
  final LocationIntroOutcome? outcome;
}

/// Starts the background position lookup (fire and forget: it must never be
/// awaited on the navigation path).
typedef LocationBackgroundLookup = void Function();

class LocationIntroController extends StateNotifier<LocationIntroState> {
  LocationIntroController(this._gateway, this._startBackgroundLookup)
    : super(const LocationIntroState(LocationIntroPhase.idle));

  final LocationPermissionGateway _gateway;

  /// Called once, only when the permission is granted.
  final LocationBackgroundLookup _startBackgroundLookup;

  bool _busy = false;

  /// The primary action: the only place the system prompt is requested. As
  /// soon as the OS answers (any answer) the state is [LocationIntroPhase.done]
  /// so the screen continues at once; a granted permission starts the position
  /// lookup in the background and never waits for it.
  Future<void> useMyLocation() async {
    if (_busy) return;
    _busy = true;
    state = const LocationIntroState(LocationIntroPhase.requesting);
    var outcome = LocationIntroOutcome.unavailable;
    try {
      if (!await _gateway.servicesEnabled()) {
        outcome = LocationIntroOutcome.serviceOff;
      } else {
        var permission = await _gateway.check();
        if (permission == LocationPermission.denied) {
          permission = await _gateway.request();
        }
        if (locationPermissionGranted(permission)) {
          outcome = LocationIntroOutcome.granted;
        } else if (permission == LocationPermission.deniedForever) {
          outcome = LocationIntroOutcome.deniedForever;
        } else if (permission == LocationPermission.denied) {
          outcome = LocationIntroOutcome.denied;
        }
      }
    } catch (_) {
      outcome = LocationIntroOutcome.unavailable;
    }
    if (outcome == LocationIntroOutcome.granted) {
      try {
        _startBackgroundLookup();
      } catch (_) {
        // The lookup is an extra: never block or fail the hand-off.
      }
    }
    state = LocationIntroState(LocationIntroPhase.done, outcome: outcome);
    _busy = false;
  }
}

/// The controller as the screen uses it. A granted permission hands the lookup
/// to the active-location notifier, which lives on after this screen.
final locationIntroControllerProvider =
    StateNotifierProvider.autoDispose<
      LocationIntroController,
      LocationIntroState
    >((ref) {
      return LocationIntroController(
        ref.watch(locationPermissionGatewayProvider),
        () {
          unawaited(
            ref.read(activeLocationProvider.notifier).adoptDeviceLocation(),
          );
        },
      );
    });
