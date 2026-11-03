import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:dabbler/features/bench/presentation/providers/bench_providers.dart';
import 'package:dabbler/features/bench/presentation/widgets/bench_sheets.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void _openBench(BuildContext context) => context.push(RoutePaths.settingsBench);

/// The viewer's bench status when it is loaded and benched, else null.
BenchStatus? _benched(WidgetRef ref) {
  final BenchStatus? status = ref.watch(benchStatusProvider).valueOrNull;
  return status != null && status.isBenched ? status : null;
}

/// Settings → "Bench mode", the only entry point (KAN-706 behaviour 7). The
/// subtitle is Off, or the end date while benched.
class BenchSettingsRow extends ConsumerWidget {
  const BenchSettingsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.benchMode) return const SizedBox.shrink();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BenchStatus? status = ref.watch(benchStatusProvider).valueOrNull;
    final DateTime? until = status?.benchUntil;
    final String? subtitle = status == null
        ? null
        : !status.isBenched
        ? l10n.bench_row_off
        : until == null
        ? l10n.bench_row_no_end
        : l10n.bench_row_until(benchDate(context, until));
    return DabblerRowGroup(
      children: [
        DabblerInputRow(
          flat: true,
          showDivider: false,
          onTap: () => _openBench(context),
          leading: DabblerIcon(
            'pause-circle',
            size: DabblerSizing.iconRow,
            color: DabblerColors.of(context).textSecondary,
          ),
          title: l10n.bench_row_title,
          subtitle: subtitle,
          trailing: const DabblerChevron(circled: true),
        ),
      ],
    );
  }
}

/// Home: "On bench until {date}" with Manage, while benched. Not
/// dismissible, never blocks anything (KAN-706 8a).
class BenchHomeStrip extends ConsumerWidget {
  const BenchHomeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.benchMode) return const SizedBox.shrink();
    final BenchStatus? status = _benched(ref);
    if (status == null) return const SizedBox.shrink();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? until = status.benchUntil;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space5,
        DabblerSpacing.space3,
        DabblerSpacing.space5,
        DabblerSpacing.space3,
      ),
      child: DabblerBanner(
        tone: DabblerBannerTone.info,
        icon: const DabblerIcon('pause-circle'),
        title: until == null
            ? l10n.bench_indicator_home_no_end
            : l10n.bench_indicator_home(benchDate(context, until)),
        action: DabblerBannerAction(
          label: l10n.bench_manage,
          onPressed: () => _openBench(context),
        ),
      ),
    );
  }
}

/// Profile: the "On bench" badge and, when hidden in the feed and search
/// until a date, that line with a small Manage button (KAN-706 8b).
class BenchProfileIndicator extends ConsumerWidget {
  const BenchProfileIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.benchMode) return const SizedBox.shrink();
    final BenchStatus? status = _benched(ref);
    if (status == null) return const SizedBox.shrink();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? until = status.benchUntil;
    final bool line = until != null && status.hideInFeed && status.hideInSearch;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space5,
        top: DabblerSpacing.space3,
        end: DabblerSpacing.space5,
      ),
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
          DabblerCard(
            child: Row(
              children: [
                Expanded(
                  child: DabblerText(
                    line
                        ? l10n.bench_indicator_profile(
                            benchDate(context, until),
                          )
                        : l10n.bench_status_head,
                    style: DabblerType.subheadline,
                  ),
                ),
                const DabblerGap.h(DabblerSpacing.space3),
                DabblerButton(
                  label: l10n.bench_manage,
                  tone: DabblerButtonTone.outlined,
                  size: DabblerButtonSize.small,
                  onPressed: () => _openBench(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
