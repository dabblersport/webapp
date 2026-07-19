import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/widgets/legal_doc_sheet.dart';

import '../providers/auth_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class EnterPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const EnterPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<EnterPasswordScreen> createState() =>
      _EnterPasswordScreenState();
}

class _EnterPasswordScreenState extends ConsumerState<EnterPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEmailValid = false;

  static const double _controlFontSize = 16;

  TextStyle? _controlTextStyle(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return theme.textTheme.titleMedium?.copyWith(
      fontSize: _controlFontSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? colorScheme.onSurface,
    );
  }

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
    if (isValid != _isEmailValid) {
      setState(() => _isEmailValid = isValid);
    }
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SafeArea(
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
                            AppLocalizations.of(context).email_password_title,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            AppLocalizations.of(context).email_password_subtitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 56),
                          // Text(
                          //   'Email',
                          //   style: theme.textTheme.titleMedium?.copyWith(
                          //     fontWeight: FontWeight.w700,
                          //     color: colorScheme.onSurface,
                          //   ),
                          // ),
                          // const SizedBox(height: 14),
                          _buildEmailField(context),
                          const SizedBox(height: 16),
                          // Text(
                          //   'Password',
                          //   style: theme.textTheme.titleMedium?.copyWith(
                          //     fontWeight: FontWeight.w700,
                          //     color: colorScheme.onSurface,
                          //   ),
                          // ),
                          // const SizedBox(height: 14),
                          _buildPasswordField(context),
                          if (_showForgotPassword) ...[
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => context.go(
                                        RoutePaths.forgotPassword,
                                        extra: {
                                          'email': _emailController.text.trim(),
                                        },
                                      ),
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).email_password_forgot,
                                  style: _controlTextStyle(
                                    context,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildLoginButton(context),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: _isLoading || !_isEmailValid
                                  ? null
                                  : _handleSendEmailOtp,
                              child: Text(
                                AppLocalizations.of(context).email_password_send_otp,
                                style: _controlTextStyle(
                                  context,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _InlineMessage(
                              message: _errorMessage!,
                              color: colorScheme.error,
                            ),
                          ],
                          const Spacer(),
                          _buildGoogleButton(),
                          if (!kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.iOS) ...[
                            const SizedBox(height: 14),
                            _buildAppleButton(context),
                          ],
                          const SizedBox(height: 12),
                          _buildSignUpRedirect(context),
                          const SizedBox(height: 16),
                          _buildTermsFooter(context),
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
        ),
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(999);

    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.next,
      onChanged: _onEmailChanged,
      validator: _validateEmail,
      style: _controlTextStyle(
        context,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).email_password_hint_email,
        hintStyle: _controlTextStyle(
          context,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
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
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(999);

    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
      textInputAction: TextInputAction.done,
      style: _controlTextStyle(
        context,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).email_password_hint_password,
        hintStyle: _controlTextStyle(
          context,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
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
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            tooltip: _obscurePassword ? AppLocalizations.of(context).email_password_show_password : AppLocalizations.of(context).email_password_hide_password,
            icon: Icon(
              _obscurePassword ? Iconsax.eye_copy : Iconsax.eye_slash_copy,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: _isLoading
                ? null
                : () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
      validator: (v) => v == null || v.isEmpty ? AppLocalizations.of(context).email_password_validate_password_required : null,
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canSubmit = _isEmailValid && !_isLoading;

    return FilledButton(
      onPressed: canSubmit ? _handleLogin : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        shape: const StadiumBorder(),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        textStyle: _controlTextStyle(
          context,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimary,
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(AppLocalizations.of(context).email_password_login_btn),
    );
  }

  Widget _buildGoogleButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.outlineVariant),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      child: _isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.onSurface,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.google_1,
                  size: 22,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).email_password_btn_google,
                  style: _controlTextStyle(
                    context,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppleButton(BuildContext context) {
    return FilledButton(
      onPressed: _isLoading ? null : _handleAppleSignIn,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        backgroundColor: const Color(0xFF2C2A33),
        foregroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Iconsax.apple,
            size: 22,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context).email_password_btn_apple,
            style: _controlTextStyle(
              context,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpRedirect(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: TextButton(
        onPressed: _isLoading
            ? null
            : () => context.go(RoutePaths.emailInput),
        child: Text.rich(
          TextSpan(
            text: 'Not a user? ',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            children: [
              TextSpan(
                text: 'Sign up',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final linkStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.primary,
    );

    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
        children: [
          TextSpan(text: AppLocalizations.of(context).email_input_terms_prefix),
          TextSpan(
            text: AppLocalizations.of(context).email_input_terms_link,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => showTermsSheet(context),
          ),
          TextSpan(text: AppLocalizations.of(context).email_input_terms_and),
          TextSpan(
            text: AppLocalizations.of(context).email_input_privacy_link,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => showPrivacySheet(context),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
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
