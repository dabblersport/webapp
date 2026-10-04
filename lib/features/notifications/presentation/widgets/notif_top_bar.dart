// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: back + title + trailing actions is the DS titled top bar; the
// notifications/activity switch is a segmented DabblerTabs under it; "mark all
// read" is a trailing top-bar action (it lived in the unread counter row).

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// Which of the two lists the screen is showing. Moved here with [TopBar] and
/// [ModeToggle], which cannot see a library-private enum from another file.
enum ViewMode { notifications, activity }

class TopBar extends StatelessWidget {
  final String title;
  final ViewMode mode;
  final ValueChanged<ViewMode>? onModeChanged;

  /// When non-null a "mark all read" action shows at the end of the bar.
  final VoidCallback? onMarkAllRead;

  const TopBar({
    super.key,
    required this.title,
    required this.mode,
    required this.onModeChanged,
    this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerNavigationTopBar.titled(
          title: title,
          safeArea: false,
          border: true,
          onBack: () => context.canPop() ? context.pop() : context.go('/home'),
          actions: [
            DabblerNavigationAction(
              icon: 'tick-circle',
              label: l10n.notif_mark_all_read,
              onPressed: onMarkAllRead,
            ),
            DabblerNavigationAction(
              icon: 'setting-2',
              label: l10n.settings_header_title,
              onPressed: () => context.push('/settings/notifications'),
            ),
          ],
        ),
        if (onModeChanged != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space6,
              DabblerSpacing.space2,
              DabblerSpacing.space6,
              DabblerSpacing.space3,
            ),
            child: ModeToggle(mode: mode, onChanged: onModeChanged!),
          ),
      ],
    );
  }
}

class ModeToggle extends StatelessWidget {
  final ViewMode mode;
  final ValueChanged<ViewMode> onChanged;
  const ModeToggle({super.key, required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerTabs(
      variant: DabblerTabsVariant.segmented,
      fullWidth: true,
      value: mode.name,
      items: [
        DabblerTabItem(
          id: ViewMode.notifications.name,
          label: l10n.notif_title_notifications,
          icon: const DabblerIcon('notification'),
        ),
        DabblerTabItem(
          id: ViewMode.activity.name,
          label: l10n.notif_title_activity_log,
          icon: const DabblerIcon('activity'),
        ),
      ],
      onChanged: (id) => onChanged(
        id == ViewMode.activity.name ? ViewMode.activity : ViewMode.notifications,
      ),
    );
  }
}
