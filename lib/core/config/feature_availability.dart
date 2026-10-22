import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart'
    show selectedLocationProvider;

/// Remote feature availability by service region (KAN-585).
///
/// The server decides per account service region (KAN-584, chosen by the user,
/// never GPS, VPN or IP) through `get_feature_availability()`. The app side:
///
///   effective = compile-time flag AND remote value
///
/// Remote config can only switch a feature off, never on: a compile-time-off
/// feature stays off, and an id the app does not know is off. A missing id, an
/// RPC error, being offline or signed out keeps the last good cached value,
/// else the compile-time default, so an available feature is never silently
/// disabled. Fetched on sign-in, app start and service-region change; no
/// polling.

/// The stable feature ids and their compile-time flags. An id is never renamed
/// or reused. The four compile-time-off flags (`early_bird_check_in`,
/// `data_export`, `payments`, `community_mobile_nav`) are reserved and not
/// listed: they are off and stay off here.
const Map<String, bool> kFeatureCompileDefaults = <String, bool>{
  'meetups': FeatureFlags.enableMeetups,
  'favourites': FeatureFlags.enableFavourites,
  'game_browsing': FeatureFlags.enableGameBrowsing,
  'player_game_creation': FeatureFlags.enablePlayerGameCreation,
  'organiser_game_creation': FeatureFlags.enableOrganiserGameCreation,
  'player_game_joining': FeatureFlags.enablePlayerGameJoining,
  'organiser_game_joining': FeatureFlags.enableOrganiserGameJoining,
  'social_feed': FeatureFlags.socialFeed,
  'messaging': FeatureFlags.messaging,
  'messaging_game_chat': FeatureFlags.enableMessagingGameChat,
  'messaging_direct': FeatureFlags.enableMessagingDirect,
  'messaging_reporting': FeatureFlags.enableMessagingReporting,
  'messaging_realtime': FeatureFlags.messagingRealtime,
  'notifications': FeatureFlags.notifications,
  'multi_sport': FeatureFlags.multiSport,
  'organiser_profile': FeatureFlags.organiserProfile,
  'venues_booking': FeatureFlags.venuesBooking,
  'booking_flow': FeatureFlags.enableBookingFlow,
};

/// The one evaluation rule. [remote] holds only the ids the server returned.
bool evaluateFeature(
  String featureId,
  Map<String, bool> remote, {
  Map<String, bool> compile = kFeatureCompileDefaults,
}) {
  final bool? compiled = compile[featureId];
  if (compiled == null || !compiled) return false;
  return remote[featureId] ?? true;
}

/// Reads the signed-in account's availability. Throws on any failure so the
/// caller keeps its last good value.
abstract class FeatureAvailabilityRemote {
  Future<Map<String, bool>> fetch();
}

class SupabaseFeatureAvailabilityRemote implements FeatureAvailabilityRemote {
  static const String rpc = 'get_feature_availability';

  @override
  Future<Map<String, bool>> fetch() async {
    final dynamic rows = await Supabase.instance.client.rpc(rpc);
    final Map<String, bool> out = <String, bool>{};
    if (rows is List) {
      for (final dynamic row in rows) {
        if (row is Map &&
            row['feature_id'] is String &&
            row['enabled'] is bool) {
          out[row['feature_id'] as String] = row['enabled'] as bool;
        }
      }
    }
    return out;
  }
}

/// The last good remote values, kept on the device.
abstract class FeatureAvailabilityCache {
  Future<Map<String, bool>> read();
  Future<void> write(Map<String, bool> values);
}

class PrefsFeatureAvailabilityCache implements FeatureAvailabilityCache {
  static const String key = 'feature_availability.last_good';

  @override
  Future<Map<String, bool>> read() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(key);
      if (raw == null) return <String, bool>{};
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, bool>{};
      return <String, bool>{
        for (final MapEntry<dynamic, dynamic> e in decoded.entries)
          if (e.key is String && e.value is bool)
            e.key as String: e.value as bool,
      };
    } catch (_) {
      return <String, bool>{};
    }
  }

  @override
  Future<void> write(Map<String, bool> values) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(values));
    } catch (_) {
      // Best effort: the in-memory value still applies.
    }
  }
}

/// Holds the remote values (only what the server said) and refreshes them.
class FeatureAvailabilityNotifier extends StateNotifier<Map<String, bool>> {
  FeatureAvailabilityNotifier({
    required String? userId,
    required FeatureAvailabilityRemote remote,
    required FeatureAvailabilityCache cache,
  }) : _userId = userId,
       _remote = remote,
       _cache = cache,
       super(const <String, bool>{}) {
    _load();
  }

  final String? _userId;
  final FeatureAvailabilityRemote _remote;
  final FeatureAvailabilityCache _cache;
  bool _disposed = false;

  Future<void> _load() async {
    final Map<String, bool> cached = await _cache.read();
    if (_disposed) return;
    if (cached.isNotEmpty) state = cached;
    await refresh();
  }

  /// Fetches the account's values. Signed out: nothing to ask, keep what is
  /// held. Any failure keeps the last good value.
  Future<void> refresh() async {
    if (_userId == null) return;
    try {
      final Map<String, bool> fetched = await _remote.fetch();
      if (_disposed) return;
      // An id the server did not return keeps its last good value.
      final Map<String, bool> merged = <String, bool>{...state, ...fetched};
      state = merged;
      await _cache.write(merged);
    } catch (_) {
      // Offline, RPC error or an old backend: keep the last good value.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final featureAvailabilityRemoteProvider = Provider<FeatureAvailabilityRemote>(
  (ref) => SupabaseFeatureAvailabilityRemote(),
);

final featureAvailabilityCacheProvider = Provider<FeatureAvailabilityCache>(
  (ref) => PrefsFeatureAvailabilityCache(),
);

/// Rebuilt, and so refetched, on sign-in, sign-out and service-region change.
final featureAvailabilityProvider =
    StateNotifierProvider<FeatureAvailabilityNotifier, Map<String, bool>>((
      ref,
    ) {
      final String? userId = ref.watch(currentUserIdProvider);
      ref.watch(selectedLocationProvider.select((l) => l.valueOrNull?.country));
      return FeatureAvailabilityNotifier(
        userId: userId,
        remote: ref.watch(featureAvailabilityRemoteProvider),
        cache: ref.watch(featureAvailabilityCacheProvider),
      );
    });

/// Whether [featureId] is available to this account right now.
final featureEnabledProvider = Provider.family<bool, String>(
  (ref, featureId) =>
      evaluateFeature(featureId, ref.watch(featureAvailabilityProvider)),
);
