import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/authentication/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
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
        fields: ['id', 'onboard'],
      );

      // Check if user has completed onboarding
      final isOnboarded =
          userProfile != null &&
          (userProfile['onboard'] == true || userProfile['onboard'] == 'true');

      if (isOnboarded) {
        // User has completed onboarding - go to home
        if (mounted) {
          context.go(RoutePaths.home);
        }
      } else {
        // User needs to complete onboarding - initialize onboarding data
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
      // Final fallback - go to onboarding
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'OTP sent successfully to your ${_identifierType == IdentifierType.email ? 'email' : 'phone'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _startResendCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
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
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleSectionLayout(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: screenHeight - topPadding - bottomPadding - 48,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Container
            Column(
              children: [
                SizedBox(height: AppSpacing.xl),
                // Dabbler logo
                Center(
                  child: SvgPicture.asset(
                    'assets/images/dabbler_logo.svg',
                    width: 80,
                    height: 88,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                // Dabbler text logo
                Center(
                  child: SvgPicture.asset(
                    'assets/images/dabbler_text_logo.svg',
                    width: 110,
                    height: 21,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
                // Title
                Text(
                  _identifierType == IdentifierType.email
                      ? 'Verify Your Email'
                      : 'Verify Your Phone',
                  style: AppTypography.headlineMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.sm),
                // Subtitle
                Text(
                  _identifierType == IdentifierType.email
                      ? 'We\'ve sent a 6-digit code to your email'
                      : 'We\'ve sent a 6-digit code to',
                  style: AppTypography.bodyLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.md),
                // Identifier
                Text(
                  _identifier,
                  style: AppTypography.bodyLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Form Container
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instructions text
                Text(
                  'Enter the 6-digit code',
                  style: AppTypography.bodyLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.lg),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) => _onOtpChanged(value, index),
                      ),
                    );
                  }),
                ),
                SizedBox(height: AppSpacing.xl),

                // Verify Button
                FilledButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: Text(_isLoading ? 'Verifying...' : 'Verify'),
                ),

                SizedBox(height: AppSpacing.lg),

                // Resend OTP
                Column(
                  children: [
                    Text(
                      'Didn\'t receive the code?',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    if (_resendCountdown > 0)
                      Text(
                        'Resend in $_resendCountdown s',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _isResending ? null : _handleResend,
                        child: Text(
                          _isResending ? 'Sending...' : 'Resend',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: AppSpacing.xl),

                // Change identifier button
                TextButton(
                  onPressed: () => context.go(RoutePaths.phoneInput),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: Text(
                    _identifierType == IdentifierType.email
                        ? 'Change Email'
                        : 'Change Phone Number',
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
