import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// Opens the design's date-of-birth sheet — three scrolling columns for day,
/// month and year over a full-width confirm action — and resolves with the
/// confirmed date, or null when dismissed.
///
/// [initialDate] is null when nothing has been chosen yet; the primary action
/// then reads Cancel, as in the design (`Auth and Onboarding.dc.html:586`).
Future<DateTime?> showBirthDateSheet({
  required BuildContext context,
  required DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDabblerSheet<DateTime>(
    context: context,
    title: AppLocalizations.of(context).onb_dob_label,
    detent: DabblerSheetDetent.content,
    showCloseButton: false,
    builder: (_) => _BirthDateColumns(
      initial: initialDate,
      first: firstDate,
      last: lastDate,
    ),
  );
}

class _BirthDateColumns extends StatefulWidget {
  const _BirthDateColumns({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime? initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_BirthDateColumns> createState() => _BirthDateColumnsState();
}

class _BirthDateColumnsState extends State<_BirthDateColumns> {
  int? _day;
  int? _month;
  int? _year;

  @override
  void initState() {
    super.initState();
    _day = widget.initial?.day;
    _month = widget.initial?.month;
    _year = widget.initial?.year;
  }

  bool get _complete => _day != null && _month != null && _year != null;

  /// The chosen date, with the day held inside the month and the whole date
  /// held inside the allowed range.
  DateTime _resolve() {
    final lastDayOfMonth = DateTime(_year!, _month! + 1, 0).day;
    var date = DateTime(
      _year!,
      _month!,
      _day! > lastDayOfMonth ? lastDayOfMonth : _day!,
    );
    if (date.isAfter(widget.last)) date = widget.last;
    if (date.isBefore(widget.first)) date = widget.first;
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final months = <String>[
      l10n.onb_month_1,
      l10n.onb_month_2,
      l10n.onb_month_3,
      l10n.onb_month_4,
      l10n.onb_month_5,
      l10n.onb_month_6,
      l10n.onb_month_7,
      l10n.onb_month_8,
      l10n.onb_month_9,
      l10n.onb_month_10,
      l10n.onb_month_11,
      l10n.onb_month_12,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerDateColumns(
          dayLabel: l10n.onb_day,
          monthLabel: l10n.onb_month,
          yearLabel: l10n.onb_year,
          monthNames: months,
          firstYear: widget.first.year,
          lastYear: widget.last.year,
          day: _day,
          month: _month,
          year: _year,
          onDayChanged: (d) => setState(() => _day = d),
          onMonthChanged: (m) => setState(() => _month = m),
          onYearChanged: (y) => setState(() => _year = y),
        ),
        // The frame's lists are 200 tall and the action sits 12 below them; the
        // design system's lists are 192 (the nearest grid step), so the action
        // takes the nearest step to the 20 that keeps it where the frame has it.
        const DabblerGap.v(DabblerSpacing.space7),
        DabblerButton(
          label: _complete
              ? l10n.onb_dob_sheet_confirm
              : l10n.onb_dob_sheet_cancel,
          size: DabblerButtonSize.full,
          fullWidth: true,
          onPressed: () =>
              Navigator.pop(context, _complete ? _resolve() : null),
        ),
      ],
    );
  }
}
