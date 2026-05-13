import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/widgets/app_button.dart';
import 'package:dabbler/widgets/input_field.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/services/onboarding_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/features/username_engine/providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  Timer? _usernameDebounceTimer;
  String? _usernameError;
  bool _isCheckingUsername = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final onboardingData = ref.read(onboardingDataProvider);
    if (onboardingData?.username != null) {
      _usernameController.text = onboardingData!.username!;
    }
  }

  void _checkUsernameAvailability(String username) {
    _usernameDebounceTimer?.cancel();

    if (username.isEmpty) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    // Basic validation
    if (username.length < 3) {
      setState(() {
        _usernameError = AppLocalizations.of(context).set_password_validate_username_min;
        _isCheckingUsername = false;
      });
      return;
    }

    if (username.length > 20) {
      setState(() {
        _usernameError = AppLocalizations.of(context).set_password_validate_username_max;
        _isCheckingUsername = false;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _usernameError = AppLocalizations.of(context).set_password_validate_username_chars;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    _usernameDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final result = await ref.read(
        usernameAvailabilityProvider(username).future,
      );

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() {
            _usernameError = AppLocalizations.of(context).set_password_validate_username_checking;
            _isCheckingUsername = false;
          });
        },
        (isAvailable) {
          setState(() {
            _usernameError = isAvailable ? null : AppLocalizations.of(context).set_password_validate_username_taken;
            _isCheckingUsername = false;
          });
        },
      );
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cooldownTimer?.cancel();
    _usernameDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_usernameError != null || _isCheckingUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).set_password_wait_validation),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Get onboarding data from provider
    final onboardingData = ref.read(onboardingDataProvider);

    try {
      if (onboardingData == null ||
          (onboardingData.email == null && onboardingData.phone == null)) {
        throw Exception('Onboarding data is missing. Please start over.');
      }

      // Validate required fields
      if (onboardingData.displayName == null ||
          onboardingData.displayName!.trim().isEmpty) {
        throw Exception(
          'Name is required. Please go back and enter your name.',
        );
      }

      if (onboardingData.age == null) {
        throw Exception('Age is required. Please go back and enter your age.');
      }

      if (onboardingData.age! < 16) {
        throw Exception('You must be at least 16 years old to register.');
      }

      if (onboardingData.gender == null ||
          onboardingData.gender!.trim().isEmpty) {
        throw Exception(
          'Gender is required. Please go back and select your gender.',
        );
      }

      if (onboardingData.intention == null ||
          onboardingData.intention!.trim().isEmpty) {
        throw Exception(
          'Intention is required. Please go back and select your intention.',
        );
      }

      if (onboardingData.preferredSport == null ||
          onboardingData.preferredSport!.trim().isEmpty) {
        throw Exception(
          'Preferred sport is required. Please go back and select your preferred sport.',
        );
      }

      final username = _usernameController.text.trim();
      if (username.isEmpty) {
        throw Exception('Username is required.');
      }

      // Save username to onboarding data
      ref.read(onboardingDataProvider.notifier).setUsername(username);

      final authService = AuthService();
      final onboardingService = OnboardingService();

      // Handle email-based registration
      if (onboardingData.email != null) {
        final email = onboardingData.email!.trim();
        final normalizedEmail = email.replaceAll(
          RegExp(r"[\u200B-\u200D\uFEFF]"),
          "",
        );
        final password = _passwordController.text;

        try {
          // Check if user already exists
          final userExists = await authService.checkUserExistsByEmail(
            normalizedEmail,
          );
          if (userExists) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).set_password_account_exists,
                ),
                backgroundColor: Colors.orange,
              ),
            );
            context.go('/enter-password', extra: normalizedEmail);
            return;
          }

          // Check if user is already authenticated (from OTP verification)
          final currentUser = authService.getCurrentUser();
          if (currentUser != null && currentUser.email == normalizedEmail) {
            // User is already authenticated via OTP - just set password and complete onboarding

            // Get selected location (country and city) from provider
            final locationState = ref.read(selectedLocationProvider);
            final country = locationState.maybeWhen(
              data: (loc) => loc.country,
              orElse: () => null,
            );
            final city = locationState.maybeWhen(
              data: (loc) => loc.city,
              orElse: () => null,
            );

            // Complete onboarding with password
            await authService.completeOnboarding(
              displayName: onboardingData.displayName!,
              username: username,
              age: onboardingData.age!,
              gender: onboardingData.gender!,
              intention: onboardingData.intention!,
              preferredSport: onboardingData.preferredSport!,
              interests: onboardingData.interests,
              country: country,
              city: city,
              password: password, // Email users set password
            );
          } else {
            // User not authenticated - create account with password
            // This should not happen in the unified flow, but keep as fallback

            final signUpResponse = await authService.signUpWithEmailAndPassword(
              email: normalizedEmail,
              password: password,
            );

            if (signUpResponse.user == null) {
              throw Exception('Failed to create account');
            }

            // Complete onboarding after account creation
            // Get selected location (country and city) from provider
            final locationStateFallback = ref.read(selectedLocationProvider);
            final countryFallback = locationStateFallback.maybeWhen(
              data: (loc) => loc.country,
              orElse: () => null,
            );
            final cityFallback = locationStateFallback.maybeWhen(
              data: (loc) => loc.city,
              orElse: () => null,
            );

            await authService.completeOnboarding(
              displayName: onboardingData.displayName!,
              username: username,
              age: onboardingData.age!,
              gender: onboardingData.gender!,
              intention: onboardingData.intention!,
              preferredSport: onboardingData.preferredSport!,
              interests: onboardingData.interests,
              country: countryFallback,
              city: cityFallback,
              password:
                  null, // Password already set via signUpWithEmailAndPassword
            );
          }
        } catch (e) {
          final msg = e.toString();

          if (msg.contains('already registered') ||
              msg.contains('user_already_exists')) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).set_password_account_exists,
                ),
                backgroundColor: Colors.orange,
              ),
            );
            context.go('/enter-password', extra: normalizedEmail);
            return;
          }

          if (msg.contains('over_email_send_rate_limit') ||
              msg.contains('after 12 seconds')) {
            if (!mounted) return;
            setState(() => _cooldown = 12);
            _cooldownTimer?.cancel();
            _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (!mounted) {
                t.cancel();
                return;
              }
              setState(() {
                _cooldown = (_cooldown - 1).clamp(0, 999);
                if (_cooldown == 0) t.cancel();
              });
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).set_password_rate_limit),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          rethrow;
        }
      } else {
        // This screen is only for email users
        throw Exception('This screen is only for email-based registration.');
      }

      // Persist get_updates preference to user_preferences
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('user_preferences').upsert(
          {
            'user_id': userId,
            'get_updates': onboardingData.getUpdates,
          },
          onConflict: 'user_id',
        );
      }

      // Mark onboarding complete
      await onboardingService.markOnboardingComplete();

      // Clear onboarding data
      ref.read(onboardingDataProvider.notifier).clear();

      // Refresh auth state
      await ref.read(simpleAuthProvider.notifier).refreshAuthState();

      // Navigate to welcome screen
      if (mounted) {
        final displayName = onboardingData.displayName ?? 'Player';
        context.go(RoutePaths.welcome, extra: {'displayName': displayName});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).set_password_error_prefix(e.toString())), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingData = ref.watch(onboardingDataProvider);
    final email = onboardingData?.email ?? '';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final backgroundColor = isDarkMode
        ? colorScheme.surface
        : const Color(0xFFF6F2FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppLocalizations.of(context).set_password_title,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (email.isNotEmpty)
                            Text(
                              AppLocalizations.of(context).set_password_email_prefix(email),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          const SizedBox(height: 32),

                          // Username Field
                          Text(
                            AppLocalizations.of(context).set_password_username_label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomInputField(
                            controller: _usernameController,
                            label: AppLocalizations.of(context).set_password_username_label,
                            hintText: AppLocalizations.of(context).set_password_username_hint,
                            onChanged: _checkUsernameAvailability,
                            suffixIcon: _isCheckingUsername
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _usernameError == null &&
                                      _usernameController.text.isNotEmpty
                                ? Icon(
                                    Icons.check_circle,
                                    color: Colors.green[600],
                                  )
                                : null,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(context).set_password_validate_username_required;
                              }
                              if (_usernameError != null) {
                                return _usernameError;
                              }
                              return null;
                            },
                          ),
                          if (_usernameError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _usernameError!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Password Field
                          Text(
                            AppLocalizations.of(context).set_password_password_label,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          CustomInputField(
                            controller: _passwordController,
                            label: AppLocalizations.of(context).set_password_password_label,
                            hintText: AppLocalizations.of(context).set_password_password_hint,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(context).set_password_validate_password_required;
                              }
                              if (value.length < 6) {
                                return AppLocalizations.of(context).set_password_validate_password_min;
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Confirm Password Field
                          Text(
                            AppLocalizations.of(context).set_password_confirm_label,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          CustomInputField(
                            controller: _confirmPasswordController,
                            label: AppLocalizations.of(context).set_password_confirm_label,
                            hintText: AppLocalizations.of(context).set_password_confirm_hint,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(context).set_password_validate_confirm_required;
                              }
                              if (value != _passwordController.text) {
                                return AppLocalizations.of(context).set_password_validate_confirm_match;
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 32),

                          // Create Account Button
                          AppButton(
                            label: _isLoading
                                ? AppLocalizations.of(context).set_password_creating_btn
                                : (_cooldown > 0
                                      ? AppLocalizations.of(context).set_password_wait_btn(_cooldown)
                                      : AppLocalizations.of(context).set_password_create_btn),
                            onPressed: _isLoading || _cooldown > 0
                                ? null
                                : _handleSubmit,
                            isLoading: _isLoading,
                            fullWidth: true,
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
