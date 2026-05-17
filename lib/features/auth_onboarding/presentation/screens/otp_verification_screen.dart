import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_widgets.dart';

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
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isHandlingOtpPaste = false;
  int _focusedIndex = -1;

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

    for (int i = 0; i < _focusNodes.length; i++) {
      final index = i;
      _focusNodes[index].addListener(() {
        if (mounted) {
          setState(() {
            if (_focusNodes[index].hasFocus) {
              _focusedIndex = index;
            } else if (_focusedIndex == index) {
              _focusedIndex = -1;
            }
          });
        }
      });
    }

    _startResendCountdown();
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
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

  void _onOtpChanged(String value, int index) {
    if (_isHandlingOtpPaste) return;

    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    if (digitsOnly.length > 1) {
      _applyOtpPaste(digitsOnly, startIndex: index);
      return;
    }

    if (value != digitsOnly) {
      _otpControllers[index].text = digitsOnly;
      _otpControllers[index].selection = TextSelection.collapsed(
        offset: digitsOnly.length,
      );
    }

    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (value.length == 1 && index == 5) {
      final otpCode = _getOtpCode();
      if (otpCode.length == 6) {
        FocusScope.of(context).unfocus();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_isLoading) {
            _handleSubmit();
          }
        });
      }
    }
  }

  void _applyOtpPaste(String digits, {required int startIndex}) {
    _isHandlingOtpPaste = true;
    try {
      final chars = digits.split('');
      var writeIndex = startIndex;
      for (final ch in chars) {
        if (writeIndex >= _otpControllers.length) break;
        _otpControllers[writeIndex].text = ch;
        _otpControllers[writeIndex].selection = const TextSelection.collapsed(
          offset: 1,
        );
        writeIndex++;
      }

      final nextEmpty = _otpControllers.indexWhere(
        (c) => c.text.trim().isEmpty,
      );
      if (nextEmpty != -1) {
        _focusNodes[nextEmpty].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
        final otpCode = _getOtpCode();
        if (otpCode.length == 6 && !_isLoading) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && !_isLoading) {
              _handleSubmit();
            }
          });
        }
      }
    } finally {
      _isHandlingOtpPaste = false;
    }
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _handleSubmit() async {
    final otpCode = _getOtpCode();

    final otpError = AppValidators.validateOTP(otpCode);
    if (otpError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(otpError), backgroundColor: Colors.orange),
      );
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

      if (mounted) {
        await _checkUserProfileAndNavigate();
      }
    } catch (e) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        final rawMessage = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rawMessage),
            backgroundColor: colorScheme.error,
          ),
        );
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
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _identifierType == IdentifierType.email
                  ? AppLocalizations.of(context).otp_verify_sent_email
                  : AppLocalizations.of(context).otp_verify_sent_phone,
            ),
            backgroundColor: colorScheme.primary,
          ),
        );
        _startResendCountdown();
      }
    } catch (e) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).otp_verify_error_prefix(e.toString()),
            ),
            backgroundColor: colorScheme.error,
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
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final title = _identifierType == IdentifierType.email
        ? l10n.otp_verify_title_email
        : l10n.otp_verify_title_phone;
    final subtitle = _identifierType == IdentifierType.email
        ? l10n.otp_verify_subtitle_email
        : l10n.otp_verify_subtitle_phone;
    final changeLabel = _identifierType == IdentifierType.email
        ? l10n.otp_verify_change_email
        : l10n.otp_verify_change_phone;
    final changeRoute = _identifierType == IdentifierType.email
        ? RoutePaths.emailInput
        : RoutePaths.phoneInput;

    final isAllFilled = _getOtpCode().length == 6;
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: GradientBlob(
              color: colorScheme.primary,
              size: 320,
              opacity: 0.20,
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: GradientBlob(color: kObPink, size: 280, opacity: 0.14),
          ),
          SafeArea(
            child: Column(
              children: [
                OnboardingTopBar(onBack: () => context.pop()),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OnboardingScreenHead(title: title, subtitle: subtitle),
                        // Identifier pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _identifierType == IdentifierType.email
                                    ? Iconsax.sms_copy
                                    : Iconsax.mobile_copy,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _identifier,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => context.go(changeRoute),
                                child: Text(
                                  changeLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onPrimaryContainer,
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        // OTP cells
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            final isFilled =
                                _otpControllers[index].text.isNotEmpty;
                            final isFocused = _focusedIndex == index;
                            return Expanded(
                              child: Container(
                                margin: EdgeInsets.only(
                                  left: index == 0 ? 0 : 5,
                                  right: index == 5 ? 0 : 5,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: AnimatedContainer(
                                    duration: duration,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: isFilled
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerLowest,
                                      border: Border.all(
                                        color: (isFilled || isFocused)
                                            ? colorScheme.primary
                                            : colorScheme.outlineVariant,
                                        width: (isFilled || isFocused)
                                            ? 2
                                            : 1.5,
                                      ),
                                      boxShadow: isFocused
                                          ? [
                                              BoxShadow(
                                                color: colorScheme.primary
                                                    .withValues(alpha: 0.22),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: TextField(
                                      controller: _otpControllers[index],
                                      focusNode: _focusNodes[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 6,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: colorScheme.primary,
                                      ),
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) =>
                                          _onOtpChanged(value, index),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 28),
                        // Resend row
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.otp_verify_didnt_get,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (_resendCountdown > 0)
                                Text(
                                  l10n.otp_verify_resend_countdown(
                                    _resendCountdown,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                )
                              else
                                TextButton(
                                  onPressed: _isResending
                                      ? null
                                      : _handleResend,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _isResending
                                        ? l10n.otp_verify_sending
                                        : l10n.otp_verify_resend,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                OnboardingBottomBar(
                  child: OnboardingCTAButton(
                    label: l10n.otp_verify_continue,
                    onPressed: (!isAllFilled || _isLoading)
                        ? null
                        : _handleSubmit,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
