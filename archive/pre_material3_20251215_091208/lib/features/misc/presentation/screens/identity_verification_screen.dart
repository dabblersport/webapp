import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/core/utils/validators.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/features/authentication/presentation/providers/onboarding_data_provider.dart';

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  String _countryCode = '+971'; // Default to UAE
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _isPhoneValid = false;
  IdentifierType _currentIdentifierType = IdentifierType.phone;

  @override
  void initState() {
    super.initState();
    _setDefaultCountryFromLocale();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    final trimmed = value.trim();

    final isNumericLike = _isNumericLike(trimmed);

    // If not numeric-like, treat as email and never show phone prefix
    if (!isNumericLike) {
      setState(() {
        _currentIdentifierType = IdentifierType.email;
        _isPhoneValid = false;
      });
      return;
    }

    String working = trimmed;

    // Special handling for UAE: if starts with "971" (without "+"),
    // interpret it as UAE country code and keep only the local part.
    if (working.startsWith('971') && !working.startsWith('+')) {
      final remaining = working.substring(3); // strip "971"
      if (_countryCode != '+971') {
        _countryCode = '+971';
      }
      if (remaining != working) {
        _phoneController.value = TextEditingValue(
          text: remaining,
          selection: TextSelection.collapsed(offset: remaining.length),
        );
        working = remaining;
      }
    }

    // Enforce digit limits based on starting digit
    final digitsOnly = working.replaceAll(RegExp(r'[^\d]'), '');
    int maxLength;

    if (digitsOnly.startsWith('0')) {
      maxLength = 10; // 05XXXXXXXX
    } else {
      maxLength = 9; // 5XXXXXXXX
    }

    if (digitsOnly.length > maxLength) {
      // Truncate to max length
      final truncated = digitsOnly.substring(0, maxLength);
      _phoneController.value = TextEditingValue(
        text: truncated,
        selection: TextSelection.collapsed(offset: truncated.length),
      );
      working = truncated;
    }

    setState(() {
      _currentIdentifierType = IdentifierType.phone;
    });

    final isValidPhone = _isValidUaeMobile(working);
    if (isValidPhone != _isPhoneValid) {
      setState(() {
        _isPhoneValid = isValidPhone;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final input = _phoneController.text.trim();

    // Decide based on the same numeric-like heuristic used in _onPhoneChanged
    final isNumericLike = _isNumericLike(input);
    late final IdentifierType identifierType;
    late final String finalIdentifier;

    if (isNumericLike) {
      identifierType = IdentifierType.phone;

      // UAE-only normalization
      final local = _normalizeToUaeLocal(input);
      if (local == null) {
        setState(() {
          _errorMessage = 'Please use your email address';
        });
        return;
      }
      // Always send full E.164 UAE number
      finalIdentifier = '+971$local';
    } else {
      identifierType = IdentifierType.email;
      // Normalize email similarly to IdentifierDetector
      final normalizedEmail = input
          .replaceAll(RegExp(r"[\u200B-\u200D\uFEFF]"), "")
          .replaceAll(RegExp(r"\s+"), "")
          .trim()
          .toLowerCase();
      finalIdentifier = normalizedEmail;
    }

    try {
      // Check if user exists BEFORE sending OTP
      try {
        final authService = AuthService();

        bool userExistsBeforeOtp = false;
        if (identifierType == IdentifierType.email) {
          userExistsBeforeOtp = await authService.checkUserExistsByEmail(
            finalIdentifier,
          );
        } else {
          userExistsBeforeOtp = await authService.checkUserExistsByPhone(
            finalIdentifier,
          );
        }

        // Send OTP using unified method
        await authService.sendOtp(
          identifier: finalIdentifier,
          type: identifierType,
        );

        if (mounted) {
          setState(() {
            _successMessage = identifierType == IdentifierType.email
                ? 'OTP sent! Please check your email.'
                : 'OTP sent! Please check your phone.';
          });
        }
      } catch (dbError) {
        final errorMsg = dbError.toString();

        // Check for provider not configured error
        if (errorMsg.contains('phone_provider_disabled') ||
            errorMsg.contains('Unsupported phone provider')) {
          if (mounted) {
            setState(() {
              _errorMessage =
                  'Phone authentication is not available yet. Please use email to continue.';
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _errorMessage = 'Service error: ${dbError.toString()}';
          });
        }
        return; // Don't navigate if there's an error
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to send OTP. Please try again.';
        });
      }
      return; // Don't navigate if there's an error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    // Navigate to OTP verification screen only if everything succeeded
    if (mounted) {
      try {
        context.push(
          RoutePaths.otpVerification,
          extra: {
            'identifier': finalIdentifier,
            'identifierType': identifierType.name,
            // We always use OTP for both new and existing users; keep flag
            // only for analytics/routing decisions in the OTP screen.
            'userExistsBeforeOtp': true,
          },
        );
      } catch (navError) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Navigation failed: ${navError.toString()}';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleSectionLayout(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom -
              48,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Header Container: Logo, Title
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
                  'Identity verification',
                  style: AppTypography.headlineMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.sm),
                // Subtitle
                // Text(
                //   'Enter your email address to get started',
                //   style: AppTypography.bodyLarge.copyWith(
                //     color: Theme.of(context).colorScheme.onSurfaceVariant,
                //   ),
                //   textAlign: TextAlign.center,
                // ),
              ],
            ),

            const SizedBox(height: 40),

            // Form Container: Inputs and CTA
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Phone input field
                _buildPhoneInput(),
                SizedBox(height: AppSpacing.md),

                // Continue button
                FilledButton(
                  onPressed: _isLoading || !_isValidEmail()
                      ? null
                      : _handleSubmit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: Text(_isLoading ? 'Sending...' : 'Continue'),
                ),

                SizedBox(height: AppSpacing.lg),

                // Divider with "or"
                _buildDivider(),

                SizedBox(height: AppSpacing.lg),

                // Continue with Google button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  icon: const Text(
                    'G',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  label: const Text('Continue with Google'),
                ),

                // Error/Success messages
                if (_errorMessage != null) ...[
                  SizedBox(height: AppSpacing.md),
                  _buildErrorMessage(),
                ],

                if (_successMessage != null) ...[
                  SizedBox(height: AppSpacing.md),
                  _buildSuccessMessage(),
                ],

                SizedBox(height: AppSpacing.xl),

                // Terms text at bottom
                _buildTermsText(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.error.withValues(alpha: 0.15)
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.danger_copy,
            color: isDark ? colorScheme.error : colorScheme.onErrorContainer,
            size: 20,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? colorScheme.error
                    : colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDark
        ? const Color(0xFF4CAF50)
        : const Color(0xFF2E7D32);
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? successColor.withValues(alpha: 0.15)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: successColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.tick_circle_copy, color: successColor, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _successMessage!,
              style: AppTypography.bodyMedium.copyWith(color: successColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInputField(
            controller: _phoneController,
            label: 'Email address',
            hintText: 'Enter your email address',
            keyboardType: _currentIdentifierType == IdentifierType.email
                ? TextInputType.emailAddress
                : TextInputType.phone,
            onChanged: (value) {
              _onPhoneChanged(value);
            },
          ),
          if (_formKey.currentState?.validate() == false &&
              _phoneController.text.isNotEmpty) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              _getValidationError(_phoneController.text),
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getValidationError(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'Email or phone number is required';
    }

    final isNumericLike = _isNumericLike(trimmed);

    if (isNumericLike) {
      if (_isValidUaeMobile(trimmed)) {
        return '';
      }
      return 'Please use your email address';
    } else {
      return AppValidators.validateEmail(trimmed) ?? '';
    }
  }

  /// For now, we only support UAE numbers, so always use +971
  void _setDefaultCountryFromLocale() {
    _countryCode = '+971';
  }

  /// Returns true if the string looks like a phone-ish input (digits, +, spaces, (), -).
  bool _isNumericLike(String input) {
    return input.isNotEmpty &&
        RegExp(r'^[0-9+\s()\-\u0660-\u0669]+$').hasMatch(input);
  }

  /// Normalize various UAE formats to local 9-digit starting with 5:
  /// 5XXXXXXXX, 05XXXXXXXX, 9715XXXXXXXX, +9715XXXXXXXX -> 5XXXXXXXX
  String? _normalizeToUaeLocal(String input) {
    var s = input.replaceAll(RegExp(r'\s+'), '');

    if (s.startsWith('+971')) {
      s = s.substring(4);
    } else if (s.startsWith('971')) {
      s = s.substring(3);
    } else if (s.startsWith('05')) {
      s = s.substring(1); // drop leading 0
    }

    if (RegExp(r'^5\d{8}$').hasMatch(s)) {
      return s;
    }
    return null;
  }

  /// UAE-only mobile validation.
  bool _isValidUaeMobile(String input) {
    final local = _normalizeToUaeLocal(input);
    return local != null;
  }

  /// Check if current input is a valid email
  bool _isValidEmail() {
    final input = _phoneController.text.trim();
    if (input.isEmpty) return false;

    // Only accept email addresses (not phone numbers)
    if (_isNumericLike(input)) return false;

    return AppValidators.validateEmail(input) == null;
  }

  Widget _buildDivider() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Divider(color: colorScheme.outlineVariant, thickness: 1),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'or',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: colorScheme.outlineVariant, thickness: 1),
        ),
      ],
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = AuthService();

      // Launch Google OAuth (this opens browser/app)
      await authService.signInWithGoogle();

      // Note: OAuth is asynchronous - the user will complete sign-in in browser/app
      // The auth state listener will detect when they return and handle routing
      // For now, we'll wait a bit and then check, but ideally this should be handled
      // by the auth state listener in the router

      // Wait for OAuth to complete (user will be redirected back)
      await Future.delayed(const Duration(seconds: 3));

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
          // Error occurred
          setState(() {
            _errorMessage = result.message;
          });
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google sign-in failed. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTermsText() {
    final colorScheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        text: 'By continuing, you agree to our ',
        style: AppTypography.bodySmall.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(
            text: 'Terms of Service',
            style: AppTypography.bodySmall.copyWith(
              color: colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: AppTypography.bodySmall.copyWith(
              color: colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
