import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'dart:convert';
import 'dart:async';

/// Comprehensive onboarding controller with analytics and A/B testing
class OnboardingController extends ChangeNotifier {
  final SupabaseClient _supabase;
  static const String _progressKey = 'onboarding_progress';
  static const String _variantKey = 'ab_test_variant';
  static const String _sessionKey = 'onboarding_session';
  static const String _analyticsKey = 'onboarding_analytics';

  // Onboarding state
  OnboardingProgress? _progress;
  String? _currentVariant;
  DateTime? _sessionStarted;
  Map<String, dynamic> _analytics = {};
  Timer? _timeTracker;

  // Getters
  OnboardingProgress? get progress => _progress;
  String? get currentVariant => _currentVariant;
  double get completionPercentage => _progress?.completionPercentage ?? 0.0;
  int get currentStep => _progress?.currentStep ?? 1;
  bool get isCompleted => _progress?.isCompleted ?? false;
  Duration? get timeSpent => _sessionStarted != null
      ? DateTime.now().difference(_sessionStarted!)
      : null;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  OnboardingController({required SupabaseClient supabase})
    : _supabase = supabase {
    _initializeOnboarding();
  }

  /// Initialize onboarding system
  Future<void> _initializeOnboarding() async {
    await _loadProgress();
    await _loadVariant();
    await _loadSession();
    await _loadAnalytics();
    _startTimeTracking();
  }

  /// Load onboarding progress from storage
  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString(_progressKey);

      if (progressJson != null) {
        final data = jsonDecode(progressJson);
        _progress = OnboardingProgress.fromJson(data);
      } else {
        _progress = OnboardingProgress.initial();
      }

      // Also try to load from backend for authenticated users
      if (_supabase.auth.currentUser != null) {
        await _syncWithBackend();
      }

