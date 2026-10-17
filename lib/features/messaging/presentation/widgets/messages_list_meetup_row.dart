import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// One meetup-chat row of the Messages list (KAN-559): a
/// [DabblerConversationRow] of kind `squad`, whose kind tile carries the
/// `people` glyph the meetups feature uses as its mark (the DS has no meetup
/// kind — reported as a design question).
///
/// It shows the meetup title, a quiet kind label with the start date and
/// time, the relative last-activity time and the state as a neutral
/// [DabblerConversationState] badge. Never a preview, sender or unread mark.
class MessagesListMeetupRow extends StatelessWidget {
  const MessagesListMeetupRow({
    super.key,
    required this.title,
    required this.seed,
    required this.timestamp,
    required this.kindLabel,
    required this.stateLabel,
    this.divider = true,
    this.onTap,
  });

  final String title;

  /// Seed of the kind tile (the conversation id).
  final String seed;
  final String timestamp;

  /// "Meetup · " plus the start date and time, or "Meetup" when the start is unknown.
  final String kindLabel;

  /// The state badge (open, read-only, left).
  final String stateLabel;
  final bool divider;
  final VoidCallback? onTap;

  /// The accessible name: title, time, state, kind label.
  String composedLabel() => [
    title,
    if (timestamp.isNotEmpty) timestamp,
    stateLabel,
    kindLabel,
  ].join(', ');

  @override
  Widget build(BuildContext context) => DabblerConversationRow(
    kind: DabblerConversationKind.squad,
    seed: seed,
    title: title,
    timestamp: timestamp,
    kindLabel: kindLabel,
    state: DabblerConversationState(label: stateLabel),
    divider: divider,
    onTap: onTap,
    semanticLabel: composedLabel(),
  );
}
