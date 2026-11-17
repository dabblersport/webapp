// KAN-991 (W1-F5): the notification settings screen, on the single settings
// store (`notification_settings`, KAN-975 RPCs). One file per section:
// categories, message preview, quiet hours, reminders, muted list. When the
// phone has notifications turned off, a banner leads to the system settings
// and every push switch is disabled; in-app switches keep working.

import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/sync/settings_sync_handlers.dart' show SettingKeys;
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/setting_sync_hint.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings_inner_top_bar.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/services/notifications/push_notification_service.dart';

import 'notification_settings_categories_section.dart';
import 'notification_settings_muted_section.dart';
import 'notification_settings_preview_section.dart';
import 'notification_settings_quiet_section.dart';
import 'notification_settings_reminders_section.dart';

/// Screen for managing notification preferences.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  // The phone's permission can change in system settings meanwhile.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(notificationOsPushDeniedProvider),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static String _errorText(AppLocalizations l10n, String error) =>
      switch (error) {
        kSecurityMuteRefused => l10n.notif_settings_security_mute_refused,
        'rejected' => l10n.notif_settings_save_rejected,
        _ => l10n.notif_settings_update_failed(error),
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final NotificationSettingsState state = ref.watch(
      notificationSettingsControllerProvider,
    );
    final bool osDenied =
        ref.watch(notificationOsPushDeniedProvider).valueOrNull ?? false;

    // Surface save/load errors without blocking the UI.
    ref.listen<NotificationSettingsState>(
      notificationSettingsControllerProvider,
      (prev, next) {
        final String? error = next.error;
        if (error != null && error != prev?.error) {
          DabblerToastProvider.of(context).show(
            DabblerToastSpec(
              message: _errorText(l10n, error),
              tone: DabblerToastTone.error,
            ),
          );
        }
      },
    );

    return DabblerPage(
      topBar: settingsInnerTopBar(
        context,
        title: l10n.settings_tile_notifications,
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space11,
        ),
        children: [_body(context, state, osDenied)],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    NotificationSettingsState state,
    bool osDenied,
  ) {
    final settings = state.settings;
    if (settings == null) {
      return const Padding(
        padding: EdgeInsetsDirectional.only(top: DabblerSpacing.space11),
        child: Center(child: DabblerSpinner()),
      );
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final NotificationSettingsController controller = ref.read(
      notificationSettingsControllerProvider.notifier,
    );
    const Widget gap = SizedBox(height: DabblerSpacing.space7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingSyncHint([SettingKeys.notifications]),
        if (osDenied) ...[
          DabblerBanner(
            key: const ValueKey<String>('notif-os-denied'),
            tone: DabblerBannerTone.warning,
            icon: const DabblerIcon('notification'),
            title: l10n.notif_settings_os_denied_title,
            message: l10n.notif_settings_os_denied_body,
            action: DabblerBannerAction(
              label: l10n.notif_settings_open_settings,
              onPressed: () =>
                  unawaited(ref.read(notificationOpenSystemSettingsProvider)()),
            ),
          ),
          gap,
        ],
        NotificationSettingsCategoriesSection(
          settings: settings,
          controller: controller,
          osDenied: osDenied,
          onPushTurnedOn: () => unawaited(
            PushNotificationService.instance.requestNotificationPermission(),
          ),
        ),
        gap,
        NotificationSettingsPreviewSection(
          settings: settings,
          controller: controller,
        ),
        gap,
        NotificationSettingsQuietSection(
          settings: settings,
          controller: controller,
        ),
        gap,
        NotificationSettingsRemindersSection(
          settings: settings,
          controller: controller,
          pushLocked: osDenied || !settings.pushEnabled,
        ),
        gap,
        NotificationSettingsMutedSection(
          settings: settings,
          controller: controller,
        ),
      ],
    );
  }
}
