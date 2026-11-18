// KAN-999 (G-05): the organiser's "Attendance" row in the game detail and the
// meetup manage screen. The caller places it only for the organiser; the list
// itself is refused by the server to anyone else.

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class AttendanceListEntry extends StatelessWidget {
  const AttendanceListEntry({
    super.key,
    required this.eventId,
    this.title,
    this.show = true,
  });

  /// games.id / meetups.id, which is the events.id.
  final String eventId;
  final String? title;

  /// False draws nothing (the viewer is not the organiser).
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.organiserAttendance || !show) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    return DabblerActionRow(
      key: const ValueKey<String>('attendance-list-entry'),
      icon: 'task-square',
      label: l.g05_title,
      note: l.g05_entry_note,
      onTap: () => context.push(RoutePaths.attendance(eventId, title: title)),
    );
  }
}
