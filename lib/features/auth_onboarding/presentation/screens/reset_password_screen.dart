import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import '../../../../utils/constants/route_constants.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  bool _isLoading = false;
  String? _error;
  String? _passwordError;
  String? _confirmError;
  String _password = '';
  String _confirm = '';

  bool _validate() {
    final l10n = AppLocalizations.of(context);
    String? passwordError;
    if (_password.isEmpty) {
      passwordError = l10n.reset_password_validate_enter;
    } else if (_password.length < 8) {
      passwordError = l10n.reset_password_validate_min;
    }
    String? confirmError;
    if (_confirm.isEmpty) {
      confirmError = l10n.reset_password_validate_confirm;
    } else if (_confirm != _password) {
      confirmError = l10n.reset_password_validate_match;
    }
    setState(() {
      _passwordError = passwordError;
      _confirmError = confirmError;
    });
    return passwordError == null && confirmError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService().updatePassword(_password);
      if (!mounted) return;
      // After successful reset, go to login to sign in
      context.go(RoutePaths.authWelcome);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final l10n = AppLocalizations.of(context);

    return DabblerPage(
      topBar: const DabblerNavigationTopBar.titled(),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space4,
          DabblerSpacing.space8,
          DabblerSpacing.space10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.reset_password_title,
              style: DabblerType.largeTitle
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space3),
            Text(
              l10n.reset_password_subtitle,
              style: DabblerType.body
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: DabblerSpacing.space9),
            DabblerTextField(
              variant: DabblerTextFieldVariant.password,
              label: l10n.reset_password_new_label,
              errorText: _passwordError,
              onChanged: (v) => _password = v,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: DabblerSpacing.space4),
            DabblerTextField(
              variant: DabblerTextFieldVariant.password,
              label: l10n.reset_password_confirm_label,
              errorText: _confirmError,
              onChanged: (v) => _confirm = v,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: DabblerSpacing.space8),
            DabblerButton(
              label: l10n.reset_password_update_btn,
              size: DabblerButtonSize.full,
              fullWidth: true,
              loading: _isLoading,
              onPressed: _submit,
            ),
            if (_error != null) ...[
              const SizedBox(height: DabblerSpacing.space4),
              DabblerBanner(tone: DabblerBannerTone.error, message: _error),
            ],
          ],
        ),
      ),
    );
  }
}
