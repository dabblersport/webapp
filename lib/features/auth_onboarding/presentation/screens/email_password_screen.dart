import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/pending_auth_email_provider.dart';
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

import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/core/services/auth_service.dart';
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
  bool _profileCheckFailed = false;
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
    // The route's email wins; otherwise the one typed on /email_input.
    final initial = widget.email.isNotEmpty
        ? widget.email
        : ref.read(pendingAuthEmailProvider);
    _emailController.text = initial;
    _isEmailValid = _isEmailFormatValid(initial);
  }

  @override
  void dispose() {
    routerRefreshNotifier.releaseProfileHold();
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
    ref.read(pendingAuthEmailProvider.notifier).set(value);
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
    return _isEmailValid ? null : l10n.auth_email_invalid;
  }

  /// The wrong-credentials message, else the live "enter a password" one.
  String? _passwordMessage(AppLocalizations l10n) {
    if (_passwordError != null) return _passwordError;
    if (_passwordTouched && _passwordController.text.isEmpty) {
      return l10n.email_password_validate_password_required;
    }
    return null;
  }

  /// KAN-602: route on the three profile-lookup outcomes. Only a CONFIRMED
  /// absence goes to onboarding; a lookup that could not be completed keeps
  /// the user here, signed in, with their input intact and a retry.
  Future<void> _checkProfileAndRoute(
    AuthService authService,
    String email,
  ) async {
    final lookup = await authService.lookupUserProfile(
      fields: ['id', 'onboard', 'display_name', 'intention'],
    );
    if (!mounted) return;

    if (lookup is! ProfileLookupCouldNotCheck) {
      routerRefreshNotifier.releaseProfileHold();
    }

    switch (lookup) {
      case ProfileLookupFound(:final profile):
        final isOnboarded =
            profile['onboard'] == true || profile['onboard'] == 'true';
        if (isOnboarded) {
          final displayName = profile['display_name'] as String? ?? '';
          final personaType = profile['intention'] as String? ?? 'player';
          context.go(
            RoutePaths.welcome,
            extra: {
              'displayName': displayName,
              'personaType': personaType,
              'isFirstTime': false,
            },
          );
        } else {
          // Profile exists but onboard == false — let router redirect handle it
          context.go(RoutePaths.home);
        }
      case ProfileLookupConfirmedNoProfile():
        context.go(RoutePaths.createUserInfo, extra: {'email': email});
      case ProfileLookupCouldNotCheck():
        setState(() => _profileCheckFailed = true);
    }
  }

  /// Retries only the profile lookup; the sign-in already succeeded.
  Future<void> _retryProfileCheck() async {
    setState(() {
      _isLoading = true;
      _profileCheckFailed = false;
    });
    try {
      await _checkProfileAndRoute(
        ref.read(authServiceProvider),
        _emailController.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      _profileCheckFailed = false;
    });
    // KAN-602: the sign-in event must not move the router on before the
    // profile check has run (see RouterRefreshNotifier.holdForProfile).
    routerRefreshNotifier.holdForProfile();

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
          ).auth_login_password_wrong,
        );
        return;
      }

      // The sign-in itself succeeded. Anything that fails from here on is a
      // profile/session/bootstrap failure, NOT a rejected login (KAN-570): it
      // gets its own message so the user is not told their login failed.
      try {
        await ref.read(simpleAuthProvider.notifier).handleSuccessfulLogin();
        if (!mounted) return;

        await _checkProfileAndRoute(authService, email);
      } catch (_) {
        if (!mounted) return;
        _toastError(
          AppLocalizations.of(context).email_password_error_profile_failed,
        );
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
          ).auth_login_password_wrong,
        );
      } else {
        _toastError(
          AppLocalizations.of(context).email_password_error_login_failed,
        );
      }
    } finally {
      if (!_profileCheckFailed) routerRefreshNotifier.releaseProfileHold();
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
      AnalyticsService.trackOAuthSignup(result, provider: 'google');
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
      AnalyticsService.trackOAuthSignup(result, provider: 'apple');
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
        borderOutside: true,
        controller: _emailController,
        label: l10n.auth_email_label,
        placeholder: l10n.auth_email_placeholder,
        errorText: _emailError(l10n),
        enabled: !_isLoading,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        onChanged: _onEmailChanged,
      ),
      DabblerTextField(
        borderOutside: true,
        variant: DabblerTextFieldVariant.password,
        mutedPasswordToggle: true,
        controller: _passwordController,
        label: l10n.auth_login_password_label,
        placeholder: l10n.auth_login_password_placeholder,
        errorText: _passwordMessage(l10n),
        enabled: !_isLoading,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {
          _passwordTouched = true;
          _passwordError = null;
          _profileCheckFailed = false;
        }),
        onSubmitted: (_) {
          if (_isEmailValid && !_isLoading) _handleLogin();
        },
      ),
      if (_profileCheckFailed)
        DabblerInlineMessage(l10n.auth_profile_check_failed),
    ];

    // Keyboard open: only the title, fields, Log in and the code link stay
    // above it; the back row and the "or" group are out of the way.
    final keyboard = authKeyboardOpen(context);
    final tight = authKeyboardTight(context);
    final Widget codeLink = Center(
      child: DabblerTextLink(
        label: l10n.auth_login_email_code,
        style: authLinkStyle(context, DabblerType.copy),
        inline: true,
        underline: false,
        onPressed: _isLoading || !_isEmailValid ? null : _handleSendEmailOtp,
      ),
    );

    return DabblerFlowPage(
      onBack: keyboard
          ? null
          : () => context.canPop()
                ? context.pop()
                : context.go(RoutePaths.authWelcome),
      backLabel: l10n.auth_back,
      title: l10n.auth_login_title,
      titleStyle: DabblerType.displayScreen,
      titleGap: keyboard ? DabblerSpacing.space2 : DabblerSpacing.space3,
      headerTopPadding: DabblerSpacing.space4,
      bodyTopPadding: keyboard ? DabblerSpacing.space4 : DabblerSpacing.space6,
      bodyGap: keyboard ? DabblerSpacing.space4 : DabblerSpacing.space6,
      subtitle: tight ? null : l10n.auth_login_subtitle,
      subtitleStyle: DabblerType.lead,
      primaryLabel: _profileCheckFailed
          ? l10n.auth_profile_check_retry
          : l10n.auth_login_button,
      primaryLoading: _isLoading,
      onPrimary: _isEmailValid && !_isLoading
          ? (_profileCheckFailed ? _retryProfileCheck : _handleLogin)
          : null,
      footerBottomPadding: keyboard
          ? DabblerSpacing.space4
          : DabblerSpacing.space8,
      secondary: keyboard
          ? codeLink
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                codeLink,
                const DabblerGap.v(DabblerSpacing.space4),
                DabblerDivider(label: l10n.auth_or),
                const DabblerGap.v(DabblerSpacing.space4),
                DabblerButton(
                  label: l10n.auth_entry_continue_google,
                  tone: DabblerButtonTone.outlined,
                  size: DabblerButtonSize.full,
                  fullWidth: true,
                  disabled: _isLoading,
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                ),
                if (showApple) ...<Widget>[
                  const DabblerGap.v(DabblerSpacing.space4),
                  DabblerButton(
                    label: l10n.auth_entry_continue_apple,
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
