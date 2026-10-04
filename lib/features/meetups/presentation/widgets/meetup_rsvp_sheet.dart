import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// The RSVP sheet, "Are you going to this meetup?" (`Details.dc.html:322-352`):
/// three answers as [DabblerActionRow]s — the chosen one filled — and a Confirm
/// button. Resolves to the chosen [RsvpAction], or null when dismissed.
Future<RsvpAction?> showMeetupRsvpSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  RsvpAction? current,
}) {
  final l = AppLocalizations.of(context);
  return showDabblerSheet<RsvpAction>(
    context: context,
    detent: DabblerSheetDetent.content,
    titleWidget: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DabblerText(title, style: DabblerType.title3),
        DabblerText(
          subtitle,
          style: DabblerType.caption1,
          tone: DabblerTextTone.secondary,
        ),
      ],
    ),
    title: title,
    showCloseButton: false,
    headerActionBuilder: (ctx) => DabblerButton(
      label: l.meetups_sheet_cancel,
      size: DabblerButtonSize.small,
      tone: DabblerButtonTone.neutral,
      onPressed: () => Navigator.of(ctx).pop(),
    ),
    headerDivider: true,
    builder: (ctx) => _RsvpSheetBody(initial: current),
  );
}

class _RsvpSheetBody extends StatefulWidget {
  const _RsvpSheetBody({required this.initial});

  final RsvpAction? initial;

  @override
  State<_RsvpSheetBody> createState() => _RsvpSheetBodyState();
}

class _RsvpSheetBodyState extends State<_RsvpSheetBody> {
  late RsvpAction? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget row(RsvpAction a, String icon, String label) => DabblerActionRow(
      icon: icon,
      label: label,
      selected: _picked == a,
      onTap: () => setState(() => _picked = a),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DabblerSpacing.space3,
      children: <Widget>[
        row(RsvpAction.going, 'tick-circle', l.meetups_sheet_yes),
        row(RsvpAction.interested, 'clock', l.meetups_sheet_maybe),
        row(RsvpAction.cancel, 'close-circle', l.meetups_sheet_no),
        DabblerButton(
          label: l.meetups_sheet_confirm,
          fullWidth: true,
          disabled: _picked == null,
          onPressed: () => Navigator.of(context).pop(_picked),
        ),
      ],
    );
  }
}
