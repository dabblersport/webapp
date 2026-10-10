import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/pending_auth_email_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show AutofillHints, TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmailInputScreen extends ConsumerStatefulWidget {
  const EmailInputScreen({super.key});

  @override
  ConsumerState<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends ConsumerState<EmailInputScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isEmailValid = false;
  bool _emailTouched = false;
  bool _getUpdates = true;

  @override
  void initState() {
    super.initState();
    // Coming back from /enter-password: show the email typed earlier.
    final pending = ref.read(pendingAuthEmailProvider);
    if (pending.isNotEmpty) {
      _emailController.text = pending;
      _isEmailValid = _emailRegExp.hasMatch(pending);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  static final RegExp _emailRegExp = RegExp(
    r'^[\w+\-.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  void _toastError(String message) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));
  }

  void _onEmailChanged(String value) {
    ref.read(pendingAuthEmailProvider.notifier).set(value);
    setState(() {
      _emailTouched = true;
      _isEmailValid = _emailRegExp.hasMatch(value.trim());
    });
  }

  /// Validation shown live under the field once it has been edited.
  String? _emailError(AppLocalizations l10n) {
    if (!_emailTouched) return null;
    if (_emailController.text.trim().isEmpty) {
      return l10n.email_input_validate_required;
    }
    return _isEmailValid ? null : l10n.auth_email_invalid;
  }

  Future<void> _handleSubmit() async {
    if (!_isEmailValid) return;

    setState(() => _isLoading = true);

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
        _toastError(
          kDebugMode
              ? message
              : AppLocalizations.of(context).email_input_error_generic,
        );
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
        textInputAction: TextInputAction.done,
        onChanged: _onEmailChanged,
        onSubmitted: (_) {
          if (_isEmailValid && !_isLoading) _handleSubmit();
        },
      ),
      Row(
        children: <Widget>[
          Expanded(
            child: DabblerText(
              l10n.auth_email_marketing,
              style: DabblerType.copy,
            ),
          ),
          const DabblerGap.h(DabblerSpacing.space4),
          DabblerToggle(
            compactHitArea: true,
            checked: _getUpdates,
            semanticLabel: l10n.auth_email_marketing,
            onChanged: _isLoading
                ? null
                : (v) {
                    setState(() => _getUpdates = v);
                    ref.read(onboardingDataProvider.notifier).setGetUpdates(v);
                  },
          ),
        ],
      ),
    ];

    // Keyboard open: only the title, the field and the primary action stay
    // above it; the back row and the "or" group are out of the way.
    final keyboard = authKeyboardOpen(context);
    final tight = authKeyboardTight(context);

    return DabblerFlowPage(
      onBack: keyboard
          ? null
          : () => context.canPop()
                ? context.pop()
                : context.go(RoutePaths.authWelcome),
      backLabel: l10n.auth_back,
      title: l10n.auth_email_title,
      titleStyle: DabblerType.displayScreen,
      titleGap: keyboard ? DabblerSpacing.space2 : DabblerSpacing.space3,
      headerTopPadding: DabblerSpacing.space4,
      bodyTopPadding: keyboard ? DabblerSpacing.space4 : DabblerSpacing.space6,
      bodyGap: keyboard ? DabblerSpacing.space4 : DabblerSpacing.space6,
      subtitle: tight ? null : l10n.auth_email_subtitle,
      subtitleStyle: DabblerType.lead,
      primaryLabel: l10n.auth_email_send_code,
      primaryLoading: _isLoading,
      onPrimary: _isEmailValid && !_isLoading ? _handleSubmit : null,
      footerBottomPadding: keyboard
          ? DabblerSpacing.space4
          : DabblerSpacing.space8,
      secondary: keyboard
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
                  prefix: l10n.auth_already_have_account,
                  action: l10n.auth_log_in,
                  onAction: _isLoading ? null : _goToLogin,
                ),
                const DabblerGap.v(DabblerSpacing.space4),
                const AuthLegalNotice(),
              ],
            ),
      content: body,
    );
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
          context.push(
            RoutePaths.enterPassword,
            extra: {'email': result.email},
          );
          break;
        case GoogleSignInResultError():
          _toastError(result.message);
          break;
      }
    } catch (e) {
      if (mounted) _toastError('Apple sign-in failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

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
          _toastError(AppLocalizations.of(context).email_input_google_failed);
          break;
      }
    } catch (e) {
      if (mounted) {
        _toastError(AppLocalizations.of(context).email_input_google_failed);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToLogin() {
    context.go(
      RoutePaths.enterPassword,
      extra: {'email': _emailController.text.trim()},
    );
  }
}
