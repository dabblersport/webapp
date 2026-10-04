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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ComposerSettingsRow(
          icon: 'calendar',
          title: l.meetups_when,
          subtitle: l.meetups_when_sub,
          showDivider: false,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            bottom: DabblerSpacing.space3,
          ),
          child: Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: <Widget>[
              ComposerCompactSelectPill(value: _date(l), onTap: onDate),
              ComposerCompactSelectPill(
                value: start == null
                    ? l.game_time
                    : DabblerTimeFormat.format(start!),
                onTap: onStart,
              ),
              ComposerCompactSelectPill(
                value: end == null
                    ? l.meetups_end
                    : DabblerTimeFormat.format(end!),
                onTap: onEnd,
              ),
            ],
          ),
        ),
        const DabblerDivider(),
      ],
    );
  }
}
