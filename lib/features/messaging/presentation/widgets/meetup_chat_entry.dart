import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/meetup_conversation_provider.dart';
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
/// It opens the shared thread route with the conversation id resolved from
/// the member's Messages list. While that resolves the button is loading;
/// when the member has no conversation row for this meetup (not created yet)
/// or the list failed, the button stays visible but disabled, with a
/// semantic label saying the chat is not available yet. It never guesses an
/// id. With the committed messaging flags it draws nothing.
class MeetupChatEntry extends ConsumerWidget {
  const MeetupChatEntry({
    super.key,
    required this.meetupId,
    required this.isHost,
    required this.myStatus,
  });

  final String meetupId;
  final bool isHost;
  final String? myStatus;

  static const buttonKey = ValueKey<String>('messaging-meetup-chat-entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(meetupChatEntryFlagsProvider);
    if (!meetupChatEntryVisible(flags, isHost: isHost, myStatus: myStatus)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final resolved = ref.watch(meetupConversationIdProvider(meetupId));
    final id = resolved.valueOrNull;
    final loading = resolved.isLoading;
    final unavailable = !loading && id == null;
    return DabblerButton(
      key: buttonKey,
      label: l10n.messaging_meetup_chat_open,
      semanticLabel: unavailable
          ? l10n.messaging_meetup_chat_unavailable
          : l10n.messaging_meetup_chat_semantic,
      // Text only, like the profile Message action: an icon beside the
      // label overflows the button at 200% text scale.
      tone: DabblerButtonTone.outlined,
      size: DabblerButtonSize.full,
      fullWidth: true,
      loading: loading,
      disabled: id == null,
      onPressed: id == null
          ? null
          : () => context.pushNamed(
              dmThreadRouteName,
              pathParameters: {dmThreadRouteParam: id},
            ),
    );
  }
}
