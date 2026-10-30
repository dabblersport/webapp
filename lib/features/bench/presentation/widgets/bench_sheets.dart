import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// A bench date in the viewer's locale (`yMMMd`), Western digits.
String benchDate(BuildContext context, DateTime date) =>
    DabblerType.toWesternDigits(
      DateFormat.yMMMd(
        Localizations.localeOf(context).toString(),
      ).format(date.toLocal()),
    );

/// "Start bench mode?" with a summary of what applies. Resolves true on
/// Start bench; Cancel (or a dismiss) resolves false and keeps the form.
Future<bool> showBenchConfirmSheet(
  BuildContext context,
  BenchSettings settings,
) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final DateTime? until = settings.benchUntil;
  final bool? confirmed = await showAppSheet<bool>(
    context: context,
    title: l10n.bench_confirm_title,
    detent: DabblerSheetDetent.content,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerText(
          l10n.bench_confirm_body,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space5),
        if (settings.hideInFeed)
          _SummaryRow(icon: 'eye-slash', text: l10n.bench_confirm_sum_feed),
        if (settings.hideInSearch)
          _SummaryRow(
            icon: 'search-normal',
            text: l10n.bench_confirm_sum_search,
          ),
        if (settings.blockFriendRequests)
          _SummaryRow(icon: 'user-add', text: l10n.bench_confirm_sum_friends),
        if (settings.suppressSocialNotifications)
          _SummaryRow(
            icon: 'notification-bing',
            text: l10n.bench_confirm_sum_notifs,
          ),
        _SummaryRow(
          icon: 'calendar-1',
          text: until == null
              ? l10n.bench_confirm_sum_no_end
              : l10n.bench_confirm_sum_end(benchDate(sheetContext, until)),
        ),
        const DabblerGap.v(DabblerSpacing.space5),
        DabblerButton(
          label: l10n.bench_start,
          fullWidth: true,
          onPressed: () => Navigator.pop(sheetContext, true),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerButton(
          label: l10n.bench_cancel,
          tone: DabblerButtonTone.outlined,
          fullWidth: true,
          onPressed: () => Navigator.pop(sheetContext, false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// "End bench now?". Resolves true on End bench; Keep bench resolves false.
Future<bool> showBenchEndSheet(BuildContext context) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool? confirmed = await showAppSheet<bool>(
    context: context,
    title: l10n.bench_end_confirm_title,
    detent: DabblerSheetDetent.content,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerText(
          l10n.bench_end_confirm_body,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
        const DabblerGap.v(DabblerSpacing.space5),
        DabblerButton(
          label: l10n.bench_end,
          fullWidth: true,
          onPressed: () => Navigator.pop(sheetContext, true),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        DabblerButton(
          label: l10n.bench_end_confirm_keep,
          tone: DabblerButtonTone.outlined,
          fullWidth: true,
          onPressed: () => Navigator.pop(sheetContext, false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The end-date picker: a calendar from today on; tapping a day picks it.
Future<DateTime?> showBenchEndDateSheet(
  BuildContext context, {
  DateTime? initial,
}) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  return showAppSheet<DateTime>(
    context: context,
    title: AppLocalizations.of(context).bench_end_label,
    detent: DabblerSheetDetent.content,
    builder: (_) => _BenchEndCalendar(
      first: today,
      initial: initial != null && !initial.isBefore(today) ? initial : null,
    ),
  );
}

class _BenchEndCalendar extends StatefulWidget {
  const _BenchEndCalendar({required this.first, this.initial});

  final DateTime first;
  final DateTime? initial;

  @override
  State<_BenchEndCalendar> createState() => _BenchEndCalendarState();
}

class _BenchEndCalendarState extends State<_BenchEndCalendar> {
  late DateTime _month = widget.initial ?? widget.first;

  @override
  Widget build(BuildContext context) {
    final DateTime? initial = widget.initial;
    return DabblerCalendar(
      month: _month,
      selected: <DateTime>{if (initial != null) initial},
      minimum: widget.first,
      showActions: false,
      onSelect: (day) => Navigator.pop(context, day),
      onMonthChanged: (month) => setState(() => _month = month),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space3),
    child: Row(
      children: [
        DabblerIcon(
          icon,
          size: DabblerSizing.iconInline,
          color: DabblerColors.of(context).textSecondary,
        ),
        const DabblerGap.h(DabblerSpacing.space3),
        Expanded(child: DabblerText(text, style: DabblerType.subheadline)),
      ],
    ),
  );
}
