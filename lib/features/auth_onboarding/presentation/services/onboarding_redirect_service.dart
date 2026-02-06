import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/features/auth_onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:dabbler/features/auth_onboarding/domain/models/onboarding_state.dart';

/// Service to check onboarding status and redirect accordingly
///
/// CRITICAL: Called on app start after authentication
/// Determines where user should go based on DB state
class OnboardingRedirectService {
  /// Check onboarding state and redirect user
  ///
  /// Returns true if redirect was performed
  static Future<bool> checkAndRedirect(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Trigger resume check
    await ref.read(onboardingControllerProvider.notifier).checkResumeState();

    final state = ref.read(onboardingControllerProvider);

    return _handleOnboardingState(context, state);
  }

  /// Handle state and perform appropriate redirect
  static bool _handleOnboardingState(
    BuildContext context,
    OnboardingState state,
  ) {
    switch (state.step) {
      case OnboardingStep.checking:
        // Still loading - don't redirect
        return false;

      case OnboardingStep.completed:
        // Onboarding complete
        if (state.existingProfileCount == 2) {
          // User has 2 profiles - go to profile switcher
          context.go('/profile-switcher');
          return true;
        } else {
          // User has 1 complete profile - go to home
          context.go('/home');
          return true;
        }

      case OnboardingStep.collectingBasicInfo:
        // Start onboarding from beginning
        context.go('/onboarding/basic-info');
        return true;

      case OnboardingStep.selectingPersona:
        // Resume at persona selection
        context.go('/onboarding/persona-selection');
        return true;

      case OnboardingStep.creatingProfile:
      case OnboardingStep.creatingPersonaExtension:
        // DB writes in progress - show loading
        // These should auto-progress, so stay where we are
        return false;

      case OnboardingStep.selectingPrimarySport:
        // Resume at primary sport selection
        context.go('/onboarding/primary-sport');
        return true;

      case OnboardingStep.creatingSportProfile:
      case OnboardingStep.finalizing:
        // Final DB writes - should auto-complete
        return false;

      case OnboardingStep.error:
        // Error occurred - show error screen or stay on current screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error ?? 'An error occurred'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
    }
  }
}

/// Widget that checks onboarding on mount
/// Use this as a wrapper in your router
class OnboardingCheck extends ConsumerStatefulWidget {
  final Widget child;

  const OnboardingCheck({required this.child, super.key});

  @override
  ConsumerState<OnboardingCheck> createState() => _OnboardingCheckState();
}

class _OnboardingCheckState extends ConsumerState<OnboardingCheck> {
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasChecked) {
        _hasChecked = true;
        OnboardingRedirectService.checkAndRedirect(context, ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to state changes
    ref.listen(onboardingControllerProvider, (previous, next) {
      if (previous?.step != next.step) {
        OnboardingRedirectService._handleOnboardingState(context, next);
      }
    });

    return widget.child;
  }
}
