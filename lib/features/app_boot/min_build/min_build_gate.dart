import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart'
    show Brightness, MaterialApp, ThemeData, ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'min_build_providers.dart';
import 'page_reload.dart';

/// KAN-926: the root of the app. Shows [child] unless the server's minimum
/// supported build for this platform is above the running build, in which case
/// the whole app is replaced by [UpdateRequiredApp] — before routing and auth,
/// so a signed-out user is gated too.
///
/// Fails open: while the check is loading, or if it errored, [child] is shown.
/// `main.dart` resolves the check during the launch splash, so in practice the
/// answer is already there on the first frame.
class MinBuildGate extends ConsumerWidget {
  const MinBuildGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(minBuildStatusProvider).valueOrNull;
    if (status == null || !status.blocked) return child;
    return UpdateRequiredApp(status: status);
  }
}

/// The blocking "Update required" screen, in its own non-routed app: there is
/// no route behind it, so nothing to go back or close to.
class UpdateRequiredApp extends ConsumerWidget {
  const UpdateRequiredApp({super.key, required this.status});

  final MinBuildStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withFonts(
        DabblerDesignSystemTheme.withTokens(
          ThemeData(brightness: Brightness.light),
        ),
        locale: locale,
      ),
      darkTheme: DabblerDesignSystemTheme.withFonts(
        DabblerDesignSystemTheme.withTokens(
          ThemeData(brightness: Brightness.dark),
        ),
        locale: locale,
      ),
      themeMode: ThemeMode.system,
      home: _UpdateRequiredScreen(status: status),
    );
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen({required this.status});

  final MinBuildStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final storeUrl = status.storeUrl;
    final Widget? action;
    if (status.isWeb) {
      action = DabblerButton(
        label: l10n.update_required_action_reload,
        onPressed: reloadPage,
      );
    } else if (storeUrl != null) {
      action = DabblerButton(
        label: l10n.update_required_action_update,
        onPressed: () => _openStore(storeUrl),
      );
    } else {
      action = null;
    }
    return PopScope(
      canPop: false,
      child: DabblerPage(
        body: Center(
          child: SingleChildScrollView(
            padding: DabblerInsets.screen,
            child: DabblerEmptyState(
              size: DabblerEmptyStateSize.page,
              icon: 'arrow-circle-up',
              title: l10n.update_required_title,
              text: status.isWeb
                  ? l10n.update_required_message_web
                  : l10n.update_required_message_store,
              action: action,
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing to fall back to; the screen stays.
    }
  }
}
