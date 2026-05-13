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
import 'package:dabbler/utils/ui_constants.dart';
import 'package:dabbler/widgets/adaptive_auth_shell.dart';
import 'package:dabbler/l10n/app_localizations.dart';

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
  bool _getUpdates = true;

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
    final l10n = AppLocalizations.of(context);
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l10n.email_input_validate_required;
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return l10n.email_input_validate_invalid;
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

      // Seed onboarding data so getUpdates is carried through the flow
      final notifier = ref.read(onboardingDataProvider.notifier);
      if (ref.read(onboardingDataProvider) == null) {
        notifier.initWithEmail(email);
      }
      notifier.setGetUpdates(_getUpdates);

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
        final raw = e.toString();
        final message = raw.startsWith('Exception: ')
            ? raw.substring('Exception: '.length)
            : raw;
        setState(() {
          _errorMessage = kDebugMode
              ? message
              : AppLocalizations.of(context).email_input_error_generic;
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
    final colorScheme = theme.colorScheme;

    return AdaptiveAuthShell(
      backgroundColor: colorScheme.surface,
      containerColor: colorScheme.secondaryContainer,
      resizeToAvoidBottomInset: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    AppLocalizations.of(context).email_input_title,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    AppLocalizations.of(context).email_input_subtitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildTermsTextInline(context),
                  const SizedBox(height: AppSpacing.xxxl * 2),
                  Text(
                    AppLocalizations.of(context).email_input_label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildEmailInputPill(context),
                  const SizedBox(height: AppSpacing.lg),
                  _buildContinueButtonPill(context),
                  const SizedBox(height: AppSpacing.lg),
                  _buildKeepInLoopRow(context),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  const Spacer(),
                  _buildGoogleButton(),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.iOS) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildAppleButton(context),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _goToLogin,
                      child: Text(
                        AppLocalizations.of(context).email_input_already_account,
                        style: theme.textTheme.titleMedium?.copyWith(
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
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return FilledButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: FilledButton.styleFrom(
        backgroundColor: isDark
            ? colorScheme.inverseSurface
            : colorScheme.surfaceContainerLowest,
        foregroundColor: isDark
            ? colorScheme.onInverseSurface
            : colorScheme.onSurface,
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
                  isDark ? colorScheme.onInverseSurface : colorScheme.onSurface,
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
                        ? colorScheme.onInverseSurface
                        : colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppLocalizations.of(context).email_input_btn_google,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark
                        ? colorScheme.onInverseSurface
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppleButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return FilledButton(
      onPressed: _isLoading
          ? null
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).auth_welcome_apple_soon)),
              );
            },
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.scrim,
        foregroundColor: isDark
            ? colorScheme.onSurface
            : colorScheme.onPrimary,
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
              isDark ? colorScheme.onSurface : colorScheme.onPrimary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            AppLocalizations.of(context).email_input_btn_apple,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
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
          _errorMessage = AppLocalizations.of(context).email_input_google_failed;
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
          hintText: AppLocalizations.of(context).email_input_hint,
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
          : Text(AppLocalizations.of(context).email_input_continue),
    );
  }

  Widget _buildKeepInLoopRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            AppLocalizations.of(context).email_input_keep_in_loop,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Switch(
          value: _getUpdates,
          onChanged: _isLoading
              ? null
              : (v) {
                  setState(() => _getUpdates = v);
                  ref
                      .read(onboardingDataProvider.notifier)
                      .setGetUpdates(v);
                },
          activeThumbColor: colorScheme.primary,
        ),
      ],
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
          TextSpan(
            text: AppLocalizations.of(context).email_input_terms_prefix,
          ),
          TextSpan(
            text: AppLocalizations.of(context).email_input_terms_link,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () =>
                  _openExternalUrl('https://www.dabbler.pro/terms.html'),
          ),
          TextSpan(text: AppLocalizations.of(context).email_input_terms_and),
          TextSpan(
            text: AppLocalizations.of(context).email_input_privacy_link,
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
