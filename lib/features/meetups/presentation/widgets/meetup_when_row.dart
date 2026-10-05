import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// The "When" block of the create and edit drawers (`Home Feed.dc.html:1163`):
/// the label and its caption, then the date, start and End pills on one wrap
/// beneath, so long times never squeeze the label.
class MeetupWhenRow extends StatelessWidget {
  const MeetupWhenRow({
    super.key,
    required this.date,
    required this.start,
    required this.end,
    required this.onDate,
    required this.onStart,
    required this.onEnd,
  });

  final DateTime? date;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final VoidCallback onDate;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  String _date(AppLocalizations l) {
    final d = date;
    if (d == null) return l.game_date;
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return l.game_today;
    }
    return DateFormat('MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final today =
        date != null &&
        date!.year == now.year &&
        date!.month == now.month &&
        date!.day == now.day;
    return ComposerSettingsRow(
      icon: 'calendar',
      title: l.meetups_when,
      subtitle: l.meetups_when_sub,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DabblerSpacing.space2,
        children: <Widget>[
          DabblerChip(
            label: _date(l),
            dense: true,
            selected: today,
            onTap: onDate,
          ),
          DabblerChip(
            label: start == null
                ? l.game_time
                : DabblerTimeFormat.format(start!),
            dense: true,
            onTap: onStart,
          ),
          DabblerChip(
            label: end == null ? l.meetups_end : DabblerTimeFormat.format(end!),
            dense: true,
            onTap: onEnd,
          ),
        ],
      ),
    );
  }
}
