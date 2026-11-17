// The "What reaches you" sheet behind the Notifications top bar's gear
// (`Notifications.dc.html:190-235`), fed by the notification-settings
// controller. The full screen stays at /settings/notifications.
//
// KAN-991: one switch per category (Social, Messages, Games, Meetups,
// Rewards & announcements), the same categories as the settings screen. A
// switch turns the category's in-app and push channels on or off together
// (Rewards & announcements is in-app only). Booking and payments are hidden
// (F-12). The quiet-hours chip shows the device's 12/24-hour format.

import 'dart:async';

import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings_keys.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/notification_settings_categories_section.dart'
    show notifCategoryLabel;
import 'package:dabbler/features/profile/presentation/screens/settings/notification_settings_rows.dart'
    show notifSettingsClock;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opens the sheet over the current route.
void showNotifPrefsSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showAppSheet<void>(
    context: context,
    title: l10n.notif_prefs_title,
    detent: DabblerSheetDetent.content,
    pageBackground: true,
    showCloseButton: false,
    headerActionBuilder: (sheetContext) => DabblerButton(
      label: l10n.notif_prefs_done,
      size: DabblerButtonSize.small,
      tone: DabblerButtonTone.neutral,
      onPressed: () => Navigator.of(sheetContext).pop(),
    ),
    builder: (_) => NotifPrefsSheetBody(
      onOpenFullSettings: () => context.push('/settings/notifications'),
    ),
  );
}

/// The channels a category's sheet switch drives.
List<String> _channelsOf(String category) => category == NotifCategoryKey.system
    ? const <String>[NotifChannel.inApp]
    : const <String>[NotifChannel.inApp, NotifChannel.push];

/// On when any of the category's channels is on.
bool notifPrefsCategoryOn(NotificationSettings s, String category) =>
    _channelsOf(category).any((ch) => s.categoryOn(category, ch));

class NotifPrefsSheetBody extends ConsumerWidget {
  const NotifPrefsSheetBody({super.key, required this.onOpenFullSettings});

  /// Opens the full notification-settings screen (quiet-hours editing lives
  /// there).
  final VoidCallback onOpenFullSettings;

  Future<void> _set(
    NotificationSettingsController controller,
    String category,
    bool on,
  ) async {
    for (final String ch in _channelsOf(category)) {
      await controller.setCategory(category, ch, on);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(notificationSettingsControllerProvider).settings;
    if (settings == null) {
      return const Center(child: DabblerSpinner());
    }
    final controller = ref.read(
      notificationSettingsControllerProvider.notifier,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final String c in NotifCategoryKey.shown)
          DabblerInputRow.toggle(
            key: ValueKey<String>('notif-pref-$c'),
            flat: true,
            leading: DabblerIcon(
              notifCategoryLabel(l10n, c).icon,
              size: DabblerSizing.iconMd,
            ),
            title: notifCategoryLabel(l10n, c).title,
            subtitle: notifCategoryLabel(l10n, c).sub,
            checked: notifPrefsCategoryOn(settings, c),
            onChanged: (on) => unawaited(_set(controller, c, on)),
          ),
        DabblerInputRow(
          flat: true,
          showDivider: false,
          leading: const DabblerIcon('clock', size: DabblerSizing.iconMd),
          title: l10n.notif_quiet_hours_title,
          subtitle: l10n.notif_quiet_hours_sub,
          trailing: DabblerChip(
            label: settings.hasQuietHours
                ? l10n.notif_quiet_hours_range(
                    notifSettingsClock(context, settings.quietStartMin!),
                    notifSettingsClock(context, settings.quietEndMin!),
                  )
                : l10n.notif_quiet_hours_off,
            trailingIcon: const DabblerIcon(
              'arrow-circle-right',
              mirrorInRtl: true,
            ),
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              onOpenFullSettings();
            },
          ),
        ),
      ],
    );
  }
}
