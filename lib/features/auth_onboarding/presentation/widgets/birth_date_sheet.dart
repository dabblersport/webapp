import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Opens a DS sheet with a [DabblerCalendar] for a date of birth and resolves
/// with the confirmed date, or null when dismissed. The calendar's year chip
/// swaps the grid for a year list, since a birth year is decades back.
Future<DateTime?> showBirthDateSheet({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDabblerSheet<DateTime>(
    context: context,
    detents: const <double>[0.75],
    builder: (_) =>
        _BirthDateSheet(initial: initialDate, first: firstDate, last: lastDate),
  );
}

class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  late DateTime _selected = widget.initial;
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);
  // Opens on the year list: a birth date is picked year first.
  bool _pickingYear = true;

  void _pickYear(int year) {
    setState(() {
      var d = DateTime(year, _selected.month, _selected.day);
      if (d.isAfter(widget.last)) d = widget.last;
      if (d.isBefore(widget.first)) d = widget.first;
      _selected = d;
      _month = DateTime(d.year, d.month);
      _pickingYear = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pickingYear) {
      final years = <int>[
        for (var y = widget.last.year; y >= widget.first.year; y--) y,
      ];
      return GridView.count(
        crossAxisCount: 4,
        padding: const EdgeInsetsDirectional.all(DabblerSpacing.space6),
        mainAxisSpacing: DabblerSpacing.space3,
        crossAxisSpacing: DabblerSpacing.space3,
        childAspectRatio: 2,
        children: [
          for (final y in years)
            Center(
              child: DabblerChip(
                label: '$y',
                selected: y == _selected.year,
                onTap: () => _pickYear(y),
              ),
            ),
        ],
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
      ),
      child: DabblerCalendar(
        month: _month,
        selected: <DateTime>{_selected},
        minimum: widget.first,
        maximum: widget.last,
        onSelect: (d) => setState(() => _selected = d),
        onMonthChanged: (m) => setState(() => _month = m),
        onYearPressed: () => setState(() => _pickingYear = true),
        onConfirm: () => Navigator.pop(context, _selected),
        onCancel: () => Navigator.pop(context),
      ),
    );
  }
}
