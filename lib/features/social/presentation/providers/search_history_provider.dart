import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's most recent social-search queries on this device.
class RecentSearchHistoryNotifier extends StateNotifier<List<String>> {
  RecentSearchHistoryNotifier({SharedPreferences? preferences})
    : _preferences = preferences,
      super(const []) {
    _initialized = _load();
  }

  static const _storageKey = 'social_search_recent_queries';
  static const _maxEntries = 10;

  final SharedPreferences? _preferences;
  late final Future<void> _initialized;
  late SharedPreferences _storage;

  /// Completes once the persisted history has been read.
  Future<void> get initialized => _initialized;

  Future<void> _load() async {
    _storage = _preferences ?? await SharedPreferences.getInstance();
    state = List.unmodifiable(_storage.getStringList(_storageKey) ?? const []);
  }

  Future<void> add(String query) async {
    await _initialized;
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    final next = [
      normalized,
      ...state.where((existing) => existing != normalized),
    ].take(_maxEntries).toList(growable: false);
    await _replace(next);
  }

  Future<void> remove(String query) async {
    await _initialized;
    final index = state.indexOf(query);
    if (index < 0) return;

    final next = [...state]..removeAt(index);
    await _replace(next);
  }

  Future<void> clear() async {
    await _initialized;
    await _replace(const []);
  }

  Future<void> _replace(List<String> next) async {
    state = List.unmodifiable(next);
    await _storage.setStringList(_storageKey, next);
  }
}

final recentSearchHistoryProvider =
    StateNotifierProvider<RecentSearchHistoryNotifier, List<String>>((ref) {
      return RecentSearchHistoryNotifier();
    });
