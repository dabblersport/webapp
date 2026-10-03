import 'dart:async';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String? identifier; // Can be email or phone
  final IdentifierType? identifierType; // If null, will be auto-detected
  final bool? userExistsBeforeOtp;

  // Legacy support for phoneNumber parameter
  const OtpVerificationScreen({
    super.key,
    this.identifier,
    this.identifierType,
    this.userExistsBeforeOtp,
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

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;

  late String _identifier;
  late IdentifierType _identifierType;

  @override
  void initState() {
    super.initState();

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
      Future.delayed(const Duration(seconds: 1), () {
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
    });
  }

  void _onCodeCompleted(String value) {
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !_isLoading) {
        _handleSubmit();
      }
    });
  }

  String _getOtpCode() => _code;

  Future<void> _handleSubmit() async {
    final otpCode = _getOtpCode();

    final otpError = AppValidators.validateOTP(otpCode);
    if (otpError != null) {
      setState(() => _errorMessage = otpError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final response = await authService.verifyOtp(
        identifier: _identifier,
        type: _identifierType,
        token: otpCode,
      );

      if (response.session != null) {
        await ref.read(simpleAuthProvider.notifier).refreshAuthState();
      }

      if (widget.userExistsBeforeOtp == false) {
        unawaited(AnalyticsService.trackEvent('signup'));
      }

      if (mounted) {
        await _checkUserProfileAndNavigate();
      }
    } catch (e) {
      if (mounted) {
        final rawMessage = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
        setState(() => _errorMessage = rawMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkUserProfileAndNavigate() async {
    try {
      final authService = AuthService();
      final userProfile = await authService.getUserProfile(
        fields: ['id', 'onboard', 'display_name', 'intention'],
      );

      final isOnboarded =
          userProfile != null &&
          (userProfile['onboard'] == true || userProfile['onboard'] == 'true');

      if (isOnboarded) {
        if (mounted) {
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
        }
      } else {
        if (_identifierType == IdentifierType.email) {
          ref.read(onboardingDataProvider.notifier).initWithEmail(_identifier);
          if (mounted) {
            context.go(
              RoutePaths.createUserInfo,
              extra: {'email': _identifier},
            );
          }
        } else {
          ref.read(onboardingDataProvider.notifier).initWithPhone(_identifier);
          if (mounted) {
            context.go(
              RoutePaths.createUserInfo,
              extra: {'phone': _identifier},
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (_identifierType == IdentifierType.email) {
          ref.read(onboardingDataProvider.notifier).initWithEmail(_identifier);
          context.go(RoutePaths.createUserInfo, extra: {'email': _identifier});
        } else {
          ref.read(onboardingDataProvider.notifier).initWithPhone(_identifier);
          context.go(RoutePaths.createUserInfo, extra: {'phone': _identifier});
        }
      }
    }
  }

  Future<void> _handleResend() async {
    if (_resendCountdown > 0) return;

    setState(() => _isResending = true);

    try {
      final authService = AuthService();
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
            message: AppLocalizations.of(
              context,
            ).otp_verify_error_prefix(e.toString()),
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
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final l10n = AppLocalizations.of(context);

    final isEmail = _identifierType == IdentifierType.email;
    final title = isEmail
        ? l10n.otp_verify_title_email
        : l10n.otp_verify_title_phone;
    final subtitle = isEmail
        ? l10n.otp_verify_subtitle_email
        : l10n.otp_verify_subtitle_phone;
    final changeLabel = isEmail
        ? l10n.otp_verify_change_email
        : l10n.otp_verify_change_phone;
    final changeRoute = RoutePaths.emailInput;

    final isAllFilled = _getOtpCode().length == 6;

    return DabblerPage(
      resizeForKeyboard: false,
      topBar: DabblerNavigationTopBar.titled(onBack: () => context.pop()),
      bottomBar: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
          DabblerSpacing.space8,
        ),
        child: DabblerButton(
          label: l10n.otp_verify_continue,
          size: DabblerButtonSize.full,
          fullWidth: true,
          disabled: !isAllFilled,
          loading: _isLoading,
          onPressed: _handleSubmit,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space4,
          DabblerSpacing.space8,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: DabblerType.largeTitle
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space3),
            Text(
              subtitle,
              style: DabblerType.body
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: DabblerSpacing.space6),
            DabblerSurface.card(
              radius: DabblerRadius.lg,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: DabblerSpacing.space5,
                vertical: DabblerSpacing.space4,
              ),
              child: Row(
                children: [
                  DabblerIcon(
                    isEmail ? 'sms' : 'mobile',
                    size: 20,
                    color: colors.brandPrimary,
                  ),
                  const SizedBox(width: DabblerSpacing.space4),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        _identifier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DabblerType.subheadline
                            .resolveForDirection(direction)
                            .copyWith(color: colors.textPrimary),
                      ),
                    ),
                  ),
                  DabblerButton(
                    label: changeLabel,
                    tone: DabblerButtonTone.text,
                    size: DabblerButtonSize.small,
                    onPressed: () => context.go(changeRoute),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DabblerSpacing.space6),
            DabblerCodeInput(
              value: _code,
              error: _errorMessage != null,
              enabled: !_isLoading,
              onChanged: _onCodeChanged,
              onCompleted: _onCodeCompleted,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: DabblerSpacing.space4),
              DabblerBanner(
                tone: DabblerBannerTone.error,
                message: _errorMessage,
              ),
            ],
            const SizedBox(height: DabblerSpacing.space6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.otp_verify_didnt_get,
                  style: DabblerType.subheadline
                      .resolveForDirection(direction)
                      .copyWith(color: colors.textSecondary),
                ),
                if (_resendCountdown > 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: DabblerSpacing.space2,
                    ),
                    child: Text(
                      l10n.otp_verify_resend_countdown(_resendCountdown),
                      style: DabblerType.subheadline
                          .resolveForDirection(direction)
                          .copyWith(color: colors.textTertiary),
                    ),
                  )
                else
                  DabblerButton(
                    label: _isResending
                        ? l10n.otp_verify_sending
                        : l10n.otp_verify_resend,
                    tone: DabblerButtonTone.text,
                    size: DabblerButtonSize.small,
                    disabled: _isResending,
                    onPressed: _handleResend,
                  ),
              ],
            ),
            const SizedBox(height: DabblerSpacing.space10),
          ],
        ),
      ),
    );
  }
}
