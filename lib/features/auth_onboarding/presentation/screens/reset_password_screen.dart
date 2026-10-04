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
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  String _password = '';

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
    final l10n = AppLocalizations.of(context);

    return DabblerFlowPage(
      onBack: () => context.go(RoutePaths.authWelcome),
      backLabel: l10n.auth_back,
      title: l10n.reset_password_title,
      titleStyle: DabblerType.displayScreen,
      headerTopPadding: DabblerSpacing.space4,
      subtitle: l10n.reset_password_subtitle,
      subtitleStyle: DabblerType.lead,
      bodyGap: DabblerSpacing.space4,
      content: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DabblerTextField(
                variant: DabblerTextFieldVariant.password,
                label: l10n.reset_password_new_label,
                onChanged: (v) => _password = v,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return l10n.reset_password_validate_enter;
                  }
                  if (v.length < 8) {
                    return l10n.reset_password_validate_min;
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const DabblerGap.v(DabblerSpacing.space4),
              DabblerTextField(
                variant: DabblerTextFieldVariant.password,
                label: l10n.reset_password_confirm_label,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return l10n.reset_password_validate_confirm;
                  }
                  if (v != _password) {
                    return l10n.reset_password_validate_match;
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ],
      footerBanner: _error == null
          ? null
          : DabblerBanner(tone: DabblerBannerTone.error, message: _error),
      primaryLabel: l10n.reset_password_update_btn,
      primaryLoading: _isLoading,
      onPrimary: _isLoading ? null : _submit,
    );
  }
}
