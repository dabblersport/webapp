import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KAN-622: loading, empty and error-with-retry for one section of the page.
/// Each section owns its three states, so one failing list never blanks the
/// others, and nothing is drawn from sample data.
class SportSectionSkeleton extends StatelessWidget {
  const SportSectionSkeleton({super.key, this.rows = 2});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < rows; i++) ...<Widget>[
          if (i > 0) const DabblerGap.v(DabblerSpacing.space4),
          const DabblerSkeleton.card(),
        ],
      ],
    );
  }
}

class SportSectionError extends StatelessWidget {
  const SportSectionError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return DabblerEmptyState.error(
      title: l.sport_overview_error_title,
      text: l.sport_overview_error_text,
      size: DabblerEmptyStateSize.inline,
      retryLabel: l.sport_overview_retry,
      onRetry: onRetry,
    );
  }
}

class SportSectionEmpty extends StatelessWidget {
  const SportSectionEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final String icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DabblerEmptyState(
      icon: icon,
      title: title,
      text: text,
      size: DabblerEmptyStateSize.inline,
    );
  }
}

/// Draws [value] as skeleton, error with Retry, the empty state or [data].
/// A refresh keeps the rows already shown (Riverpod keeps the old value while
/// it reloads), so a retry never flashes an empty page.
Widget sportAsyncSection<T>({
  required AsyncValue<T> value,
  required Widget Function(T data) data,
  required bool Function(T data) isEmpty,
  required Widget empty,
  required VoidCallback onRetry,
  int skeletonRows = 2,
}) {
  return value.when(
    skipLoadingOnRefresh: false,
    loading: () => SportSectionSkeleton(rows: skeletonRows),
    error: (_, _) => SportSectionError(onRetry: onRetry),
    data: (T d) => isEmpty(d) ? empty : data(d),
  );
}
