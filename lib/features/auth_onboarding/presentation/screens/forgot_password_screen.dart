import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import '../../../../utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';

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
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final l10n = AppLocalizations.of(context);

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space4,
          DabblerSpacing.space8,
          DabblerSpacing.space11,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.forgot_password_title,
              style: DabblerType.largeTitle
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space3),
            Text(
              l10n.forgot_password_subtitle,
              style: DabblerType.body
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: DabblerSpacing.space9),
            DabblerTextField(
              controller: _emailController,
              placeholder: l10n.forgot_password_email_hint,
              errorText: _error,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(context),
            ),
            const SizedBox(height: DabblerSpacing.space8),
            DabblerButton(
              label: l10n.forgot_password_send_btn,
              size: DabblerButtonSize.full,
              fullWidth: true,
              loading: _isLoading,
              onPressed: () => _submit(context),
            ),
            const SizedBox(height: DabblerSpacing.space5),
            if (_sent)
              DabblerBanner(
                tone: DabblerBannerTone.success,
                message: l10n.forgot_password_sent_msg,
              ),
            const SizedBox(height: DabblerSpacing.space8),
            DabblerButton(
              label: l10n.forgot_password_back_to_signin,
              tone: DabblerButtonTone.text,
              size: DabblerButtonSize.full,
              fullWidth: true,
              onPressed: () => context.go(RoutePaths.authWelcome),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () => _error = AppLocalizations.of(
          context,
        ).forgot_password_validate_email,
      );
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
