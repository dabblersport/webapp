import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextInputAction, TextInputType, AutofillHints;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';

class EnterPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const EnterPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<EnterPasswordScreen> createState() =>
      _EnterPasswordScreenState();
}

class _EnterPasswordScreenState extends ConsumerState<EnterPasswordScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEmailValid = false;

  // Forgot Password is hidden on the login screen for now.
  static const bool _showForgotPassword = false;

  // Email regex shared by the localized validator and the context-free check.
  static final RegExp _emailRegExp = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  /// Format-only validity check that does NOT touch Localizations, so it is
  /// safe to call from initState (before dependencies are available).
  bool _isEmailFormatValid(String? value) {
    final email = value?.trim() ?? '';
    return email.isNotEmpty && _emailRegExp.hasMatch(email);
  }

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
    _isEmailValid = _isEmailFormatValid(widget.email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final l10n = AppLocalizations.of(context);
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l10n.email_password_validate_email_required;
    if (!_emailRegExp.hasMatch(email)) {
      return l10n.email_password_validate_email_invalid;
    }
    return null;
  }

  void _onEmailChanged(String value) {
    final isValid = _isEmailFormatValid(value);
    if (isValid != _isEmailValid || _emailError != null) {
      setState(() {
        _isEmailValid = isValid;
        _emailError = null;
      });
    }
  }

  Future<void> _handleLogin() async {
    final emailError = _validateEmail(_emailController.text);
    final passwordError = _passwordController.text.isEmpty
        ? AppLocalizations.of(context).email_password_validate_password_required
        : null;
    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
      });
      return;
    }

    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (result.user == null) {
        if (!mounted) return;
        setState(() => _errorMessage = AppLocalizations.of(context).email_password_error_invalid_creds);
        return;
      }

      await ref.read(simpleAuthProvider.notifier).handleSuccessfulLogin();
      if (!mounted) return;

      // Check if user has completed onboarding before going home
      // (mirrors the logic in otp_verification_screen)
      final userProfile = await AuthService().getUserProfile(
        fields: ['id', 'onboard', 'display_name', 'intention'],
      );
      if (!mounted) return;

      final isOnboarded =
          userProfile != null &&
          (userProfile['onboard'] == true || userProfile['onboard'] == 'true');

      if (isOnboarded) {
        final displayName = userProfile['display_name'] as String? ?? '';
        final personaType = userProfile['intention'] as String? ?? 'player';
        context.go(
          RoutePaths.welcome,
          extra: {
            'displayName': displayName,
            'personaType': personaType,
            'isFirstTime': false,
          },
        );
      } else if (userProfile == null) {
        // No profile at all — go to onboarding
        context.go(RoutePaths.createUserInfo, extra: {'email': email});
      } else {
        // Profile exists but onboard == false — let router redirect handle it
        context.go(RoutePaths.home);
      }
    } catch (e) {
      final errText = e.toString().toLowerCase();
      final isInvalidCreds =
          errText.contains('invalid login credentials') ||
          errText.contains('invalid_credentials') ||
          errText.contains('invalid email or password') ||
          errText.contains('email not confirmed');
      if (!mounted) return;
      setState(() {
        _errorMessage = isInvalidCreds
            ? AppLocalizations.of(context).email_password_error_invalid_creds
            : AppLocalizations.of(context).email_password_error_login_failed;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendEmailOtp() async {
    if (_validateEmail(_emailController.text) != null) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).email_password_validate_email_hint;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      // Check if user exists in the system
      final authService = ref.read(authServiceProvider);
      final userExists = await authService.checkUserExistsByEmail(email);

      // Always use OTP for email, regardless of whether the user exists
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
      if (!mounted) return;
      setState(() => _errorMessage = AppLocalizations.of(context).email_password_error_otp_failed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      final launched = await authService.signInWithGoogle();
      if (!launched) return;

      final result = await authService.handleGoogleSignInFlow();
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
          _emailController.text = result.email;
          _onEmailChanged(result.email);
          break;
        case GoogleSignInResultError():
          setState(() => _errorMessage = result.message);
          break;
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AppLocalizations.of(context).email_password_google_failed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
          _emailController.text = result.email;
          _onEmailChanged(result.email);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    return DabblerPage(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        DabblerSpacing.space8,
                        DabblerSpacing.space10,
                        DabblerSpacing.space8,
                        DabblerSpacing.space8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.email_password_title,
                            style: authText(
                              context,
                              DabblerType.largeTitle,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: DabblerSpacing.space3),
                          Text(
                            l10n.email_password_subtitle,
                            style: authText(
                              context,
                              DabblerType.body,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: DabblerSpacing.space8),
                          _buildEmailField(context),
                          const SizedBox(height: DabblerSpacing.space5),
                          _buildPasswordField(context),
                          if (_showForgotPassword) ...[
                            const SizedBox(height: DabblerSpacing.space4),
                            DabblerButton(
                              label: l10n.email_password_forgot,
                              tone: DabblerButtonTone.text,
                              fullWidth: true,
                              disabled: _isLoading,
                              onPressed: _isLoading
                                  ? null
                                  : () => context.go(
                                      RoutePaths.forgotPassword,
                                      extra: {
                                        'email': _emailController.text.trim(),
                                      },
                                    ),
                            ),
                          ],
                          const SizedBox(height: DabblerSpacing.space6),
                          DabblerButton(
                            label: l10n.email_password_login_btn,
                            size: DabblerButtonSize.full,
                            fullWidth: true,
                            loading: _isLoading,
                            disabled: !(_isEmailValid && !_isLoading),
                            onPressed: (_isEmailValid && !_isLoading)
                                ? _handleLogin
                                : null,
                          ),
                          const SizedBox(height: DabblerSpacing.space2),
                          DabblerButton(
                            label: l10n.email_password_send_otp,
                            tone: DabblerButtonTone.text,
                            fullWidth: true,
                            disabled: _isLoading || !_isEmailValid,
                            onPressed: _isLoading || !_isEmailValid
                                ? null
                                : _handleSendEmailOtp,
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: DabblerSpacing.space5),
                            AuthInlineMessage(message: _errorMessage!),
                          ],
                          const Spacer(),
                          const SizedBox(height: DabblerSpacing.space6),
                          DabblerButton(
                            label: l10n.email_password_btn_google,
                            tone: DabblerButtonTone.outlined,
                            size: DabblerButtonSize.full,
                            fullWidth: true,
                            disabled: _isLoading,
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                          ),
                          if (!kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.iOS) ...[
                            const SizedBox(height: DabblerSpacing.space4),
                            DabblerButton(
                              label: l10n.email_password_btn_apple,
                              tone: DabblerButtonTone.outlined,
                              size: DabblerButtonSize.full,
                              fullWidth: true,
                              disabled: _isLoading,
                              onPressed: _isLoading ? null : _handleAppleSignIn,
                            ),
                          ],
                          const SizedBox(height: DabblerSpacing.space4),
                          _buildSignUpRedirect(context),
                          const SizedBox(height: DabblerSpacing.space5),
                          const AuthLegalNotice(),
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
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return DabblerTextField(
      controller: _emailController,
      placeholder: AppLocalizations.of(context).email_password_hint_email,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.next,
      onChanged: _onEmailChanged,
      errorText: _emailError,
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return DabblerTextField(
      variant: DabblerTextFieldVariant.password,
      controller: _passwordController,
      placeholder: AppLocalizations.of(context).email_password_hint_password,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        if (!_isLoading) _handleLogin();
      },
      onChanged: (_) {
        if (_passwordError != null) setState(() => _passwordError = null);
      },
      errorText: _passwordError,
    );
  }

  Widget _buildSignUpRedirect(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Not a user?',
          style: authText(
            context,
            DabblerType.subheadline,
            color: colors.textSecondary,
          ),
        ),
        DabblerButton(
          label: 'Sign up',
          tone: DabblerButtonTone.text,
          size: DabblerButtonSize.small,
          disabled: _isLoading,
          onPressed: _isLoading ? null : () => context.go(RoutePaths.emailInput),
        ),
      ],
    );
  }
}
