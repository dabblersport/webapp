import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

class OnboardingService {
  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  final UserService _userService = UserService();

  // Onboarding step constants
  static const String onboardingStepProfile = 'profile';
  static const String onboardingStepSports = 'sports';
  static const String onboardingStepIntent = 'intent';
  static const String onboardingStepComplete = 'complete';

  // Storage keys
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingStepKey = 'onboarding_step';

  /// Get the next onboarding step for the user
  Future<String> getNextOnboardingStep() async {
    // Check if user is authenticated (simplified check)
    if (_userService.currentUser == null) {
      // Always start with phone input for unauthenticated users
      return '/phone-input';
    }

    // Check if onboarding is already completed
    if (await _isOnboardingCompleted()) {
      return '/home';
    }

    // Check current onboarding step
    final currentStep = await _getOnboardingStep();

    if (currentStep == null) {
      // First time user - start with profile
      return '/create-user-info';
    }

    // Return next step based on current progress
    switch (currentStep) {
      case onboardingStepProfile:
        return '/sports-selection';
      case onboardingStepSports:
        return '/intent-selection';
      case onboardingStepIntent:
        return '/home'; // Onboarding complete
      default:
        return '/create-user-info'; // Fallback
    }
  }

  /// Mark a specific onboarding step as completed
  Future<void> markStepCompleted(String step) async {
    await _setOnboardingStep(step);
  }

  /// Mark onboarding as complete
  Future<void> markOnboardingComplete() async {
    await _setOnboardingStep(onboardingStepComplete);
    await _setOnboardingCompleted(true);
  }

  /// Reset onboarding progress (for testing or user preference)
  Future<void> resetOnboardingProgress() async {
    await _clearOnboardingProgress();
  }

  /// Debug method to clear all onboarding and session data (for testing)
  Future<void> clearAllDataForTesting() async {
    try {
      // Clear onboarding progress
      await _clearOnboardingProgress();

      // Clear user data
      await _userService.clearUserData();

      // Debug logging removed for production
    } catch (e) {
      // Error handling without print statements
    }
  }

  /// Check if user needs to complete onboarding
  Future<bool> needsOnboarding() async {
    return !(await _isOnboardingCompleted());
  }

  /// Get current onboarding step
  Future<String?> getCurrentStep() async {
    return await _getOnboardingStep();
  }

  /// Get onboarding progress percentage (0.0 to 1.0)
  Future<double> getOnboardingProgress() async {
    final currentStep = await _getOnboardingStep();

    if (currentStep == null) return 0.0;
    if (await _isOnboardingCompleted()) return 1.0;

    switch (currentStep) {
      case onboardingStepProfile:
        return 0.25; // 1 of 4 steps
      case onboardingStepSports:
        return 0.5; // 2 of 4 steps
      case onboardingStepIntent:
        return 0.75; // 3 of 4 steps
      default:
        return 0.0;
    }
  }

  /// Get the step number for display (1-4)
  Future<int> getCurrentStepNumber() async {
    final currentStep = await _getOnboardingStep();

    if (currentStep == null) return 1;
    if (await _isOnboardingCompleted()) return 4;

    switch (currentStep) {
      case onboardingStepProfile:
        return 2;
      case onboardingStepSports:
        return 3;
      case onboardingStepIntent:
        return 4;
      default:
        return 1;
    }
  }

  /// Get step title for display
  Future<String> getCurrentStepTitle() async {
    final stepNumber = await getCurrentStepNumber();

    switch (stepNumber) {
      case 1:
        return 'Profile Information';
      case 2:
        return 'Sports Preferences';
      case 3:
        return 'Your Intent';
      case 4:
        return 'Complete';
      default:
        return 'Getting Started';
    }
  }

  // Private helper methods using StorageService
  Future<bool> _isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_onboardingCompletedKey);
      return completed ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _getOnboardingStep() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_onboardingStepKey);
    } catch (e) {
      return null;
    }
  }

  Future<void> _setOnboardingStep(String step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_onboardingStepKey, step);
    } catch (e) {
      // Error handling without print statements
    }
  }

  Future<void> _setOnboardingCompleted(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, completed);
    } catch (e) {
      // Error handling without print statements
    }
  }

  Future<void> _clearOnboardingProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingStepKey);
      await prefs.remove(_onboardingCompletedKey);
    } catch (e) {
      // Error handling without print statements
    }
  }
}
