import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:dabbler/features/bench/presentation/widgets/bench_sheets.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The benched state: the "On bench" card, then End bench and Edit. Both
/// buttons are disabled offline or while a write runs.
class BenchStatusView extends StatelessWidget {
  const BenchStatusView({
    super.key,
    required this.status,
    required this.offline,
    required this.ending,
    required this.locked,
    required this.onEnd,
    required this.onEdit,
    this.banner,
  });

  final BenchStatus status;
  final bool offline;

  /// End bench is in flight.
  final bool ending;

  /// Any write is in flight.
  final bool locked;
  final VoidCallback onEnd;
  final VoidCallback onEdit;

  /// The offline warning or a failed write's banner.
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool disabled = offline || locked;
    final DateTime? since = status.benchedAt;
    final DateTime? until = status.benchUntil;
    final String? reason = status.reason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null) ...[
          banner!,
          const DabblerGap.v(DabblerSpacing.space6),
        ],
        DabblerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DabblerBadge(
                  label: l10n.bench_status_badge,
                  status: DabblerColors.of(context).info,
                ),
              ),
              const DabblerGap.v(DabblerSpacing.space3),
              DabblerText(l10n.bench_status_head, style: DabblerType.title2),
              const DabblerGap.v(DabblerSpacing.space3),
              if (since != null)
                _Line(
                  label: l10n.bench_status_since,
                  value: benchDate(context, since),
                ),
              _Line(
                label: l10n.bench_status_until,
                value: until == null
                    ? l10n.bench_status_no_end
                    : benchDate(context, until),
              ),
              if (reason != null)
                _Line(label: l10n.bench_status_reason, value: reason),
              const DabblerGap.v(DabblerSpacing.space6),
              DabblerText(
                l10n.bench_status_hidden_head,
                style: DabblerType.headline,
                weight: DabblerTextWeight.semibold,
              ),
              const DabblerGap.v(DabblerSpacing.space3),
              const DabblerDivider(),
              DabblerKeyValueRow(
                label: l10n.bench_status_feed,
                value: status.hideInFeed
                    ? l10n.bench_status_hidden
                    : l10n.bench_status_visible,
              ),
              DabblerKeyValueRow(
                label: l10n.bench_status_search,
                value: status.hideInSearch
                    ? l10n.bench_status_hidden
                    : l10n.bench_status_visible,
              ),
              DabblerKeyValueRow(
                label: l10n.bench_status_friends,
                value: status.blockFriendRequests
                    ? l10n.bench_status_blocked
                    : l10n.bench_status_allowed,
              ),
              DabblerKeyValueRow(
                label: l10n.bench_status_notifs,
                value: status.suppressSocialNotifications
                    ? l10n.bench_status_muted
                    : l10n.bench_status_on,
              ),
            ],
          ),
        ),
        const DabblerGap.v(DabblerSpacing.space7),
        DabblerButton(
          label: l10n.bench_end,
          fullWidth: true,
          loading: ending,
          disabled: disabled,
          onPressed: disabled ? null : onEnd,
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerButton(
          label: l10n.bench_edit_action,
          tone: DabblerButtonTone.outlined,
          fullWidth: true,
          disabled: disabled,
          onPressed: disabled ? null : onEdit,
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DabblerText(
          label,
          style: DabblerType.subheadline,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.h(DabblerSpacing.space3),
        Expanded(child: DabblerText(value, style: DabblerType.subheadline)),
      ],
    ),
  );
}

/// The loading state: a skeleton of the status card and its two buttons,
/// with the "Loading" spinner.
class BenchLoadingView extends StatelessWidget {
  const BenchLoadingView({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DabblerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DabblerSkeleton.rect(
                width: DabblerSizing.illustrationMd,
                height: DabblerSizing.iconLg,
              ),
            ),
            DabblerGap.v(DabblerSpacing.space6),
            DabblerSkeleton.text(lines: 3),
            DabblerGap.v(DabblerSpacing.space6),
            DabblerSkeleton.text(lines: 4),
          ],
        ),
      ),
      const DabblerGap.v(DabblerSpacing.space7),
      const DabblerSkeleton.rect(height: DabblerSizing.tileLg),
      const DabblerGap.v(DabblerSpacing.space3),
      const DabblerSkeleton.rect(height: DabblerSizing.tileLg),
      const DabblerGap.v(DabblerSpacing.space7),
      Center(
        child: DabblerSpinner(
          label: AppLocalizations.of(context).bench_loading,
        ),
      ),
    ],
  );
}
