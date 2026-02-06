import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dabbler/data/models/core/user_model.dart';
import 'auth_service.dart';
import 'profile_cache_service.dart';

class UserService extends ChangeNotifier {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static const String _userKey = 'user_profile';
  static const String _greetingCacheKey = 'greeting_cache';
  static const String _lastGreetingUpdateKey = 'last_greeting_update';

  UserModel? _currentUser;
  String? _cachedGreeting;
  DateTime? _lastGreetingUpdate;
  final AuthService _authService = AuthService();

  // Getters
  UserModel? get currentUser => _currentUser;
  String? get cachedGreeting => _cachedGreeting;
  DateTime? get lastGreetingUpdate => _lastGreetingUpdate;

  // Check if greeting cache is valid (less than 1 hour old)
  bool get isGreetingCacheValid {
    if (_lastGreetingUpdate == null) return false;
    final now = DateTime.now();
    return now.difference(_lastGreetingUpdate!).inHours < 1;
  }

  // Initialize user service
  Future<void> init() async {
    await _loadUserFromSupabase();
    await _loadGreetingCache();
    notifyListeners();
  }

  // Load user from Supabase
  Future<void> _loadUserFromSupabase() async {
    try {
      // Prefer cached basic profile first for fast startup
      final cache = ProfileCacheService();
      final basic = await cache.getOwnProfile(
        fields: const ['id', 'name', 'email', 'avatar_url', 'updated_at'],
        preferCache: true,
        revalidate: true,
      );
      final userProfile =
          basic ??
          await _authService.getUserProfile(
            fields: [
              'id',
              'name',
              'email',
              'avatar_url',
              'updated_at',
              'age',
              'gender',
              'sports',
              'intent',
              'phone',
            ],
          );
      if (userProfile != null) {
        _currentUser = UserModel.fromSupabaseJson(userProfile);
        await _saveUserToStorage(); // Cache locally
      } else {
        // Fallback to local storage if no Supabase profile
        await _loadUserFromStorage();
      }
    } catch (e) {
      // Fallback to local storage on error
      await _loadUserFromStorage();
    }
  }

  // Load user from shared preferences (fallback)
  Future<void> _loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);

      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        _currentUser = UserModel.fromJson(userMap);
      } else {
        // No cached user; keep unset to avoid stale names during new registrations
        _currentUser = null;
      }
    } catch (e) {
      // On error, leave user unset
      _currentUser = null;
    }
  }

  // Save user to shared preferences
  Future<void> _saveUserToStorage() async {
    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json.encode(_currentUser!.toJson()));
    }
  }

  // Load greeting cache from storage
  Future<void> _loadGreetingCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedGreeting = prefs.getString(_greetingCacheKey);

      final lastUpdateString = prefs.getString(_lastGreetingUpdateKey);
      if (lastUpdateString != null) {
        _lastGreetingUpdate = DateTime.parse(lastUpdateString);
      }
    } catch (e) {
      _cachedGreeting = null;
      _lastGreetingUpdate = null;
    }
  }

  // Update user profile
  Future<void> updateUser(UserModel updatedUser) async {
    try {
      // Update in Supabase first
      await _authService.updateUserProfile(
        displayName: updatedUser.username,
        age: updatedUser.age,
        gender: updatedUser.gender,
        sports: updatedUser.sports,
        intent: updatedUser.intent,
      );
      _currentUser = updatedUser;

      await _saveUserToStorage();
      // Update cache selectively
      final userId = updatedUser.id;
      await ProfileCacheService().updateProfilePartial(userId, {
        'name': updatedUser.username,
        'age': updatedUser.age,
        'gender': updatedUser.gender,
        'sports': updatedUser.sports,
        'intent': updatedUser.intent,
        'email': updatedUser.email,
        'avatar_url': updatedUser.profileImageUrl,
      });

      // Clear greeting cache when user info changes
      await _clearGreetingCache();

      notifyListeners();
    } catch (e) {
      // Fallback to local update only
      _currentUser = updatedUser;
      await _saveUserToStorage();
      final userId = updatedUser.id;
      await ProfileCacheService().updateProfilePartial(userId, {
        'name': updatedUser.username,
        'age': updatedUser.age,
        'gender': updatedUser.gender,
        'sports': updatedUser.sports,
        'intent': updatedUser.intent,
        'email': updatedUser.email,
        'avatar_url': updatedUser.profileImageUrl,
      });
      await _clearGreetingCache();
      notifyListeners();
    }
  }

  // Update specific user fields
  Future<void> updateUserFields({
    String? displayName,
    String? email,
    String? phone,
    String? bio,
    String? language,
  }) async {
    if (_currentUser != null) {
      try {
        // Update local copy first
        final updatedUser = _currentUser!.copyWith(
          username: displayName, // Store display name as firstName
          displayName: '', // Keep lastName empty
          email: email,
          phone: phone,
          bio: bio,
          language: language,
          updatedAt: DateTime.now(),
        );

        // Update in Supabase using updateUserProfile
        await _authService.updateUserProfile(
          displayName: displayName,
          bio: bio,
          phone: phone,
          language: language,
        );

        _currentUser = updatedUser;

        await _saveUserToStorage();
        await ProfileCacheService().updateProfilePartial(updatedUser.id, {
          'name': displayName,
          'email': email,
          'phone': phone,
          'bio': bio,
          'language': language,
        });
        await _clearGreetingCache();
        notifyListeners();
      } catch (e) {
        // Fallback to local update only
        final updatedUser = _currentUser!.copyWith(
          username: displayName,
          displayName: '',
          email: email,
          phone: phone,
          bio: bio,
          language: language,
          updatedAt: DateTime.now(),
        );
        _currentUser = updatedUser;
        await _saveUserToStorage();
        await ProfileCacheService().updateProfilePartial(updatedUser.id, {
          'name': displayName,
          'email': email,
          'phone': phone,
          'bio': bio,
          'language': language,
        });
        await _clearGreetingCache();
        notifyListeners();
      }
    }
  }

  // Clear greeting cache
  Future<void> _clearGreetingCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_greetingCacheKey);
      await prefs.remove(_lastGreetingUpdateKey);

      _cachedGreeting = null;
      _lastGreetingUpdate = null;
    } catch (e) {
      // Handle storage error
    }
  }

  // Get user display name with fallback
  String getUserDisplayName() {
    if (_currentUser != null) {
      return _currentUser!.displayName ?? '';
    }
    return 'Player';
  }

  // Get user language preference
  String getUserLanguage() {
    return _currentUser?.language ?? 'en';
  }

  // Check if user has valid name
  bool hasValidUserName() {
    return _currentUser?.hasValidName ?? false;
  }

  // Refresh user data (simulate API call)
  Future<void> refreshUserData() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // In a real app, this would fetch from an API
    // For now, we'll just notify listeners to trigger a refresh
    notifyListeners();
  }

  // Clear all user data
  Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_greetingCacheKey);
      await prefs.remove(_lastGreetingUpdateKey);

      _currentUser = null;
      _cachedGreeting = null;
      _lastGreetingUpdate = null;

      notifyListeners();
    } catch (e) {
      // Handle storage error
    }
  }

  /// Clear user data when starting a new registration
  Future<void> clearUserForNewRegistration() async {
    await clearUserData();
  }
}