      notifyListeners();
    } catch (e) {
      _progress = OnboardingProgress.initial();
    }
  }

  /// Save progress to local storage and backend
  Future<void> _saveProgress() async {
    if (_progress == null) return;

    try {
      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_progressKey, jsonEncode(_progress!.toJson()));

      // Save to backend if authenticated
      if (_supabase.auth.currentUser != null) {
        await _supabase.from('onboarding_progress').upsert({
          'user_id': _supabase.auth.currentUser!.id,
          'step_name': 'step_${_progress!.currentStep}',
          'step_data': _progress!.toJson(),
          'completed_at': DateTime.now().toIso8601String(),
        });

        // Update user onboarding status
        await _supabase
            .from(SupabaseConfig.usersTable) // 'profiles' table
            .update({
              'onboarding_step': 'step_${_progress!.currentStep}',
              'onboarding_completed': _progress!.isCompleted,
            })
            .eq(
              'user_id',
              _supabase.auth.currentUser!.id,
            ); // Match by user_id FK
      }

      notifyListeners();
    } catch (e) {}
  }

  /// Load A/B testing variant
  Future<void> _loadVariant() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentVariant = prefs.getString(_variantKey);

      // Assign variant if none exists
      if (_currentVariant == null) {
        _currentVariant = _assignABVariant();
        await prefs.setString(_variantKey, _currentVariant!);
      }
    } catch (e) {
      _currentVariant = 'control';
    }
  }

  /// Assign A/B testing variant
  String _assignABVariant() {
    final random = DateTime.now().millisecondsSinceEpoch % 100;

    if (random < 34) return 'control';
    if (random < 67) return 'gamified';
    return 'minimal';
  }

  /// Load session data
  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString(_sessionKey);

      if (sessionData != null) {
        final data = jsonDecode(sessionData);
        _sessionStarted = DateTime.parse(data['started']);
      } else {
        _sessionStarted = DateTime.now();
        await _saveSession();
      }
    } catch (e) {
      _sessionStarted = DateTime.now();
    }
  }

  /// Save session data
  Future<void> _saveSession() async {
    if (_sessionStarted == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sessionKey,
        jsonEncode({'started': _sessionStarted!.toIso8601String()}),
      );
    } catch (e) {}
  }

  /// Load analytics data
  Future<void> _loadAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analyticsJson = prefs.getString(_analyticsKey);

      if (analyticsJson != null) {
        _analytics = jsonDecode(analyticsJson);
      }
    } catch (e) {}
  }

  /// Save analytics data
  Future<void> _saveAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_analyticsKey, jsonEncode(_analytics));

      // Send to backend for analysis
      if (_supabase.auth.currentUser != null) {
        await _supabase.from('onboarding_analytics').upsert({
          'user_id': _supabase.auth.currentUser!.id,
          'variant': _currentVariant,
          'analytics_data': _analytics,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {}
  }

  /// Start time tracking
  void _startTimeTracking() {
    _timeTracker?.cancel();
    _timeTracker = Timer.periodic(const Duration(seconds: 30), (timer) {
      _trackTimeSpent();
    });
  }

  /// Track time spent on current step
  void _trackTimeSpent() {
    if (_sessionStarted == null || _progress == null) return;

    final stepKey = 'step_${_progress!.currentStep}_time';
    final currentTime = DateTime.now().difference(_sessionStarted!).inSeconds;

    _analytics[stepKey] = currentTime;
    _saveAnalytics();
  }

  /// Sync with backend data
  Future<void> _syncWithBackend() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from(SupabaseConfig.usersTable) // 'profiles' table
          .select('onboarding_completed, onboarding_step')
          .eq('user_id', userId) // Match by user_id FK
          .maybeSingle();

      if (response != null) {
        final isCompleted = response['onboarding_completed'] ?? false;
        final step = response['onboarding_step'] ?? 'step_1';

        if (isCompleted && !_progress!.isCompleted) {
          _progress = OnboardingProgress.completed();
        } else if (!isCompleted) {
          final stepNumber = int.tryParse(step.replaceAll('step_', '')) ?? 1;
          _progress!.currentStep = stepNumber;
        }
      }
    } catch (e) {}
  }

  /// Start onboarding flow
  Future<void> startOnboarding() async {
    _progress = OnboardingProgress.initial();
    _sessionStarted = DateTime.now();
    await _saveProgress();
    await _saveSession();

    _trackEvent('onboarding_started');
    notifyListeners();
  }

  /// Complete current step
  Future<void> completeStep(int step, Map<String, dynamic>? stepData) async {
    if (_progress == null) return;

    _progress!.completeStep(step, stepData);
    await _saveProgress();

    _trackEvent('step_completed', {'step': step, 'data': stepData});
    notifyListeners();
  }

  /// Skip current step
  Future<void> skipStep(int step, {String? reason}) async {
    if (_progress == null) return;

    _progress!.skipStep(step);
    await _saveProgress();

    _trackEvent('step_skipped', {'step': step, 'reason': reason});
    notifyListeners();
  }

  /// Go to previous step
  void goToPreviousStep() {
    if (_progress == null || _progress!.currentStep <= 1) return;

    _progress!.currentStep--;
    _saveProgress();

    _trackEvent('step_back', {'to_step': _progress!.currentStep});
    notifyListeners();
  }

  /// Complete entire onboarding
  Future<void> completeOnboarding() async {
    if (_progress == null) return;

    _progress!.complete();
    await _saveProgress();

    final completionTime = timeSpent?.inMinutes ?? 0;
    _trackEvent('onboarding_completed', {'time_minutes': completionTime});

    // Award completion bonus points
    await _awardCompletionBonus();

    notifyListeners();
  }

  /// Mark onboarding as completed (alias for completeOnboarding)
  Future<void> markOnboardingCompleted() async {
    await completeOnboarding();
  }

  /// Award completion bonus
  Future<void> _awardCompletionBonus() async {
    try {
      if (_supabase.auth.currentUser != null) {
        final bonusPoints = _currentVariant == 'gamified' ? 100 : 50;

        await _supabase.from('user_points').upsert({
          'user_id': _supabase.auth.currentUser!.id,
          'points': bonusPoints,
          'source': 'onboarding_completion',
          'description': 'Profile completion bonus',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {}
  }

  /// Reset onboarding (for testing)
  Future<void> resetOnboarding() async {
    _progress = OnboardingProgress.initial();
    _sessionStarted = DateTime.now();
    _analytics.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
    await prefs.remove(_sessionKey);
    await prefs.remove(_analyticsKey);

    await _saveProgress();
    await _saveSession();

    _trackEvent('onboarding_reset');
    notifyListeners();
  }

  /// Track analytics event
  void _trackEvent(String event, [Map<String, dynamic>? data]) {
    final eventKey = 'events';
    if (!_analytics.containsKey(eventKey)) {
      _analytics[eventKey] = <Map<String, dynamic>>[];
    }

    (_analytics[eventKey] as List).add({
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
      'step': _progress?.currentStep,
      'variant': _currentVariant,
      'data': data,
    });

    _saveAnalytics();
  }

  /// Get personalized tip for current step
  String getPersonalizedTip() {
    if (_progress == null) return '';

    final step = _progress!.currentStep;
    final variant = _currentVariant ?? 'control';

    switch (step) {
      case 1:
        return variant == 'gamified'
            ? '🎯 Adding your photo earns 25 points!'
            : 'A profile photo helps others recognize you at games';
      case 2:
        return variant == 'gamified'
            ? '🏆 Each sport you add unlocks new game opportunities!'
            : 'Select sports you enjoy - you can always add more later';
      case 3:
        return variant == 'gamified'
            ? '📍 Setting location preferences earns location-based rewards!'
            : 'We\'ll show games near your preferred locations';
      case 4:
        return 'Review your privacy settings to control who sees your profile';
      default:
        return 'Complete your profile to get the best game recommendations';
    }
  }

  /// Get social proof message
  Future<String> getSocialProofMessage() async {
    try {
      // Get count of users who completed onboarding today
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
          .from(SupabaseConfig.usersTable) // 'profiles' table
          .select('id')
          .eq('onboarding_completed', true)
          .gte('updated_at', '${today}T00:00:00Z')
          .lt('updated_at', '${today}T23:59:59Z');

      final count = response.length;

      if (count > 0) {
        return '$count players completed their profile today!';
      } else {
        return 'Be among the first to complete your profile today!';
      }
    } catch (e) {
      return 'Join thousands of players with complete profiles!';
    }
  }

  /// Get suggested next actions
  List<String> getSuggestedActions() {
    if (_progress == null) return [];

    final suggestions = <String>[];
    final step = _progress!.currentStep;

    switch (step) {
      case 1:
        suggestions.addAll([
          'Add a profile photo',
          'Enter your display name',
          'Add a brief bio (optional)',
        ]);
        break;
      case 2:
        suggestions.addAll([
          'Select your favorite sports',
          'Rate your skill level',
          'Add sports you want to try',
        ]);
        break;
      case 3:
        suggestions.addAll([
          'Set your location preferences',
          'Choose available days',
          'Set preferred game times',
        ]);
        break;
      case 4:
        suggestions.addAll([
          'Review visibility settings',
          'Set message preferences',
          'Configure notifications',
        ]);
        break;
    }

    return suggestions;
  }

  /// Calculate profile strength (0-100)
  int getProfileStrength() {
    if (_progress == null) return 0;

    int strength = 0;
    final data = _progress!.stepData;

    // Basic info (25 points max)
    if (data['step_1']?['name']?.isNotEmpty == true) strength += 10;
    if (data['step_1']?['photo'] != null) strength += 10;
    if (data['step_1']?['bio']?.isNotEmpty == true) strength += 5;

    // Sports (35 points max)
    final sports = data['step_2']?['sports'] as List?;
    if (sports != null) {
      strength += (sports.length * 5).clamp(0, 25);
      if (data['step_2']?['skill_levels'] != null) strength += 10;
    }

    // Preferences (25 points max)
    if (data['step_3']?['location_preferences'] != null) strength += 10;
    if (data['step_3']?['availability'] != null) strength += 10;
    if (data['step_3']?['game_preferences'] != null) strength += 5;

    // Privacy (15 points max)
    if (data['step_4']?['privacy_reviewed'] == true) strength += 15;

    return strength.clamp(0, 100);
  }

  @override
  void dispose() {
    _timeTracker?.cancel();
    super.dispose();
  }
}

/// Onboarding progress model
class OnboardingProgress {
  int currentStep;
  bool isCompleted;
  DateTime createdAt;
  DateTime? completedAt;
  Map<String, dynamic> stepData;
  Set<int> skippedSteps;

  OnboardingProgress({
    required this.currentStep,
    required this.isCompleted,
    required this.createdAt,
    this.completedAt,
    Map<String, dynamic>? stepData,
    Set<int>? skippedSteps,
  }) : stepData = stepData ?? {},
       skippedSteps = skippedSteps ?? {};

  factory OnboardingProgress.initial() {
    return OnboardingProgress(
      currentStep: 1,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
  }

  factory OnboardingProgress.completed() {
    return OnboardingProgress(
      currentStep: 5,
      isCompleted: true,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
  }

  factory OnboardingProgress.fromJson(Map<String, dynamic> json) {
    return OnboardingProgress(
      currentStep: json['currentStep'] ?? 1,
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      stepData: Map<String, dynamic>.from(json['stepData'] ?? {}),
      skippedSteps: Set<int>.from(json['skippedSteps'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentStep': currentStep,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'stepData': stepData,
      'skippedSteps': skippedSteps.toList(),
    };
  }

  void completeStep(int step, Map<String, dynamic>? data) {
    if (data != null) {
      stepData['step_$step'] = data;
    }

    if (step >= currentStep) {
      currentStep = step + 1;
    }

    // Check if onboarding is complete (all 4 steps)
    if (currentStep > 4) {
      complete();
    }
  }

  void skipStep(int step) {
    skippedSteps.add(step);
    if (step >= currentStep) {
      currentStep = step + 1;
    }

    if (currentStep > 4) {
      complete();
    }
  }

  void complete() {
    isCompleted = true;
    completedAt = DateTime.now();
    currentStep = 5; // Completion step
  }

  double get completionPercentage {
    if (isCompleted) return 1.0;
    return (currentStep - 1) / 4.0; // 4 main steps
  }
}
