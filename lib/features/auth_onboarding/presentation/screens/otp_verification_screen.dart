import 'dart:async';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String? identifier; // Can be email or phone
  final IdentifierType? identifierType; // If null, will be auto-detected
  final bool? userExistsBeforeOtp;

  /// Seeds the message under the code boxes (render tests for the frame's
  /// not-right and expired states).
  final String? initialErrorMessage;

  /// Seeds the typed code (the frames show the digits that were rejected).
  final String? initialCode;

  // Legacy support for phoneNumber parameter
  const OtpVerificationScreen({
    super.key,
    this.identifier,
    this.identifierType,
    this.userExistsBeforeOtp,
    @visibleForTesting this.initialErrorMessage,
    @visibleForTesting this.initialCode,
    @Deprecated('Use identifier instead') String? phoneNumber,
  }) : assert(
         identifier != null || phoneNumber != null,
         'Either identifier or phoneNumber must be provided',
       );

  // Getter for backward compatibility
  String? get phoneNumber => identifier;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  String _code = '';
  String? _errorMessage;
  bool _profileCheckFailed = false;

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;

  late String _identifier;
  late IdentifierType _identifierType;

  @override
  void dispose() {
    routerRefreshNotifier.releaseProfileHold();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _errorMessage = widget.initialErrorMessage;
    _code = widget.initialCode ?? '';
    _identifier = widget.identifier ?? widget.phoneNumber ?? '';
    if (widget.identifierType != null) {
      _identifierType = widget.identifierType!;
    } else {
      final detection = IdentifierDetector.detect(_identifier);
      _identifierType = detection.type;
      _identifier = detection.normalizedValue;
    }

    _startResendCountdown();
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 30;
    });
    _countdown();
  }

  void _countdown() {
    if (!mounted) return;
    if (_resendCountdown > 0) {
      Future.delayed(DabblerMotion.delayRetryLong, () {
        if (mounted) {
          setState(() {
            _resendCountdown--;
          });
          _countdown();
        }
      });
    }
  }

  void _onCodeChanged(String value) {
    setState(() {
      _code = value;
      _errorMessage = null;
      _profileCheckFailed = false;
    });
  }

  void _onCodeCompleted(String value) {
    FocusScope.of(context).unfocus();
    Future.delayed(DabblerMotion.delayFrame, () {
      if (mounted && !_isLoading) {
        _handleSubmit();
      }
    });
  }

  String _getOtpCode() => _code;

  /// Classifies a failed verification without ever showing its raw text:
  /// `expired` / `invalid` map to the frame's own lines in [build]; anything
  /// else (offline, timeout, server) is the generic line.
  String _verifyFailureKind(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('expire')) return 'expired';
    if (text.contains('invalid') ||
        text.contains('incorrect') ||
        text.contains('otp') ||
        text.contains('token')) {
      return 'invalid';
    }
    return 'generic';
  }

  Future<void> _handleSubmit() async {
    final otpCode = _getOtpCode();

    final otpError = AppValidators.validateOTP(otpCode);
    if (otpError != null) {
      setState(() => _errorMessage = otpError);
      return;
    }

    setState(() => _isLoading = true);
    // KAN-602: the sign-in event must not move the router on before the
    // profile check has run (see RouterRefreshNotifier.holdForProfile).
    routerRefreshNotifier.holdForProfile();

    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.verifyOtp(
        identifier: _identifier,
        type: _identifierType,
        token: otpCode,
      );

      if (response.session != null) {
        await ref.read(simpleAuthProvider.notifier).refreshAuthState();
      }

      if (widget.userExistsBeforeOtp == false) {
        unawaited(AnalyticsService.trackSignup(method: 'otp'));
      }

      if (mounted) {
        await _checkUserProfileAndNavigate();
      }
    } catch (e) {
      if (mounted) {
        // KAN-602: never show raw exception text; the server's own "wrong" and
        // "expired" codes are matched on the exception below, not displayed.
        setState(() => _errorMessage = _verifyFailureKind(e));
      }
    } finally {
      if (!_profileCheckFailed) routerRefreshNotifier.releaseProfileHold();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// KAN-602: only a CONFIRMED absence of a profile goes to onboarding. If
  /// the lookup could not be completed the user stays on this screen, with
  /// the verified session and the code kept, and can retry.
  Future<void> _checkUserProfileAndNavigate() async {
    final lookup = await ref
        .read(authServiceProvider)
        .lookupUserProfile(
          fields: ['id', 'onboard', 'display_name', 'intention'],
        );
    if (!mounted) return;

    if (lookup is! ProfileLookupCouldNotCheck) {
      routerRefreshNotifier.releaseProfileHold();
    }

    switch (lookup) {
      case ProfileLookupFound(:final profile)
          when profile['onboard'] == true || profile['onboard'] == 'true':
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
      case ProfileLookupFound():
      case ProfileLookupConfirmedNoProfile():
        if (_identifierType == IdentifierType.email) {
          ref.read(onboardingDataProvider.notifier).initWithEmail(_identifier);
          context.go(RoutePaths.createUserInfo, extra: {'email': _identifier});
        } else {
          ref.read(onboardingDataProvider.notifier).initWithPhone(_identifier);
          context.go(RoutePaths.createUserInfo, extra: {'phone': _identifier});
        }
      case ProfileLookupCouldNotCheck():
        setState(() => _profileCheckFailed = true);
    }
  }

  /// Retries only the profile lookup; the code was already verified.
  Future<void> _retryProfileCheck() async {
    setState(() {
      _isLoading = true;
      _profileCheckFailed = false;
    });
    try {
      await _checkUserProfileAndNavigate();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResend() async {
    if (_resendCountdown > 0) return;

    setState(() => _isResending = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendOtp(identifier: _identifier, type: _identifierType);

      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: _identifierType == IdentifierType.email
                ? AppLocalizations.of(context).otp_verify_sent_email
                : AppLocalizations.of(context).otp_verify_sent_phone,
            tone: DabblerToastTone.success,
          ),
        );
        _startResendCountdown();
      }
    } catch (e) {
      if (mounted) {
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: AppLocalizations.of(context).auth_otp_resend_failed,
            tone: DabblerToastTone.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final isEmail = _identifierType == IdentifierType.email;
    final title = isEmail ? l10n.auth_otp_title : l10n.otp_verify_title_phone;
    final subtitle = isEmail
        ? l10n.auth_otp_subtitle
        : l10n.otp_verify_subtitle_phone;
    final changeLabel = isEmail
        ? l10n.auth_otp_change
        : l10n.otp_verify_change_phone;
    final changeRoute = RoutePaths.emailInput;

    final isAllFilled = _getOtpCode().length == 6;

    // The message under the boxes: the frame's "not right" and "expired"
    // lines for the failures the server reports as such, else its own text.
    String? message = _errorMessage;
    if (message != null) {
      final String lower = message.toLowerCase();
      if (lower.contains('expire')) {
        message = l10n.auth_otp_expired;
      } else if (message == 'generic') {
        message = l10n.auth_otp_generic_error;
      } else if (lower.contains('invalid') ||
          lower.contains('incorrect') ||
          lower.contains('token') ||
          lower.contains('digit') ||
          lower.contains('code')) {
        message = l10n.auth_otp_invalid;
      }
    }

    final List<Widget> body = <Widget>[
      DabblerSurface.card(
        radius: DabblerRadius.lg,
        // The frame's card pads 12 / 15 inside a hairline drawn outside it.
        borderOutside: true,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space5,
          vertical: DabblerSpacing.space4,
        ),
        child: Row(
          children: <Widget>[
            DabblerIcon(
              isEmail ? 'sms' : 'mobile',
              size: DabblerSizing.iconRow,
              color: DabblerColors.of(context).brandPrimary,
            ),
            const DabblerGap.h(DabblerSpacing.space4),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: DabblerText(
                  _identifier,
                  style: DabblerType.copy,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const DabblerGap.h(DabblerSpacing.space4),
            DabblerTextLink(
              label: changeLabel,
              style: authLinkStyle(context, DabblerType.small),
              inline: true,
              underline: false,
              onPressed: () => context.go(changeRoute),
            ),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DabblerCodeInput(
            value: _code,
            error: _errorMessage != null,
            enabled: !_isLoading,
            onChanged: _onCodeChanged,
            onCompleted: _onCodeCompleted,
          ),
          if (_errorMessage != null) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space4),
            DabblerInlineMessage(message!),
          ],
          if (_profileCheckFailed) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space4),
            DabblerInlineMessage(l10n.auth_profile_check_failed),
          ],
        ],
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: _resendCountdown > 0
            ? DabblerText(
                l10n.auth_otp_resend_in(_resendCountdown),
                style: DabblerType.copy,
                tone: DabblerTextTone.tertiary,
              )
            : DabblerTextLink(
                label: _isResending
                    ? l10n.otp_verify_sending
                    : l10n.auth_otp_resend,
                style: authLinkStyle(context, DabblerType.copy),
                inline: true,
                underline: false,
                onPressed: _isResending ? null : _handleResend,
              ),
      ),
    ];

    return DabblerFlowPage(
      onBack: () => context.pop(),
      backLabel: l10n.auth_back,
      title: title,
      titleStyle: DabblerType.displayScreen,
      titleGap: DabblerSpacing.space3,
      headerTopPadding: DabblerSpacing.space4,
      subtitle: subtitle,
      subtitleStyle: DabblerType.lead,
      primaryLabel: _profileCheckFailed
          ? l10n.auth_profile_check_retry
          : l10n.auth_otp_continue,
      primaryLoading: _isLoading,
      onPrimary: isAllFilled && !_isLoading
          ? (_profileCheckFailed ? _retryProfileCheck : _handleSubmit)
          : null,
      content: body,
    );
  }
}
