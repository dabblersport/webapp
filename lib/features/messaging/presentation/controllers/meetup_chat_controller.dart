import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/chat_cache.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/presentation/controllers/game_chat_controller.dart';
import 'package:dabbler/features/messaging/presentation/providers/meetup_chat_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';

/// The chat of one meetup (KAN-928; arg: the meetup id). It IS the game chat
/// controller: send, retry, paging, polling, wakes, mute and report are
/// inherited unchanged. Only the open differs: the conversation comes from
/// `GET /v1/meetups/{id}/conversation`, which the Worker answers for the
/// organiser and 'going' members (not_a_member otherwise).
class MeetupChatController extends GameChatController {
  @override
  Future<GameChatViewState> open(String arg) async {
    final conv = await ref
        .read(meetupConversationRepositoryProvider)
        .getMeetupConversation(arg);
    if (conv is Err<Conversation, Failure>) return failureFor(conv.error);
    return openConversation(conv.requireValue);
  }

  @override
  String cacheKey(String arg) => ChatCache.meetupThreadKey(arg);
}
