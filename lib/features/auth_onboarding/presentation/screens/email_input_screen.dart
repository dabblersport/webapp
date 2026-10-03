import 'package:dabbler/core/models/google_sign_in_result.dart';
import 'package:dabbler/core/utils/identifier_detector.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/auth_entry_parts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show AutofillHints, TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  bool _getUpdates = true;

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
    final l10n = AppLocalizations.of(context);
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l10n.email_input_validate_required;
    if (!RegExp(r'^[\w+\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return l10n.email_input_validate_invalid;
    }
    return null;
  }

  void _onEmailChanged(String value) {
    final isValid = _validateEmail(value) == null;
    setState(() => _isEmailValid = isValid);
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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

      // Always use OTP for email, regardless of whether the user exists.
      // Password-based login remains available elsewhere but is not used here.
      await authService.sendOtp(identifier: email, type: IdentifierType.email);

      if (!mounted) return;

      // Seed onboarding data so getUpdates is carried through the flow
      final notifier = ref.read(onboardingDataProvider.notifier);
      if (ref.read(onboardingDataProvider) == null) {
        notifier.initWithEmail(email);
      }
      notifier.setGetUpdates(_getUpdates);

      // Navigate to OTP verification screen
      context.push(
        RoutePaths.otpVerification,
        extra: {
          'identifier': email,
          'identifierType': IdentifierType.email.name,
          'userExistsBeforeOtp': userExists,
        },
      );
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final message = raw.startsWith('Exception: ')
            ? raw.substring('Exception: '.length)
            : raw;
        setState(() {
          _errorMessage = kDebugMode
              ? message
              : AppLocalizations.of(context).email_input_error_generic;
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
    final l10n = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(RoutePaths.authWelcome),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space8,
              DabblerSpacing.space4,
              DabblerSpacing.space8,
              DabblerSpacing.space6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.email_input_title,
                  style: authText(
                    context,
                    DabblerType.largeTitle,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: DabblerSpacing.space3),
                Text(
                  l10n.email_input_subtitle,
                  style: authText(
                    context,
                    DabblerType.body,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: DabblerSpacing.space4),
                const AuthLegalNotice(center: false),
                const SizedBox(height: DabblerSpacing.space8),
                _buildEmailField(context),
                const SizedBox(height: DabblerSpacing.space5),
                _buildKeepInLoopRow(context),
                const SizedBox(height: DabblerSpacing.space8),
                DabblerButton(
                  label: l10n.email_input_continue,
                  size: DabblerButtonSize.full,
                  fullWidth: true,
                  loading: _isLoading,
                  disabled: !(_isEmailValid && !_isLoading),
                  onPressed: (_isEmailValid && !_isLoading)
                      ? _handleSubmit
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: DabblerSpacing.space4),
                  AuthInlineMessage(message: _errorMessage!),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: DabblerSpacing.space4),
                  AuthInlineMessage(message: _successMessage!, success: true),
                ],
                const SizedBox(height: DabblerSpacing.space8),
                const DabblerDivider(label: 'OR'),
                const SizedBox(height: DabblerSpacing.space5),
                DabblerButton(
                  label: l10n.email_input_btn_google,
                  tone: DabblerButtonTone.outlined,
                  size: DabblerButtonSize.full,
                  fullWidth: true,
                  disabled: _isLoading,
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                ),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                  const SizedBox(height: DabblerSpacing.space4),
                  DabblerButton(
                    label: l10n.email_input_btn_apple,
                    tone: DabblerButtonTone.outlined,
                    size: DabblerButtonSize.full,
                    fullWidth: true,
                    disabled: _isLoading,
                    onPressed: _isLoading ? null : _handleAppleSignIn,
                  ),
                ],
                const SizedBox(height: DabblerSpacing.space6),
                DabblerButton(
                  label: l10n.email_input_already_account,
                  tone: DabblerButtonTone.text,
                  fullWidth: true,
                  disabled: _isLoading,
                  onPressed: _isLoading ? null : _goToLogin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      final signedIn = await authService.signInWithApple();
      if (!signedIn) return; // User cancelled the Apple sheet.

      final result = await authService.handleAppleSignInFlow();
      if (!mounted) return;

      switch (result) {
        case GoogleSignInResultGoToOnboarding():
          ref.read(onboardingDataProvider.notifier).initWithEmail(result.email);
          context.go(RoutePaths.createUserInfo, extra: {'email': result.email});
          break;
        case GoogleSignInResultGoToSetUsername():
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
          setState(() => _errorMessage = result.message);
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Apple sign-in failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // Token-based Google Sign-In (native / popup) should complete in-app.
      final launched = await authService.signInWithGoogle();
      if (!launched) {
        // User cancelled.
        return;
      }

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
          setState(() {
            _errorMessage = AppLocalizations.of(
              context,
            ).email_input_google_failed;
          });
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          ).email_input_google_failed;
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

  Widget _buildEmailField(BuildContext context) {
    final colors = DabblerColors.of(context);
    Widget? suffix;
    if (_emailController.text.isNotEmpty) {
      suffix = _isEmailValid
          ? DabblerIcon(
              'tick-circle',
              key: const ValueKey('valid'),
              weight: DabblerIconWeight.bold,
              size: DabblerSizing.iconSm,
              color: colors.success.strong,
            )
          : DabblerIcon(
              'close-circle',
              key: const ValueKey('invalid'),
              weight: DabblerIconWeight.bold,
              size: DabblerSizing.iconSm,
              color: colors.error.strong,
            );
    }
    return Form(
      key: _formKey,
      child: DabblerTextField(
        controller: _emailController,
        label: AppLocalizations.of(context).email_input_label,
        placeholder: AppLocalizations.of(context).email_input_hint,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.done,
        onChanged: _onEmailChanged,
        onSubmitted: (_) {
          if (_isEmailValid && !_isLoading) _handleSubmit();
        },
        validator: _validateEmail,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        suffixIcon: suffix == null
            ? null
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: suffix,
              ),
      ),
    );
  }

  Widget _buildKeepInLoopRow(BuildContext context) {
    final colors = DabblerColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            AppLocalizations.of(context).email_input_keep_in_loop,
            style: authText(
              context,
              DabblerType.subheadline,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: DabblerSpacing.space4),
        DabblerToggle(
          checked: _getUpdates,
          semanticLabel: AppLocalizations.of(context).email_input_keep_in_loop,
          onChanged: _isLoading
              ? null
              : (v) {
                  setState(() => _getUpdates = v);
                  ref.read(onboardingDataProvider.notifier).setGetUpdates(v);
                },
        ),
      ],
    );
  }

  void _goToLogin() {
    context.go(RoutePaths.enterPassword);
  }
}
