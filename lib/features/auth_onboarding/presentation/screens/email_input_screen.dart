import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dabbler/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/authentication/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';

class EmailInputScreen extends ConsumerStatefulWidget {
  const EmailInputScreen({super.key});

  @override
  ConsumerState<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends ConsumerState<EmailInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _isEmailValid = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  void _onEmailChanged(String value) {
    final isValid = _validateEmail(value) == null;
    if (isValid != _isEmailValid) {
      setState(() {
        _isEmailValid = isValid;
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

    final email = _emailController.text.trim();

    try {
      // Check if user exists in the system
      final authService = ref.read(authServiceProvider);
      final userExists = await authService.checkUserExistsByEmail(email);

      if (mounted) {
        // Always use OTP for email, regardless of whether the user exists.
        // Password-based login remains available elsewhere but is not used here.

        // Send OTP using unified method
        await authService.sendOtp(
          identifier: email,
          type: IdentifierType.email,
        );

        // Navigate to OTP verification screen
        context.push(
          RoutePaths.otpVerification,
          extra: {
            'identifier': email,
            'identifierType': IdentifierType.email.name,
            'userExistsBeforeOtp': userExists,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
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
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _buildHeroSection(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                child: _buildBottomSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final heroColor = isDarkMode
        ? const Color(0xFF4A148C)
        : const Color(0xFFE0C7FF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode
        ? Colors.white.withOpacity(0.85)
        : Colors.black.withOpacity(0.7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: heroColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // Dabbler logo and text
          _buildLogo(textColor),
          const SizedBox(height: 24),
          // Welcome text
          Text(
            'Welcome to dabbler!',
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email address to get started',
            style: textTheme.bodyLarge?.copyWith(color: subtextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(Color iconColor) {
    return Column(
      children: [
        // Dabbler geometric icon
        SvgPicture.asset(
          'assets/images/dabbler_logo.svg',
          width: 80,
          height: 88,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
        const SizedBox(height: 16),
        // Dabbler text logo
        SvgPicture.asset(
          'assets/images/dabbler_text_logo.svg',
          width: 110,
          height: 21,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        // Email input field
        _buildEmailInput(),
        SizedBox(height: 16.0),

        // Continue with Email button
        _buildContinueButton(),

        SizedBox(height: 24.0),

        // Divider with "or"
        _buildDivider(),

        SizedBox(height: 24.0),

        // Continue with Google button
        _buildGoogleButton(),

        SizedBox(height: 12.0),

        // Continue with Phone button
        _buildPhoneButton(),

        SizedBox(height: 32.0),

        // Terms and privacy
        _buildTermsText(),

        // Error/Success messages
        if (_errorMessage != null) ...[
          SizedBox(height: 16.0),
          Container(
            padding: EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],

        if (_successMessage != null) ...[
          SizedBox(height: 16.0),
          Container(
            padding: EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Text(
              _successMessage!,
              style: TextStyle(color: AppColors.success),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmailInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            hintText: 'email@example.com',
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: _onEmailChanged,
          validator: _validateEmail,
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📧', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8.0),
                  Text(
                    'Continue with Email',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.borderDark)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'or',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.borderDark)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.categoryBgMain(context),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'G',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 8.0),
                  Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
      ),
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

  Widget _buildPhoneButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          context.go(RoutePaths.phoneInput);
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.categoryBgMain(context),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone, size: 18),
            SizedBox(width: 8.0),
            Text(
              'Continue with Phone',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsText() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          'By continuing, you agree to our',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        GestureDetector(
          onTap: () async {
            final url = Uri.parse('https://dabbler.app/terms');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(
            'Terms of Service',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Text(
          'and',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        GestureDetector(
          onTap: () async {
            final url = Uri.parse('https://dabbler.app/privacy');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(
            'Privacy Policy',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
