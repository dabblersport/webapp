import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthWelcomeScreen extends ConsumerStatefulWidget {
  const AuthWelcomeScreen({super.key});

  @override
  ConsumerState<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends ConsumerState<AuthWelcomeScreen> {
  bool _isLoading = false;

  void _toastError(String message) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));
  }

  Future<void> _handleGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final launched = await authService.signInWithGoogle();
      if (!launched) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (kIsWeb) return;
      final result = await authService.handleGoogleSignInFlow();
      if (!mounted) return;
      switch (result) {
        case GoogleSignInResultGoToOnboarding():
          context.go(RoutePaths.createUserInfo, extra: {'email': result.email});
          break;
        case GoogleSignInResultGoToSetUsername():
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
          if (mounted) {
            _toastError(result.message);
          }
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _toastError(
        AppLocalizations.of(context).auth_welcome_google_error(e.toString()),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApple() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final signedIn = await authService.signInWithApple();
      if (!signedIn) return; // User cancelled the Apple sheet.
      final result = await authService.handleAppleSignInFlow();
      if (!mounted) return;
      switch (result) {
        case GoogleSignInResultGoToOnboarding():
          context.go(RoutePaths.createUserInfo, extra: {'email': result.email});
          break;
        case GoogleSignInResultGoToSetUsername():
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
      if (!mounted) return;
      _toastError('Apple sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleEmail() => context.go(RoutePaths.emailInput);
  void _handleLogin() => context.go(RoutePaths.enterPassword);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showApple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return DabblerPage(
      maxContentWidth: DabblerPage.readableWidth,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.only(
                start: DabblerSpacing.space8,
                top: DabblerSpacing.space6,
                end: DabblerSpacing.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DabblerText(
                    l10n.auth_entry_title,
                    style: DabblerType.displayScreen,
                  ),
                  const DabblerGap.v(DabblerSpacing.space3),
                  DabblerText(
                    l10n.auth_entry_subtitle,
                    style: DabblerType.lead,
                    tone: DabblerTextTone.secondary,
                  ),
                  const DabblerGap.v(DabblerSpacing.space8),
                  DabblerCard(
                    variant: DabblerCardVariant.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DabblerSpacing.space5,
                      vertical: DabblerSpacing.space1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        DabblerInputRow(
                          flat: true,
                          leading: const DabblerIconTile.named('verify'),
                          title: l10n.auth_entry_trust_verified,
                        ),
                        DabblerInputRow(
                          flat: true,
                          leading: const DabblerIconTile.named('activity'),
                          title: l10n.auth_entry_trust_personalised,
                        ),
                        DabblerInputRow(
                          flat: true,
                          showDivider: false,
                          leading: const DabblerIconTile.named('lock'),
                          title: l10n.auth_entry_trust_privacy,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space8,
              DabblerSpacing.space6,
              DabblerSpacing.space8,
              DabblerSpacing.space8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                authIdentify(
                  'auth-welcome-continue-email',
                  DabblerButton(
                    label: l10n.auth_entry_continue_email,
                    icon: 'sms',
                    size: DabblerButtonSize.full,
                    fullWidth: true,
                    loading: _isLoading,
                    onPressed: _isLoading ? null : _handleEmail,
                  ),
                ),
                const DabblerGap.v(DabblerSpacing.space4),
                authIdentify(
                  'auth-welcome-continue-google',
                  DabblerButton(
                    label: l10n.auth_entry_continue_google,
                    tone: DabblerButtonTone.outlined,
                    size: DabblerButtonSize.full,
                    fullWidth: true,
                    disabled: _isLoading,
                    onPressed: _isLoading ? null : _handleGoogle,
                  ),
                ),
                if (showApple) ...<Widget>[
                  const DabblerGap.v(DabblerSpacing.space4),
                  authIdentify(
                    'auth-welcome-continue-apple',
                    DabblerButton(
                      label: l10n.auth_entry_continue_apple,
                      tone: DabblerButtonTone.outlined,
                      size: DabblerButtonSize.full,
                      fullWidth: true,
                      disabled: _isLoading,
                      onPressed: _isLoading ? null : _handleApple,
                    ),
                  ),
                ],
                const DabblerGap.v(DabblerSpacing.space5),
                AuthAccountLine(
                  prefix: l10n.auth_already_have_account,
                  action: l10n.auth_log_in,
                  onAction: _isLoading ? null : _handleLogin,
                ),
                const DabblerGap.v(DabblerSpacing.space4),
                const AuthLegalNotice(),
                const DabblerGap.v(DabblerSpacing.space4),
                const AuthLocaleChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
