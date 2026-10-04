import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(registerControllerProvider);
    final controller = ref.read(registerControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(title: l10n.register_title),
      body: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space6,
          DabblerSpacing.space6,
          DabblerSpacing.space6 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DabblerTextField(
              borderOutside: true,
              label: l10n.email_input_label,
              errorText: state.error,
              onChanged: controller.updateEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const DabblerGap.v(DabblerSpacing.space6),
            DabblerTextField(
              borderOutside: true,
              variant: DabblerTextFieldVariant.password,
              mutedPasswordToggle: true,
              label: l10n.set_password_password_label,
              onChanged: controller.updatePassword,
              textInputAction: TextInputAction.done,
            ),
            const DabblerGap.v(DabblerSpacing.space8),
            DabblerButton(
              label: l10n.register_btn,
              size: DabblerButtonSize.full,
              fullWidth: true,
              loading: state.isLoading,
              onPressed: () async {
                await controller.register();
                final session = ref.read(registerControllerProvider).session;
                if (session != null) {
                  Navigator.pushReplacementNamed(context, '/confirm-email');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
