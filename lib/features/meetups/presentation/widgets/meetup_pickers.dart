import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart'
    show ComposerDateSheet, ComposerTimeSheet;
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';

/// The date step of the composers' date and time flow. Resolves to the chosen
/// day, or null when the sheet is dismissed.
Future<DateTime?> pickMeetupDate(
  BuildContext context,
  DateTime? initial,
) async {
  final l = AppLocalizations.of(context);
  final now = DateTime.now();
  final pending = ValueNotifier<DateTime?>(initial);
  DateTime? picked;
  await showComposerSheet<void>(
    context,
    title: l.composer_pick_date,
    confirm: ComposerSheetConfirm(
      label: l.composer_confirm,
      onTap: () {
        picked = pending.value;
        Navigator.of(context).maybePop();
      },
    ),
    builder: (_) => ComposerDateSheet(
      first: now,
      last: DateTime(now.year + 1, now.month, now.day),
      pending: pending,
    ),
  );
  return picked;
}

/// The time step. Resolves to the chosen time, or null when dismissed.
Future<TimeOfDay?> pickMeetupTime(
  BuildContext context,
  TimeOfDay? initial,
) async {
  final l = AppLocalizations.of(context);
  final pending = ValueNotifier<TimeOfDay>(
    initial ?? const TimeOfDay(hour: 18, minute: 0),
  );
  TimeOfDay? picked;
  await showComposerSheet<void>(
    context,
    title: l.composer_pick_time,
    confirm: ComposerSheetConfirm(
      label: l.composer_confirm,
      onTap: () {
        picked = pending.value;
        Navigator.of(context).maybePop();
      },
    ),
    builder: (_) => ComposerTimeSheet(pending: pending),
  );
  return picked;
}

/// The place sheet (search a venue or use the typed text). Resolves to the
/// pick, or null when dismissed.
Future<ComposerPlacePick?> pickMeetupPlace(
  BuildContext context,
  ComposerPlacePick? initial,
) async {
  final l = AppLocalizations.of(context);
  final pending = ValueNotifier<ComposerPlacePick?>(initial);
  ComposerPlacePick? picked;
  await showComposerSheet<void>(
    context,
    title: l.composer_add_location,
    confirm: ComposerSheetConfirm(
      label: l.composer_confirm,
      onTap: () {
        picked = pending.value;
        Navigator.of(context).maybePop();
      },
    ),
    builder: (_) => ComposerPlaceSheet(pending: pending),
  );
  return picked;
}
