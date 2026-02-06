import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple cache service using shared preferences
class CacheService {
  late final SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> _initialize() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  /// Get cached value
  Future<T?> get<T>(String key) async {
    await _initialize();

    try {
      final cachedData = _prefs.getString(key);
      if (cachedData == null) return null;

      final Map<String, dynamic> data = json.decode(cachedData);
      final expiresAt = DateTime.parse(data['expires_at']);

      if (DateTime.now().isAfter(expiresAt)) {
        await delete(key);
        return null;
      }

      return data['value'] as T?;
    } catch (e) {
      await delete(key);
      return null;
    }
  }

  /// Set cached value with duration
  Future<void> set<T>(
    String key,
    T value, {
    Duration duration = const Duration(hours: 1),
  }) async {
    await _initialize();

    try {
      final expiresAt = DateTime.now().add(duration);
      final data = {'value': value, 'expires_at': expiresAt.toIso8601String()};

      await _prefs.setString(key, json.encode(data));
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Delete cached value
  Future<void> delete(String key) async {
    await _initialize();
    await _prefs.remove(key);
  }

  /// Get all cache keys
  Future<List<String>> getKeys() async {
    await _initialize();
    return _prefs.getKeys().toList();
  }

  /// Clear all cache
  Future<void> clear() async {
    await _initialize();
    await _prefs.clear();
  }
}

/// Simple analytics service for tracking events
class AnalyticsService {
  /// Track an event
  Future<void> trackEvent(
    String eventName, [
    Map<String, dynamic>? parameters,
  ]) async {
    // This would integrate with Firebase Analytics, Mixpanel, etc.
  }

  /// Track an error
  Future<void> trackError(
    String errorName, [
    Map<String, dynamic>? parameters,
  ]) async {
    // This would integrate with Crashlytics, Sentry, etc.
  }

  /// Track screen view
  Future<void> trackScreenView(
    String screenName, [
    Map<String, dynamic>? parameters,
  ]) async {}
}

/// Providers
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});
