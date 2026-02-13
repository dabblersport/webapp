import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/selected_country_provider.dart';
import 'package:dabbler/utils/ui_constants.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class AuthWelcomeScreen extends ConsumerStatefulWidget {
  const AuthWelcomeScreen({super.key});

  @override
  ConsumerState<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends ConsumerState<AuthWelcomeScreen> {
  bool _isLoading = false;

  static const List<String> _countries = <String>[
    'United Arab Emirates',
    'Saudi Arabia',
    'Qatar',
    'Kuwait',
    'Bahrain',
    'Oman',
    'Egypt',
    'Jordan',
    'Lebanon',
    'Global',
  ];

  Future<void> _openCountryPicker() async {
    final selected = ref.read(selectedCountryProvider).valueOrNull;

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.colorScheme.brightness == Brightness.dark;
        final tokens = isDark
            ? main_dark_tokens.theme
            : main_light_tokens.theme;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose your country',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tokens.main.onSurface,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _countries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final country = _countries[index];
                  final isSelected = selected == country;
                  return ListTile(
                    title: Text(
                      country,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w800 : null,
                        color: tokens.main.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: tokens.main.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );

    if (!mounted || picked == null) return;
    await ref.read(selectedCountryProvider.notifier).setCountry(picked);
  }

  Future<void> _handleGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);

      // Native Google Sign-In completes in-app
      final launched = await authService.signInWithGoogle();
      if (!launched) {
        // User cancelled
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Check the result after OAuth completes
      final result = await authService.handleGoogleSignInFlow();

      if (!mounted) return;

      // Navigate based on result
      switch (result) {
        case GoogleSignInResultGoToOnboarding():
          // New Google user - go to onboarding
          context.go(RoutePaths.createUserInfo, extra: {'email': result.email});
          break;

        case GoogleSignInResultGoToSetUsername():
          // Legacy case
          context.go(
            RoutePaths.setUsername,
            extra: {
              'email': result.email,
              'suggestedUsername': result.suggestedUsername,
            },
          );
          break;

        case GoogleSignInResultGoToPhoneOtp():
          // New Google user (with phone) - go to OTP
          context.push(
            RoutePaths.otpVerification,
            extra: {
              'phone': result.phone,
              'email': result.email,
              'userExistsBeforeOtp': false,
            },
          );
          break;

        case GoogleSignInResultGoToHome():
          // Existing Google user - navigate to home (welcome screen will show first via router)
          context.go(RoutePaths.home);
          break;

        case GoogleSignInResultRequirePassword():
          // Existing user (non-Google) - require password
          context.push(
            RoutePaths.enterPassword,
            extra: {'email': result.email},
          );
          break;

        case GoogleSignInResultError():
          // Error occurred
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(result.message)));
          }
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not sign in with Google: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleApple() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Apple sign-in is coming soon.')),
    );
  }

  void _handleEmail() {
    context.go(RoutePaths.emailInput);
  }

  void _handleLogin() {
    context.go(RoutePaths.enterPassword);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;
    final countryState = ref.watch(selectedCountryProvider);

    // Country detection priority (via selectedCountryProvider + LocationDetector):
    //   1. IP-derived country (Supabase edge function using ipapi.co)
    //   2. Device locale country (Platform locale settings)
    //   3. Global (safe fallback)
    final countryName = countryState.maybeWhen(
      data: (country) => country,
      orElse: () => 'Global',
    );

    return Scaffold(
      backgroundColor: tokens.main.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: ClipRRect(
          borderRadius: AppRadius.extraExtraLarge,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.main.secondaryContainer),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxl,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: AppSpacing.xl),

                              Row(
                                children: [
                                  Text(
                                    'Welcome',
                                    style: theme.textTheme.displayMedium
                                        ?.copyWith(
                                          color:
                                              tokens.main.onSecondaryContainer,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    '👋',
                                    style: theme.textTheme.displayMedium
                                        ?.copyWith(
                                          color:
                                              tokens.main.onSecondaryContainer,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'We are stoked to have you join us. Create an account and start dabbing in local sports.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: tokens.main.onSecondaryContainer,
                                  height: 1.25,
                                ),
                              ),
                              // const SizedBox(height: AppSpacing.sm),
                              // Text(
                              //   'By signing up you agree to our Terms and Conditions, Privacy Policy and Cookies Policy.',
                              //   style: theme.textTheme.bodyMedium?.copyWith(
                              //     color: tokens.main.onSecondaryContainer,
                              //     height: 1.25,
                              //   ),
                              // ),
                              const SizedBox(height: AppSpacing.xxl),
                              Text(
                                'Built for trust',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: tokens.main.onSecondaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    child: Icon(
                                      Icons.check_circle,
                                      size: AppIconSize.sm,
                                      color: tokens.main.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      'Reviewed players, verified memberships and rated venues',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: tokens
                                                .main
                                                .onSecondaryContainer,
                                            height: 1.25,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    child: Icon(
                                      Icons.check_circle,
                                      size: AppIconSize.sm,
                                      color: tokens.main.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      'Connections and recommendations personalised to your sports',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: tokens
                                                .main
                                                .onSecondaryContainer,
                                            height: 1.25,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    child: Icon(
                                      Icons.check_circle,
                                      size: AppIconSize.sm,
                                      color: tokens.main.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      'We do not sell your data, privacy-first by design',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: tokens
                                                .main
                                                .onSecondaryContainer,
                                            height: 1.25,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: _isLoading ? null : _handleGoogle,
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDark
                                      ? tokens.main.inverseSurface
                                      : tokens.main.surfaceContainerLowest,
                                  foregroundColor: isDark
                                      ? tokens.main.inverseOnSurface
                                      : tokens.main.onSurface,
                                  minimumSize: const Size.fromHeight(
                                    AppButtonSize.extraLargeHeight,
                                  ),
                                  padding: AppButtonSize.extraLargePadding,
                                  shape: const StadiumBorder(),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icons/google.svg',
                                      width: AppIconSize.sm,
                                      height: AppIconSize.sm,
                                      colorFilter: ColorFilter.mode(
                                        isDark
                                            ? tokens.main.inverseOnSurface
                                            : tokens.main.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'Continue with Google',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: isDark
                                                ? tokens.main.inverseOnSurface
                                                : tokens.main.onSurface,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (!kIsWeb &&
                                  defaultTargetPlatform == TargetPlatform.iOS)
                                FilledButton(
                                  onPressed: _isLoading ? null : _handleApple,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: tokens.main.scrim,
                                    foregroundColor: isDark
                                        ? tokens.main.onBackground
                                        : tokens.main.onPrimary,
                                    minimumSize: const Size.fromHeight(
                                      AppButtonSize.extraLargeHeight,
                                    ),
                                    padding: AppButtonSize.extraLargePadding,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/icons/apple.svg',
                                        width: AppIconSize.sm,
                                        height: AppIconSize.sm,
                                        colorFilter: ColorFilter.mode(
                                          isDark
                                              ? tokens.main.onBackground
                                              : tokens.main.onPrimary,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        'Continue with Apple',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: isDark
                                                  ? tokens.main.onBackground
                                                  : tokens.main.onPrimary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (!kIsWeb &&
                                  defaultTargetPlatform == TargetPlatform.iOS)
                                const SizedBox(height: AppSpacing.lg),
                              FilledButton(
                                onPressed: _isLoading ? null : _handleEmail,
                                style: FilledButton.styleFrom(
                                  backgroundColor: tokens.main.primary,
                                  foregroundColor: tokens.main.onPrimary,
                                  minimumSize: const Size.fromHeight(
                                    AppButtonSize.extraLargeHeight,
                                  ),
                                  padding: AppButtonSize.extraLargePadding,
                                  shape: const StadiumBorder(),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.mail_outline,
                                      size: AppIconSize.sm,
                                      color: tokens.main.onPrimary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'Continue with Email',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: tokens.main.onPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Center(
                                child: TextButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  child: Text(
                                    'Already have an account? Log in',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: tokens.main.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),

                              Center(
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: InkWell(
                                    borderRadius: AppRadius.medium,
                                    onTap: _isLoading
                                        ? null
                                        : _openCountryPicker,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.lg,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            countryName,
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: tokens
                                                      .main
                                                      .onSecondaryContainer,
                                                ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            'Change',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: tokens.main.primary,
                                                ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: AppIconSize.sm,
                                            color: tokens.main.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
