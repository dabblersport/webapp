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

  /// Refreshes the tab's list; [refreshing] shows its spinner.
  final VoidCallback? onRefresh;
  final bool refreshing;

  const TopBar({
    super.key,
    required this.title,
    required this.mode,
    required this.onModeChanged,
    this.onMarkAllRead,
    this.onRefresh,
    this.refreshing = false,
  });

  bool get _isNotifications => mode == ViewMode.notifications;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.maybeOf(context);
    final canBack = router?.canPop() ?? false;
    // KAN-1028: design A header — display title, Refresh, and a text
    // "Mark all read" (Notifications tab only). No settings glyph (settings
    // live under Profile > Settings > Notifications) and no bottom border.
    // Back shows only when the route was pushed.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space6,
            DabblerSpacing.space1,
            DabblerSpacing.space4,
            DabblerSpacing.space3,
          ),
          child: Row(
            children: [
              if (canBack)
                DabblerButton.icon(
                  key: const ValueKey<String>('notif-header-back'),
                  icon: DabblerNavigationTopBar.backIcon,
                  semanticLabel: l10n.notif_back,
                  tone: DabblerButtonTone.text,
                  mirrorInRtl: true,
                  onPressed: () => router!.pop(),
                ),
              Expanded(
                child: DabblerText(
                  title,
                  key: const ValueKey<String>('notif-header-title'),
                  style: DabblerType.displaySection,
                  maxLines: 1,
                ),
              ),
              DabblerButton.icon(
                key: const ValueKey<String>('notif-header-refresh'),
                icon: 'refresh',
                semanticLabel: l10n.notif_refresh,
                tone: DabblerButtonTone.text,
                loading: refreshing,
                onPressed: onRefresh,
              ),
              if (_isNotifications)
                DabblerTextLink(
                  key: const ValueKey<String>('notif-mark-all-read'),
                  label: l10n.notif_mark_all_read,
                  underline: false,
                  onPressed: onMarkAllRead,
                ),
            ],
          ),
        ),
        if (onModeChanged != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: DabblerSpacing.space6,
              end: DabblerSpacing.space6,
              bottom: DabblerSpacing.space3,
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
        ),
        DabblerTabItem(
          id: ViewMode.activity.name,
          label: l10n.notif_title_activity_log,
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
