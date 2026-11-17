// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: back + title + trailing actions is the DS titled top bar; the
// notifications/activity switch is a segmented DabblerTabs under it; "mark all
// read" is a trailing top-bar action (it lived in the unread counter row).
//
// KAN-989 (W1-F3, NC-07 / D-2): the bar carries Refresh on both tabs; Mark all
// read and the unread count are on the Notifications tab only.

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

  /// Enables "mark all read" (Notifications tab only; dimmed when null).
  final VoidCallback? onMarkAllRead;

  /// Opens the "What reaches you" preferences sheet.
  final VoidCallback onOpenSettings;

  /// Refreshes the tab's list; [refreshing] shows its spinner.
  final VoidCallback? onRefresh;
  final bool refreshing;

  /// The server's unread count, shown under the bar on the Notifications tab.
  final int unreadCount;

  const TopBar({
    super.key,
    required this.title,
    required this.mode,
    required this.onModeChanged,
    this.onMarkAllRead,
    required this.onOpenSettings,
    this.onRefresh,
    this.refreshing = false,
    this.unreadCount = 0,
  });

  bool get _isNotifications => mode == ViewMode.notifications;

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
              icon: 'refresh',
              label: l10n.notif_refresh,
              loading: refreshing,
              onPressed: onRefresh,
            ),
            if (_isNotifications)
              DabblerNavigationAction(
                icon: 'tick-circle',
                label: l10n.notif_mark_all_read,
                // Brand while something is unread, subtle once nothing is.
                tone: onMarkAllRead != null
                    ? DabblerNavigationActionTone.brand
                    : DabblerNavigationActionTone.subtle,
                onPressed: onMarkAllRead,
              ),
            DabblerNavigationAction(
              icon: 'setting-2',
              label: l10n.settings_header_title,
              onPressed: onOpenSettings,
            ),
          ],
        ),
        if (_isNotifications && unreadCount > 0)
          Padding(
            key: const ValueKey<String>('notif-unread-count'),
            padding: const EdgeInsetsDirectional.only(
              start: DabblerSpacing.space6,
              top: DabblerSpacing.space2,
              end: DabblerSpacing.space6,
            ),
            child: DabblerText(
              DabblerType.toWesternDigits(l10n.notif_unread_count(unreadCount)),
              style: DabblerType.footnote,
              tone: DabblerTextTone.secondary,
            ),
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
        id == ViewMode.activity.name
            ? ViewMode.activity
            : ViewMode.notifications,
      ),
    );
  }
}
