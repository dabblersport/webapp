// The "What reaches you" sheet behind the Notifications top bar's gear
// (`Notifications.dc.html:190-235`): a toggle per notification group, plus the
// quiet-hours window, fed by the existing notification-settings controller.
// The full screen stays at /settings/notifications.

import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Opens the sheet over the current route.
void showNotifPrefsSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showDabblerSheet<void>(
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

class _Pref {
  const _Pref(this.icon, this.kinds);
  final String icon;
  final List<String> kinds;
}

/// The groups the design lists, each mapped to the `notification_kinds` keys
/// the existing settings screen already toggles together.
const _prefs = <String, _Pref>{
  'invites': _Pref('game', [
    'game.invited',
    'game.join_request',
    'game.join_accepted',
  ]),
  'waitlist': _Pref('notification-bing', ['game.waitlist_promoted']),
  'payments': _Pref('wallet', ['arena.payment_required']),
  'social': _Pref('people', [
    'social.post_liked',
    'social.post_reacted',
    'social.comment_liked',
    'social.post_commented',
    'social.mentioned_in_post',
    'social.mentioned_in_comment',
    'social.followed',
  ]),
};

class NotifPrefsSheetBody extends ConsumerWidget {
  const NotifPrefsSheetBody({super.key, required this.onOpenFullSettings});

  /// Opens the full notification-settings screen (quiet-hours editing lives
  /// there).
  final VoidCallback onOpenFullSettings;

  static String _time(BuildContext context, int minutes) {
    final locale = Localizations.localeOf(context).toString();
    final at = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    final pattern = minutes % 60 == 0 ? 'h a' : 'h:mm a';
    return DabblerType.toWesternDigits(DateFormat(pattern, locale).format(at));
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
    final titles = <String, (String, String)>{
      'invites': (l10n.notif_pref_invites_title, l10n.notif_pref_invites_sub),
      'waitlist': (
        l10n.notif_pref_waitlist_title,
        l10n.notif_pref_waitlist_sub,
      ),
      'payments': (
        l10n.notif_pref_payments_title,
        l10n.notif_pref_payments_sub,
      ),
      'social': (l10n.notif_pref_social_title, l10n.notif_pref_social_sub),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in _prefs.entries)
          DabblerInputRow.toggle(
            flat: true,
            leading: DabblerIcon(entry.value.icon, size: DabblerSizing.iconMd),
            title: titles[entry.key]!.$1,
            subtitle: titles[entry.key]!.$2,
            checked: !entry.value.kinds.any(settings.isKindMuted),
            onChanged: (on) =>
                controller.setKindsEnabled(entry.value.kinds, on),
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
                    _time(context, settings.quietStartMin!),
                    _time(context, settings.quietEndMin!),
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
