import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/utils/ui_constants.dart';
import 'package:dabbler/widgets/adaptive_auth_shell.dart';

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

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;

  late String _identifier;
  late IdentifierType _identifierType;

  @override
  void initState() {
    super.initState();

    // Determine identifier and type
    _identifier = widget.identifier ?? widget.phoneNumber ?? '';
    if (widget.identifierType != null) {
      _identifierType = widget.identifierType!;
    } else {
      // Auto-detect if not provided
      final detection = IdentifierDetector.detect(_identifier);
      _identifierType = detection.type;
      _identifier = detection.normalizedValue;
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

    // Auto-submit when all 6 digits are entered
    if (value.length == 1 && index == 5) {
      // Check if all fields are filled
      final otpCode = _getOtpCode();
      if (otpCode.length == 6) {
        // Unfocus to dismiss keyboard
        FocusScope.of(context).unfocus();
        // Automatically submit after a short delay
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

      // Verify session was created
      if (response.session != null) {
        // Refresh auth state to ensure the session is recognized app-wide
        await ref.read(simpleAuthProvider.notifier).refreshAuthState();
      } else {}

      if (mounted) {
        // Check if user needs to complete profile
        await _checkUserProfileAndNavigate();
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        final isDark = theme.colorScheme.brightness == Brightness.dark;
        final tokens = isDark
            ? main_dark_tokens.theme
            : main_light_tokens.theme;

        // Strip the Exception wrapper added by auth_service for a clean message.
        final rawMessage = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rawMessage),
            backgroundColor: tokens.main.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Check if user has completed profile and navigate accordingly
  Future<void> _checkUserProfileAndNavigate() async {
    try {
      final authService = AuthService();
      final userProfile = await authService.getUserProfile(
        fields: ['id', 'onboard', 'display_name', 'intention'],
      );

      // Check if user has completed onboarding
      final isOnboarded =
          userProfile != null &&
          (userProfile['onboard'] == true || userProfile['onboard'] == 'true');

      if (isOnboarded) {
        // EXISTING USER: Go to welcome screen (sign-in flow)
        if (mounted) {
          final displayName = userProfile['display_name'] as String? ?? '';
          final personaType = userProfile['intention'] as String? ?? 'player';

          context.go(
            RoutePaths.welcome,
            extra: {
              'displayName': displayName,
              'personaType': personaType,
              'isFirstTime': false, // Returning user
            },
          );
        }
      } else {
        // NEW USER: Needs to complete onboarding
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
      // Final fallback - go to onboarding (assume new user)
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
        final theme = Theme.of(context);
        final isDark = theme.colorScheme.brightness == Brightness.dark;
        final tokens = isDark
            ? main_dark_tokens.theme
            : main_light_tokens.theme;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'OTP sent successfully to your ${_identifierType == IdentifierType.email ? 'email' : 'phone'}',
            ),
            backgroundColor: tokens.main.primary,
          ),
        );
        _startResendCountdown();
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        final isDark = theme.colorScheme.brightness == Brightness.dark;
        final tokens = isDark
            ? main_dark_tokens.theme
            : main_light_tokens.theme;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: tokens.main.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Widget _buildOtpInputRow(
    BuildContext context,
    ThemeData theme,
    dynamic tokens,
  ) {
    const gap = AppSpacing.sm;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : gap / 2,
              right: index == 5 ? 0 : gap / 2,
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: tokens.main.onSurface,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0',
                  hintStyle: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: tokens.main.onSurface.withOpacity(0.3),
                  ),
                  filled: true,
                  fillColor: tokens.main.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(1000),
                    borderSide: BorderSide(
                      color: tokens.main.outlineVariant.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(1000),
                    borderSide: BorderSide(
                      color: tokens.main.outlineVariant.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(1000),
                    borderSide: BorderSide(
                      color: tokens.main.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) => _onOtpChanged(value, index),
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    final title = _identifierType == IdentifierType.email
        ? 'Verify email'
        : 'Verify phone';
    final subtitle = _identifierType == IdentifierType.email
        ? 'Enter the 6 digits we\'ve sent to your email'
        : 'Enter the 6 digits we\'ve sent to your phone';
    final changeLabel = _identifierType == IdentifierType.email
        ? 'Change email'
        : 'Change phone';
    final changeRoute = _identifierType == IdentifierType.email
        ? RoutePaths.emailInput
        : RoutePaths.phoneInput;

    return AdaptiveAuthShell(
      backgroundColor: tokens.main.background,
      containerColor: tokens.main.secondaryContainer,
      resizeToAvoidBottomInset: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    title,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: tokens.main.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tokens.main.onSecondaryContainer,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _identifier,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.main.onSecondaryContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(changeRoute),
                        child: Text(
                          changeLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: tokens.main.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  _buildOtpInputRow(context, theme, tokens),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  const Spacer(),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.main.primary,
                      foregroundColor: tokens.main.onPrimary,
                      minimumSize: const Size.fromHeight(
                        AppButtonSize.extraLargeHeight,
                      ),
                      padding: AppButtonSize.extraLargePadding,
                      shape: const StadiumBorder(),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: AppSpacing.xxl,
                            width: AppSpacing.xxl,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                tokens.main.onPrimary,
                              ),
                            ),
                          )
                        : Text(
                            'Continue',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: tokens.main.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Didn\'t get a code? ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.main.onSecondaryContainer,
                          ),
                        ),
                        if (_resendCountdown > 0)
                          Text(
                            'Resend code (${_resendCountdown}s)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: tokens.main.onSecondaryContainer
                                  .withValues(alpha: 0.6),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: _isResending ? null : _handleResend,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _isResending ? 'Sending...' : 'Resend code',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: tokens.main.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
