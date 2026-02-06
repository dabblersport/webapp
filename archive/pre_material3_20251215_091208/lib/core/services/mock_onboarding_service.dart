import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MockOnboardingService {
  static final MockOnboardingService _instance =
      MockOnboardingService._internal();
  factory MockOnboardingService() => _instance;
  MockOnboardingService._internal();

  // Onboarding steps
  static const String onboardingStepProfile = 'profile';
  static const String onboardingStepSports = 'sports';
  static const String onboardingStepIntent = 'intent';
  static const String onboardingStepComplete = 'complete';

  // Mock onboarding data
  Map<String, bool> _completedSteps = {};
  bool _onboardingComplete = false;
  final String _onboardingKey = 'mock_onboarding_data';

  // Initialize onboarding data
  Future<void> _initializeOnboarding() async {
    if (_completedSteps.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final onboardingJson = prefs.getString(_onboardingKey);
      if (onboardingJson != null) {
        final data = json.decode(onboardingJson);
        _completedSteps = Map<String, bool>.from(data['completedSteps'] ?? {});
        _onboardingComplete = data['onboardingComplete'] ?? false;
      }
    }
  }

  // Save onboarding data to local storage
  Future<void> _saveOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'completedSteps': _completedSteps,
      'onboardingComplete': _onboardingComplete,
    };
    await prefs.setString(_onboardingKey, json.encode(data));
  }

  // Mark a step as completed
  Future<void> markStepCompleted(String step) async {
    await _initializeOnboarding();
    _completedSteps[step] = true;
    await _saveOnboarding();
  }

  // Mark onboarding as complete
  Future<void> markOnboardingComplete() async {
    await _initializeOnboarding();
    _onboardingComplete = true;
    _completedSteps[onboardingStepComplete] = true;
    await _saveOnboarding();
  }

  // Check if a step is completed
  Future<bool> isStepCompleted(String step) async {
    await _initializeOnboarding();
    return _completedSteps[step] ?? false;
  }

  // Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    await _initializeOnboarding();
    return _onboardingComplete;
  }

  // Get onboarding progress (0.0 to 1.0)
  double getOnboardingProgress() {
    final totalSteps = 4; // profile, sports, intent, complete
    final completedCount = _completedSteps.values
        .where((completed) => completed)
        .length;
    return completedCount / totalSteps;
  }

  // Get current step number
  int getCurrentStepNumber() {
    final completedCount = _completedSteps.values
        .where((completed) => completed)
        .length;
    return completedCount + 1;
  }

  // Get current step title
  String getCurrentStepTitle() {
    final currentStep = getCurrentStepNumber();
    switch (currentStep) {
      case 1:
        return 'Profile';
      case 2:
        return 'Sports';
      case 3:
        return 'Intent';
      case 4:
        return 'Complete';
      default:
        return 'Setup';
    }
  }

  // Reset onboarding
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingKey);
    _completedSteps.clear();
    _onboardingComplete = false;
  }

  // Get all completed steps
  List<String> getCompletedSteps() {
    return _completedSteps.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
}
