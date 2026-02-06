import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/utils/ui_constants.dart';

class EmailInputScreen extends ConsumerStatefulWidget {
  const EmailInputScreen({super.key});

  @override
  ConsumerState<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends ConsumerState<EmailInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _isEmailValid = false;
  bool _keepInLoop = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  void _onEmailChanged(String value) {
    final isValid = _validateEmail(value) == null;
    if (isValid != _isEmailValid) {
      setState(() {
        _isEmailValid = isValid;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      // Check if user exists in the system
      final authService = ref.read(authServiceProvider);
      final userExists = await authService.checkUserExistsByEmail(email);

      // Always use OTP for email, regardless of whether the user exists.
      // Password-based login remains available elsewhere but is not used here.
      await authService.sendOtp(identifier: email, type: IdentifierType.email);

      if (!mounted) return;

      // Navigate to OTP verification screen
      context.push(
        RoutePaths.otpVerification,
        extra: {
          'identifier': email,
          'identifierType': IdentifierType.email.name,
          'userExistsBeforeOtp': userExists,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
        });
      }
      return; // Don't navigate if there's an error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    // Kept for existing widget helpers that still use ColorScheme.
    final colorScheme = theme.colorScheme;

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
                    physics: const BouncingScrollPhysics(),
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpacing.xxxl),
                              Text(
                                'Authenticate',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: tokens.main.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                'Enter your email to get started',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: tokens.main.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _buildTermsTextInline(context),
                              const SizedBox(height: AppSpacing.xxxl * 2),
                              Text(
                                'Email',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.main.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _buildEmailInputPill(context),
                              const SizedBox(height: AppSpacing.lg),
                              _buildContinueButtonPill(context),
                              const SizedBox(height: AppSpacing.lg),
                              _buildKeepInLoopRow(context),
                              const Spacer(),
                              _buildGoogleButton(),
                              if (!kIsWeb &&
                                  defaultTargetPlatform ==
                                      TargetPlatform.iOS) ...[
                                const SizedBox(height: AppSpacing.md),
                                _buildAppleButton(context),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              Center(
                                child: TextButton(
                                  onPressed: _isLoading ? null : _goToLogin,
                                  child: Text(
                                    'Already have an account? Log in',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.primary,
                                        ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: AppSpacing.xxl),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                _InlineMessage(
                                  message: _errorMessage!,
                                  color: colorScheme.error,
                                ),
                              ],
                              if (_successMessage != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                _InlineMessage(
                                  message: _successMessage!,
                                  color: Colors.green,
                                ),
                              ],
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

  Widget _buildGoogleButton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    return FilledButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: FilledButton.styleFrom(
        backgroundColor: isDark
            ? tokens.main.inverseSurface
            : tokens.main.surfaceContainerLowest,
        foregroundColor: isDark
            ? tokens.main.inverseOnSurface
            : tokens.main.onSurface,
        minimumSize: const Size.fromHeight(AppButtonSize.extraLargeHeight),
        padding: AppButtonSize.extraLargePadding,
        shape: const StadiumBorder(),
      ),
      child: _isLoading
          ? SizedBox(
              height: AppSpacing.xxl,
              width: AppSpacing.xxl,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? tokens.main.inverseOnSurface : tokens.main.onSurface,
                ),
              ),
            )
          : Row(
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark
                        ? tokens.main.inverseOnSurface
                        : tokens.main.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppleButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    return FilledButton(
      onPressed: _isLoading
          ? null
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Apple sign-in is coming soon.')),
              );
            },
      style: FilledButton.styleFrom(
        backgroundColor: tokens.main.scrim,
        foregroundColor: isDark
            ? tokens.main.onBackground
            : tokens.main.onPrimary,
        minimumSize: const Size.fromHeight(AppButtonSize.extraLargeHeight),
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
              isDark ? tokens.main.onBackground : tokens.main.onPrimary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Continue with Apple',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? tokens.main.onBackground : tokens.main.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // Token-based Google Sign-In (native / popup) should complete in-app.
      final launched = await authService.signInWithGoogle();
      if (!launched) {
        // User cancelled.
        return;
      }

      // Now check the result after OAuth completes
      final result = await authService.handleGoogleSignInFlow();

      if (!mounted) return;

      // Navigate based on result
      switch (result) {
        case GoogleSignInResultGoToOnboarding():
          // New Google user (email only) - go to full onboarding flow
          ref.read(onboardingDataProvider.notifier).initWithEmail(result.email);
          context.go(RoutePaths.createUserInfo, extra: {'email': result.email});
          break;

        case GoogleSignInResultGoToSetUsername():
          // Legacy case - should not be used for new Google users
          ref.read(onboardingDataProvider.notifier).initWithEmail(result.email);
          context.go(
            RoutePaths.setUsername,
            extra: {
              'email': result.email,
              'suggestedUsername': result.suggestedUsername,
            },
          );
          break;

        case GoogleSignInResultGoToPhoneOtp():
          // New Google user (email + phone) - go to OTP verification
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
          // Existing Google user - let router handle navigation
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
          setState(() {
            _errorMessage = result.message;
          });
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google sign-in failed. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildEmailInputPill(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final borderRadius = BorderRadius.circular(999);

    return Form(
      key: _formKey,
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.done,
        onChanged: _onEmailChanged,
        validator: _validateEmail,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'email@domain.com',
          hintStyle: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: colorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButtonPill(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canSubmit = _isEmailValid && !_isLoading;

    return FilledButton(
      onPressed: canSubmit ? _handleSubmit : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Continue'),
    );
  }

  Widget _buildKeepInLoopRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isLoading
          ? null
          : () {
              setState(() => _keepInLoop = !_keepInLoop);
            },
      child: Container(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: _keepInLoop,
              onChanged: _isLoading
                  ? null
                  : (v) => setState(() => _keepInLoop = v ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              activeColor: colorScheme.primary,
              checkColor: colorScheme.onPrimary,
              side: BorderSide(color: colorScheme.primary, width: 2),
            ),
            Expanded(
              child: Text(
                'Keep me in the loop with emails about updates & more',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsTextInline(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          height: 1.35,
        ),
        children: [
          const TextSpan(
            text:
                'By clicking Continue, you are indicating that you have read and agree to the ',
          ),
          TextSpan(
            text: 'Terms of Service',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () =>
                  _openExternalUrl('https://www.dabbler.pro/terms.html'),
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () =>
                  _openExternalUrl('https://www.dabbler.pro/privacy.html'),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _goToLogin() {
    context.go(RoutePaths.enterPassword);
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color.withValues(alpha: 0.10);
    final border = color.withValues(alpha: 0.30);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
