import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/authentication/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

import 'package:dabbler/widgets/onboarding_progress.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'dart:async';

class SetUsernameScreen extends ConsumerStatefulWidget {
  const SetUsernameScreen({super.key});

  @override
  ConsumerState<SetUsernameScreen> createState() => _SetUsernameScreenState();
}

class _SetUsernameScreenState extends ConsumerState<SetUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingUsername = false;
  String? _usernameError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Verify authentication status on load for debugging
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = AuthService();
      final currentUser = authService.getCurrentUser();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (username.length < 3) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final authService = AuthService();
        final exists = await authService.checkUsernameExists(username);

        if (mounted) {
          setState(() {
            _usernameError = exists ? 'Username already taken' : null;
            _isCheckingUsername = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _usernameError = 'Error checking username';
            _isCheckingUsername = false;
          });
        }
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_usernameError!), backgroundColor: Colors.red),
      );
      return;
    }

    final onboardingData = ref.read(onboardingDataProvider);
    if (onboardingData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing onboarding data. Please start over.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate all required fields
    if (onboardingData.displayName == null ||
        onboardingData.age == null ||
        onboardingData.gender == null ||
        onboardingData.intention == null ||
        onboardingData.preferredSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing required information. Please complete all steps.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();

      // Validate username is not empty
      if (username.isEmpty) {
        throw Exception('Username cannot be empty. Please enter a username.');
      }

      final authService = AuthService();

      final currentUser = authService.getCurrentUser();

      if (currentUser == null) {
        // Session expired - this shouldn't happen but handle gracefully
        throw Exception(
          'Your session has expired. Please verify your phone number again.',
        );
      }

      // Complete onboarding - updates profile, creates sport/organiser profile, syncs to auth.users
      await authService.completeOnboarding(
        displayName: onboardingData.displayName!,
        username: username,
        age: onboardingData.age!,
        gender: onboardingData.gender!,
        intention: onboardingData.intention!,
        preferredSport: onboardingData.preferredSport!,
        interests: onboardingData.interestsString,
        password: null, // Phone/Google users don't set password here
      );

      // Clear onboarding data
      ref.read(onboardingDataProvider.notifier).clear();

      // Refresh auth state to load the new profile
      await ref.read(simpleAuthProvider.notifier).refreshAuthState();

      // Navigate to welcome screen
      if (mounted) {
        final displayName = onboardingData.displayName ?? 'Player';
        context.go(RoutePaths.welcome, extra: {'displayName': displayName});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingData = ref.watch(onboardingDataProvider);
    final phone = onboardingData?.phone ?? '';
    final email = onboardingData?.email ?? '';
    final identifier = phone.isNotEmpty ? phone : email;

    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleSectionLayout(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: screenHeight - topPadding - bottomPadding - 48,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Container
            Column(
              children: [
                SizedBox(height: AppSpacing.xl),
                // Dabbler logo
                Center(
                  child: SvgPicture.asset(
                    'assets/images/dabbler_logo.svg',
                    width: 80,
                    height: 88,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                // Dabbler text logo
                Center(
                  child: SvgPicture.asset(
                    'assets/images/dabbler_text_logo.svg',
                    width: 110,
                    height: 21,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                // Onboarding Progress
                const OnboardingProgress(currentStep: 4),
                SizedBox(height: AppSpacing.xl),
                // Title
                Text(
                  'Choose Your Username',
                  style: AppTypography.headlineMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.sm),
                // Subtitle
                if (identifier.isNotEmpty)
                  Text(
                    identifier,
                    style: AppTypography.bodyLarge.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),

            const SizedBox(height: 40),

            // Form Container
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Username Field
                  // Text(
                  //   'Username',
                  //   style: AppTypography.titleMedium.copyWith(
                  //     fontWeight: FontWeight.w600,
                  //     color: Colors.white,
                  //   ),
                  // ),
                  SizedBox(height: AppSpacing.sm),
                  AppInputField(
                    controller: _usernameController,
                    label: 'Username',
                    hintText: 'Choose a unique username',
                    onChanged: _checkUsernameAvailability,
                    suffixIcon: _isCheckingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameError == null &&
                              _usernameController.text.isNotEmpty
                        ? const Icon(
                            Iconsax.tick_circle_copy,
                            color: Colors.green,
                          )
                        : null,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username is required';
                      }
                      if (value.trim().length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return 'Username can only contain letters, numbers, and underscores';
                      }
                      return null;
                    },
                  ),
                  if (_usernameError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _usernameError!,
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFFD32F2F),
                        ),
                      ),
                    ),

                  SizedBox(height: AppSpacing.xl),

                  // Submit Button
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: Text(_isLoading ? 'Completing...' : 'Complete'),
                  ),
                  SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
