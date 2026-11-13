import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/presentation/meetup_chat_route.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The flags the meetup-chat entry reads. Defaults to the real compile-time
/// flags; a test overrides the provider instead of flipping a const.
typedef MeetupChatEntryFlags = ({
  bool messaging,
  bool gameChat,
  bool reporting,
  bool meetups,
});

final meetupChatEntryFlagsProvider = Provider<MeetupChatEntryFlags>(
  (ref) => (
    messaging: FeatureFlags.messaging,
    gameChat: FeatureFlags.enableMessagingGameChat,
    reporting: FeatureFlags.enableMessagingReporting,
    meetups: FeatureFlags.enableMeetups,
  ),
);

/// Whether the entry is drawn: every flag on, the messaging flags consistent,
/// and the user a member (organiser, or RSVP `going`).
bool meetupChatEntryVisible(
  MeetupChatEntryFlags flags, {
  required bool isHost,
  required String? myStatus,
}) =>
    (isHost || myStatus == 'going') &&
    flags.meetups &&
    flags.messaging &&
    flags.gameChat &&
    flags.reporting &&
    FeatureFlags.messagingFlagsConsistent(
      flags.messaging,
      flags.gameChat,
      flags.reporting,
    );

/// The one entry to a meetup's chat (KAN-559), on the meetup detail screen.
/// KAN-928: it opens `/meetups/{id}/chat`, whose Worker route creates the
/// conversation on first open for the organiser or a 'going' member, so
/// there is no id to resolve first and the button is always enabled. With
/// the committed messaging flags it draws nothing.
class MeetupChatEntry extends ConsumerWidget {
  const MeetupChatEntry({
    super.key,
    required this.meetupId,
    required this.isHost,
    required this.myStatus,
    this.title,
  });

  final String meetupId;
  final bool isHost;
  final String? myStatus;

  /// The meetup's title, for the chat's top bar.
  final String? title;

  static const buttonKey = ValueKey<String>('messaging-meetup-chat-entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(meetupChatEntryFlagsProvider);
    if (!meetupChatEntryVisible(flags, isHost: isHost, myStatus: myStatus)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return DabblerButton(
      key: buttonKey,
      label: l10n.messaging_meetup_chat_open,
      semanticLabel: l10n.messaging_meetup_chat_semantic,
      // Text only, like the profile Message action: an icon beside the
      // label overflows the button at 200% text scale.
      tone: DabblerButtonTone.outlined,
      size: DabblerButtonSize.full,
      fullWidth: true,
      onPressed: () => context.push(meetupChatLocation(meetupId), extra: title),
    );
  }
}
