// Extracted from notifications_screen_v2.dart by KAN-147 (pt.A of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen.
//
// KAN-989 (W1-F3): every list state of the Notifications tab (design A.1):
// skeleton, initial-load error, refresh failed and offline banners, the
// refreshing line, the footer (Load earlier → Loading → all caught up), the
// empty-filter state, and the scope that tells rows whether actions run.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// KAN-989: whether row actions may run (false while offline: the design's
/// "Actions are unavailable"). Rows read [NotifCenterScope.actionsEnabledOf].
class NotifCenterScope extends InheritedWidget {
  const NotifCenterScope({
    super.key,
    required this.actionsEnabled,
    required super.child,
  });

  final bool actionsEnabled;

  /// True outside a scope.
  static bool actionsEnabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NotifCenterScope>()
          ?.actionsEnabled ??
      true;

  @override
  bool updateShouldNotify(NotifCenterScope old) =>
      old.actionsEnabled != actionsEnabled;
}

/// "Load earlier" (kept for the Activity log, which still uses it).
class LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String? label;
  const LoadMoreButton({super.key, required this.onPressed, this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space6,
        DabblerSpacing.space6,
        DabblerSpacing.space2,
      ),
      child: Center(
        child: DabblerButton(
          label: label ?? AppLocalizations.of(context).notif_load_older,
          tone: DabblerButtonTone.outlined,
          size: DabblerButtonSize.small,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// The list footer: Load earlier notifications → Loading → You're all caught
/// up (design A.1 "Pagination footer").
class NotifListFooter extends StatelessWidget {
  const NotifListFooter({
    super.key,
    required this.hasMore,
    required this.loading,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool loading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (loading) return _InlineStatus(label: l.notif_loading, spinner: true);
    if (hasMore) {
      return LoadMoreButton(onPressed: onLoadMore, label: l.notif_load_earlier);
    }
    return _InlineStatus(label: l.notif_all_caught_up);
  }
}

/// "Refreshing" with a spinner, over a list that stays (design A.1).
class NotifRefreshingRow extends StatelessWidget {
  const NotifRefreshingRow({super.key});

  @override
  Widget build(BuildContext context) => _InlineStatus(
    label: AppLocalizations.of(context).notif_refreshing,
    spinner: true,
  );
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.label, this.spinner = false});

  final String label;
  final bool spinner;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      vertical: DabblerSpacing.space4,
      horizontal: DabblerSpacing.space6,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (spinner) ...const [
          DabblerSpinner(),
          SizedBox(width: DabblerSpacing.space2),
        ],
        DabblerText(
          label,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
      ],
    ),
  );
}

/// Offline: the list on screen was saved at [savedAt]; actions are off.
class NotifOfflineBanner extends StatelessWidget {
  const NotifOfflineBanner({super.key, this.savedAt});

  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final at = savedAt;
    final time = at == null
        ? null
        : DabblerType.toWesternDigits(
            (MediaQuery.alwaysUse24HourFormatOf(context)
                    ? DateFormat.Hm(l.localeName)
                    : DateFormat.jm(l.localeName))
                .format(at.toLocal()),
          );
    return _BannerPad(
      child: DabblerBanner(
        // KAN-1028: offline is the neutral notice (design A), not a warning.
        tone: DabblerBannerTone.neutral,
        icon: const DabblerIcon('cloud-cross'),
        message: time == null
            ? l.notif_offline_banner_unsaved
            : l.notif_offline_banner(time),
      ),
    );
  }
}

/// A refresh failed: the earlier list stays, with Retry.
class NotifRefreshFailedBanner extends StatelessWidget {
  const NotifRefreshFailedBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _BannerPad(
      child: DabblerBanner(
        // KAN-1028: a failed refresh keeps the list — a warning, not an error.
        tone: DabblerBannerTone.warning,
        icon: const DabblerIcon('warning-2'),
        message: l.notif_refresh_failed,
        action: DabblerBannerAction(
          label: l.notif_btn_retry,
          onPressed: onRetry,
        ),
      ),
    );
  }
}

class _BannerPad extends StatelessWidget {
  const _BannerPad({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      DabblerSpacing.space6,
      DabblerSpacing.space2,
      DabblerSpacing.space6,
      DabblerSpacing.space2,
    ),
    child: child,
  );
}

/// Initial-load skeleton: six row-shaped placeholders (design A.1).
class NotifLoadingView extends StatelessWidget {
  const NotifLoadingView({super.key});

  static const int rows = 6;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
        vertical: DabblerSpacing.space4,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: DabblerSpacing.space4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  DabblerSkeleton.circle(),
                  SizedBox(width: DabblerSpacing.space4),
                  Expanded(child: DabblerSkeleton.text(lines: 2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The Activity log's error (its message and Retry).
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: DabblerEmptyState.error(
        title: l10n.notif_error_prefix(message),
        onRetry: onRetry,
        retryLabel: l10n.notif_btn_retry,
      ),
    );
  }
}

/// The Notifications tab's initial load failed (design A.1): "Couldn't load
/// notifications" with Try again.
class NotifLoadFailedView extends StatelessWidget {
  const NotifLoadFailedView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: DabblerEmptyState.error(
        title: l.notif_load_failed_title,
        text: l.notif_load_failed_hint,
        onRetry: onRetry,
        retryLabel: l.notif_try_again,
      ),
    );
  }
}

/// Nothing under the chosen chip: "Nothing in {filter}" with Show all.
class NotifFilterEmptyState extends StatelessWidget {
  const NotifFilterEmptyState({
    super.key,
    required this.filterLabel,
    required this.onShowAll,
  });

  final String filterLabel;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: DabblerSpacing.space11,
        horizontal: DabblerSpacing.space8,
      ),
      child: DabblerEmptyState(
        icon: 'filter',
        title: l.notif_empty_filter_title(filterLabel),
        text: l.notif_empty_filter_hint,
        size: DabblerEmptyStateSize.page,
        action: DabblerButton(
          label: l.notif_show_all,
          tone: DabblerButtonTone.outlined,
          size: DabblerButtonSize.small,
          onPressed: onShowAll,
        ),
      ),
    );
  }
}
