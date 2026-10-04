import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show TextInputAction, TextInputType, AutofillHints;
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
  bool _isLoading = false;
  String? _passwordError;
  bool _isEmailValid = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;

  // Email regex shared by the validity check and the OTP hand-off.
  static final RegExp _emailRegExp = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

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

  void _toastError(String message) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));
  }

  void _onEmailChanged(String value) {
    setState(() {
      _emailTouched = true;
      _isEmailValid = _isEmailFormatValid(value);
    });
  }

  /// Validation shown live under the email field once it has been edited.
  String? _emailError(AppLocalizations l10n) {
    if (!_emailTouched) return null;
    if (_emailController.text.trim().isEmpty) {
      return l10n.email_password_validate_email_required;
    }
    return _isEmailValid ? null : l10n.email_password_validate_email_invalid;
  }

  /// The wrong-credentials message, else the live "enter a password" one.
  String? _passwordMessage(AppLocalizations l10n) {
    if (_passwordError != null) return _passwordError;
    if (_passwordTouched && _passwordController.text.isEmpty) {
      return l10n.email_password_validate_password_required;
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_isEmailValid) return;
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordTouched = true);
      return;
    }

    setState(() {
      _isLoading = true;
      _passwordError = null;
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
        setState(
          () => _passwordError = AppLocalizations.of(
            context,
          ).email_password_error_invalid_creds,
        );
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
      if (isInvalidCreds) {
        setState(
          () => _passwordError = AppLocalizations.of(
            context,
          ).email_password_error_invalid_creds,
        );
      } else {
        _toastError(
          AppLocalizations.of(context).email_password_error_login_failed,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendEmailOtp() async {
    if (!_isEmailValid) {
      _toastError(
        AppLocalizations.of(context).email_password_validate_email_hint,
      );
      return;
    }

    setState(() => _isLoading = true);

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
      _toastError(AppLocalizations.of(context).email_password_error_otp_failed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

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
          _toastError(result.message);
          break;
      }
    } catch (e) {
      if (mounted) {
        _toastError(AppLocalizations.of(context).email_password_google_failed);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);

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
          _toastError(result.message);
          break;
      }
    } catch (e) {
      if (mounted) _toastError('Apple sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showApple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    final List<Widget> body = <Widget>[
      DabblerTextField(
        controller: _emailController,
        label: l10n.email_input_label,
        placeholder: l10n.email_password_hint_email,
        errorText: _emailError(l10n),
        enabled: !_isLoading,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        onChanged: _onEmailChanged,
      ),
      DabblerTextField(
        variant: DabblerTextFieldVariant.password,
        controller: _passwordController,
        label: l10n.email_password_hint_password,
        errorText: _passwordMessage(l10n),
        enabled: !_isLoading,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {
          _passwordTouched = true;
          _passwordError = null;
        }),
        onSubmitted: (_) {
          if (_isEmailValid && !_isLoading) _handleLogin();
        },
      ),
    ];

    return DabblerFlowPage(
      onBack: () =>
          context.canPop() ? context.pop() : context.go(RoutePaths.authWelcome),
      backLabel: l10n.auth_back,
      title: l10n.email_password_title,
      titleStyle: DabblerType.largeTitle,
      subtitle: l10n.email_password_subtitle,
      subtitleStyle: DabblerType.body,
      primaryLabel: l10n.email_password_login_btn,
      primaryLoading: _isLoading,
      onPrimary: _isEmailValid && !_isLoading ? _handleLogin : null,
      secondary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: DabblerTextLink(
              label: l10n.email_password_send_otp,
              underline: false,
              onPressed: _isLoading || !_isEmailValid
                  ? null
                  : _handleSendEmailOtp,
            ),
          ),
          DabblerDivider(label: l10n.auth_or),
          const DabblerGap.v(DabblerSpacing.space4),
          DabblerButton(
            label: l10n.email_password_btn_google,
            tone: DabblerButtonTone.outlined,
            size: DabblerButtonSize.full,
            fullWidth: true,
            disabled: _isLoading,
            onPressed: _isLoading ? null : _handleGoogleSignIn,
          ),
          if (showApple) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space4),
            DabblerButton(
              label: l10n.email_password_btn_apple,
              tone: DabblerButtonTone.outlined,
              size: DabblerButtonSize.full,
              fullWidth: true,
              disabled: _isLoading,
              onPressed: _isLoading ? null : _handleAppleSignIn,
            ),
          ],
          const DabblerGap.v(DabblerSpacing.space4),
          AuthAccountLine(
            prefix: l10n.auth_new_here,
            action: l10n.auth_create_account,
            onAction: _isLoading
                ? null
                : () => context.go(RoutePaths.emailInput),
          ),
        ],
      ),
      content: body,
    );
  }
}
