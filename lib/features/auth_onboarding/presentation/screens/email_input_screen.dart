import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/widgets/legal_doc_sheet.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_widgets.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SafeArea(
        child: Column(
          children: [
            OnboardingTopBar(
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(RoutePaths.authWelcome),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnboardingScreenHead(
                      title: AppLocalizations.of(context).email_input_title,
                      subtitle: AppLocalizations.of(
                        context,
                      ).email_input_subtitle,
                    ),
                    _buildTermsTextInline(context),
                    const SizedBox(height: 28),
                    Text(
                      AppLocalizations.of(context).email_input_label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildEmailInputPill(context),
                    const SizedBox(height: 16),
                    _buildKeepInLoopRow(context),
                    const SizedBox(height: 24),
                    _buildContinueButtonPill(context),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _InlineMessage(
                        message: _errorMessage!,
                        color: colorScheme.error,
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 12),
                      _InlineMessage(
                        message: _successMessage!,
                        color: Colors.green,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: colorScheme.outlineVariant),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: colorScheme.outlineVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildGoogleButton(),
                    if (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.iOS) ...[
                      const SizedBox(height: 12),
                      _buildAppleButton(context),
                    ],
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _goToLogin,
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).email_input_already_account,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerLowest,
          side: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.google_1,
                    size: 20,
                    color: colorScheme.onSurface,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context).email_input_btn_google,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAppleButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleAppleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF2C2A33),
          side: BorderSide.none,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Iconsax.apple,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).email_input_btn_apple,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      final signedIn = await authService.signInWithApple();
      if (!signedIn) return; // User cancelled the Apple sheet.

      final result = await authService.handleAppleSignInFlow();
      if (!mounted) return;

      switch (result) {
        case GoogleSignInResultGoToOnboarding():
          ref.read(onboardingDataProvider.notifier).initWithEmail(result.email);
          context.go(RoutePaths.createUserInfo, extra: {'email': result.email});
          break;
        case GoogleSignInResultGoToSetUsername():
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
          context.go(RoutePaths.home);
          break;
        case GoogleSignInResultRequirePassword():
          context.push(
            RoutePaths.enterPassword,
            extra: {'email': result.email},
          );
          break;
        case GoogleSignInResultError():
          setState(() => _errorMessage = result.message);
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Apple sign-in failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          setState(() {
            _errorMessage = AppLocalizations.of(context).email_input_google_failed;
          });
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          ).email_input_google_failed;
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
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(16);

    return Form(
      key: _formKey,
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.done,
        onChanged: _onEmailChanged,
        validator: _validateEmail,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).email_input_hint,
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.mail_outline,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: _emailController.text.isNotEmpty
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isEmailValid
                      ? Container(
                          key: const ValueKey('valid'),
                          margin: const EdgeInsets.all(10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00C853,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '✓',
                            style: TextStyle(
                              color: Color(0xFF00C853),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey('invalid'),
                          margin: const EdgeInsets.all(10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '✗',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: colorScheme.outlineVariant,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButtonPill(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canSubmit = _isEmailValid && !_isLoading;
    return OnboardingCTAButton(
      label: AppLocalizations.of(context).email_input_continue,
      onPressed: canSubmit ? _handleSubmit : null,
      isLoading: _isLoading,
      // icon: Icon(Icons.arrow_forward, size: 18, color: colorScheme.onPrimary),
    );
  }

  Widget _buildKeepInLoopRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            AppLocalizations.of(context).email_input_keep_in_loop,
            style: TextStyle(
              fontSize: 14,
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
                  ref.read(onboardingDataProvider.notifier).setGetUpdates(v);
                },
          activeTrackColor: colorScheme.primary,
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
          TextSpan(text: AppLocalizations.of(context).email_input_terms_prefix),
          TextSpan(
            text: AppLocalizations.of(context).email_input_terms_link,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => showTermsSheet(context),
          ),
          TextSpan(text: AppLocalizations.of(context).email_input_terms_and),
          TextSpan(
            text: AppLocalizations.of(context).email_input_privacy_link,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => showPrivacySheet(context),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
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
