import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'image_cache_service.dart';

/// Lightweight cache for user profiles with offline support and background sync.
class ProfileCacheService {
  static final ProfileCacheService _instance = ProfileCacheService._internal();
  factory ProfileCacheService() => _instance;
  ProfileCacheService._internal() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) {
      _tryBackgroundSync();
    });
  }

  // Keys
  static const String _ownProfileKey = 'profile:me';
  static const String _recentProfilesKey = 'profile:recent';
  static const int _maxRecent = 25;
  static const Duration _staleWhileRevalidate = Duration(minutes: 10);

  final SupabaseClient _supabase = Supabase.instance.client;
  final Connectivity _connectivity = Connectivity();
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  final Map<String, Future<Map<String, dynamic>?>> _inFlight = {};

  // Public API
  Future<Map<String, dynamic>?> getOwnProfile({
    List<String> fields = const [
      'id',
      'name',
      'email',
      'avatar_url',
      'updated_at',
      'age',
      'gender',
      'sports',
      'intent',
    ],
    bool preferCache = true,
    bool revalidate = true,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfileById(
      userId,
      fields: fields,
      cacheKeyOverride: _ownProfileKey,
      preferCache: preferCache,
      revalidate: revalidate,
    );
  }

  Future<Map<String, dynamic>?> getProfileById(
    String userId, {
    List<String> fields = const [
      'id',
      'name',
      'email',
      'avatar_url',
      'updated_at',
    ],
    String? cacheKeyOverride,
    bool preferCache = true,
    bool revalidate = true,
  }) async {
    final cacheKey = cacheKeyOverride ?? 'profile:$userId';
    final cached = await _readCache(cacheKey);

    // Serve cache if preferred and exists
    if (preferCache && cached != null) {
      // Trigger background revalidation if stale
      if (revalidate && _isStale(cached)) {
        unawaited(_fetchAndUpdate(userId, fields: fields, cacheKey: cacheKey));
      }
      _rememberRecent(cacheKey, cached);
      return cached['data'] as Map<String, dynamic>;
    }

    // De-duplicate concurrent loads
    if (_inFlight.containsKey(cacheKey)) return _inFlight[cacheKey]!;
    final completer = Completer<Map<String, dynamic>?>();
    _inFlight[cacheKey] = completer.future;

    try {
      final fresh = await _fetchAndUpdate(
        userId,
        fields: fields,
        cacheKey: cacheKey,
      );
      completer.complete(fresh);
    } catch (e) {
      // On failure, fall back to cache
      if (cached != null) {
        completer.complete(cached['data'] as Map<String, dynamic>);
      } else {
        completer.complete(null);
      }
    } finally {
      _inFlight.remove(cacheKey);
    }
    return completer.future;
  }

  Future<void> updateProfilePartial(
    String userId,
    Map<String, dynamic> partial, {
    String? cacheKeyOverride,
  }) async {
    final cacheKey =
        cacheKeyOverride ??
        (userId == _supabase.auth.currentUser?.id
            ? _ownProfileKey
            : 'profile:$userId');
    final cached = await _readCache(cacheKey);
    final currentData = (cached != null
        ? Map<String, dynamic>.from(cached['data'] as Map)
        : <String, dynamic>{});
    // Track avatar change to purge image cache
    final prevAvatar = currentData['avatar_url'];
    currentData.addAll(partial);
    final now = DateTime.now().toIso8601String();
    final meta = {'fetched_at': now};
    await _writeCache(cacheKey, currentData, meta: meta);
    if (partial.containsKey('avatar_url') &&
        partial['avatar_url'] != prevAvatar &&
        prevAvatar is String &&
        prevAvatar.isNotEmpty) {
      await ImageCacheService.invalidateUrl(prevAvatar);
    }
  }

  Future<void> invalidateProfile(
    String userId, {
    String? cacheKeyOverride,
  }) async {
    final cacheKey =
        cacheKeyOverride ??
        (userId == _supabase.auth.currentUser?.id
            ? _ownProfileKey
            : 'profile:$userId');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKey);
  }

  Future<List<Map<String, dynamic>>> getRecentlyViewed({int limit = 10}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentProfilesKey);
    if (raw == null) return [];
    final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
    return list.take(limit).toList();
  }

  // Internals
  bool _isStale(Map<String, dynamic> cached) {
    try {
      final fetchedAt = DateTime.parse(cached['meta']['fetched_at'] as String);
      return DateTime.now().difference(fetchedAt) > _staleWhileRevalidate;
    } catch (_) {
      return true;
    }
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    String key,
    Map<String, dynamic> data, {
    Map<String, dynamic>? meta,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'data': data,
      'meta': meta ?? {'fetched_at': DateTime.now().toIso8601String()},
    };
    await prefs.setString(key, json.encode(payload));
  }

  Future<Map<String, dynamic>?> _fetchAndUpdate(
    String userId, {
    required List<String> fields,
    required String cacheKey,
  }) async {
    final select = fields.join(',');
    final response = await _supabase
        .from(SupabaseConfig.usersTable)
        .select(select)
        .eq('id', userId)
        .maybeSingle();
    if (response == null) return null;
    await _writeCache(cacheKey, response);
    _rememberRecent(cacheKey, {'data': response});
    return response;
  }

  Future<void> _rememberRecent(
    String cacheKey,
    Map<String, dynamic> cached,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_recentProfilesKey);
      final list = raw != null
          ? (json.decode(raw) as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      final data = Map<String, dynamic>.from(cached['data'] as Map);
      data['cache_key'] = cacheKey;
      // Remove existing entry for same id
      list.removeWhere((e) => e['id'] == data['id']);
      list.insert(0, data);
      while (list.length > _maxRecent) {
        list.removeLast();
      }
      await prefs.setString(_recentProfilesKey, json.encode(list));
    } catch (_) {
      // ignore
    }
  }

  Future<void> _tryBackgroundSync() async {
    final status = await _connectivity.checkConnectivity();
    final online = status.any((r) => r != ConnectivityResult.none);
    if (!online) return;
    // Sync own profile in background
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      unawaited(
        _fetchAndUpdate(
          userId,
          fields: const [
            'id',
            'name',
            'email',
            'avatar_url',
            'updated_at',
            'age',
            'gender',
            'sports',
            'intent',
          ],
          cacheKey: _ownProfileKey,
        ),
      );
    }
  }

  Future<void> dispose() async {
    await _connectivitySub.cancel();
  }
}
