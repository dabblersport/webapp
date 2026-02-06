import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/auth_providers.dart';
import '../../../../utils/constants/route_constants.dart';

class EnterPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const EnterPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<EnterPasswordScreen> createState() =>
      _EnterPasswordScreenState();
}

class _EnterPasswordScreenState extends ConsumerState<EnterPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final result = await authService.signInWithEmail(
        email: widget.email,
        password: _passwordController.text,
      );

      if (result.user != null) {
        // Handle successful login with the new method
        await ref.read(simpleAuthProvider.notifier).handleSuccessfulLogin();

        // Check if auth state was updated properly
        final authState = ref.read(simpleAuthProvider);

        // Let GoRouter redirect based on updated auth state; do not navigate manually
        return;
      } else {
        setState(() {
          _errorMessage = 'Invalid email or password';
        });
      }
    } catch (e) {
      final errText = e.toString().toLowerCase();
      final isInvalidCreds =
          errText.contains('invalid login credentials') ||
          errText.contains('invalid_credentials') ||
          errText.contains('invalid email or password') ||
          errText.contains('email not confirmed');

      setState(() {
        if (isInvalidCreds) {
          _errorMessage =
              'invalid_credentials'; // Special marker for showing create account button
        } else {
          _errorMessage = 'Sign in failed: ${e.toString()}';
        }
      });
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
          // Logo
          _buildLogo(textColor),
          const SizedBox(height: 24),
          // Header
          Text(
            'Welcome Back!',
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.email,
            style: textTheme.bodyLarge?.copyWith(
              color: subtextColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(Color iconColor) {
    return Column(
      children: [
        SvgPicture.asset(
          'assets/images/dabbler_logo.svg',
          width: 80,
          height: 88,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
        const SizedBox(height: 16),
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
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              filled: true,
              fillColor: AppColors.cardColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppSpacing.buttonBorderRadius,
                ),
                borderSide: BorderSide(color: AppColors.borderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppSpacing.buttonBorderRadius,
                ),
                borderSide: BorderSide(color: AppColors.borderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppSpacing.buttonBorderRadius,
                ),
                borderSide: BorderSide(color: AppColors.primaryPurple),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _signIn(),
          ),
          SizedBox(height: AppSpacing.sm),

          // Forgot Password Link
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.go(
                RoutePaths.forgotPassword,
                extra: {'email': widget.email},
              ),
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryPurple,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xl),

          // Login Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: AppColors.buttonForeground,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.buttonBorderRadius,
                  ),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.buttonForeground,
                        ),
                      ),
                    )
                  : Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
          SizedBox(height: AppSpacing.lg),

          // Change Email Link
          TextButton(
            onPressed: () => context.go(RoutePaths.phoneInput),
            child: Text(
              'Change Email',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                decoration: TextDecoration.underline,
              ),
            ),
          ),

          // Error Message
          if (_errorMessage != null) ...[
            SizedBox(height: AppSpacing.lg),
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(
                  AppSpacing.buttonBorderRadius,
                ),
              ),
              child: Text(
                _errorMessage == 'invalid_credentials'
                    ? 'Invalid email or password'
                    : _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
