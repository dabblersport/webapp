import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../utils/constants/route_constants.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _sent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    final prefill = extra is Map && extra['email'] is String
        ? extra['email'] as String
        : (extra is String ? extra : null);
    if (prefill != null && _emailController.text.isEmpty) {
      _emailController.text = prefill;
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
            'Reset Your Password',
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email Input
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          textInputAction: TextInputAction.done,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Email Address',
            hintStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: AppColors.cardColor(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: AppColors.borderDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: AppColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.red),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 12.0,
            ),
            errorText: _error,
            errorStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.red,
            ),
          ),
          onSubmitted: (_) => _submit(context),
        ),
        SizedBox(height: 24.0),

        // Send Reset Link Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _submit(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: AppColors.buttonForeground,
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.buttonForeground,
                      ),
                    ),
                  )
                : Text(
                    'Send Reset Link',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
          ),
        ),
        SizedBox(height: 16.0),

        // Success Message
        if (_sent)
          Container(
            padding: EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.infoBackground,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppColors.infoBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
                SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'Reset link sent! Check your email inbox and spam folder for instructions to reset your password.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 24.0),

        // Back to Sign In
        TextButton(
          onPressed: () => context.go(RoutePaths.phoneInput),
          child: Text(
            'Back to Sign In',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  void _submit(BuildContext context) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService().sendPasswordResetEmail(email);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
