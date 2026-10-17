import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/presentation/providers/meetup_conversation_provider.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/widgets/meetup_chat_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-559: the meetup conversation id comes only from the member's list.
ProviderContainer _c(Result<List<MyConversation>, Failure> list) {
  final c = ProviderContainer(
    overrides: [messagesListProvider.overrideWith((ref) async => list)],
  );
  addTearDown(c.dispose);
  return c;
}

const _rows = <MyConversation>[
  MyConversation(
    conversationId: 'game-conv',
    gameId: 'm1',
    state: MyConversationState.send,
  ),
  MyConversation(
    conversationId: 'meet-conv',
    kind: MyConversationKind.meetup,
    meetupId: 'm1',
    state: MyConversationState.send,
  ),
];

void main() {
  test('resolves the meetup row by meetup id, not a game row', () async {
    final c = _c(const Ok(_rows));
    expect(
      await c.read(meetupConversationIdProvider('m1').future),
      'meet-conv',
    );
  });

  test('null when there is no row for the meetup', () async {
    final c = _c(const Ok(_rows));
    expect(await c.read(meetupConversationIdProvider('m9').future), isNull);
  });

  test('null when the list failed', () async {
    final c = _c(Err(Failure(message: 'x')));
    expect(await c.read(meetupConversationIdProvider('m1').future), isNull);
  });

  test('committed flags (KAN-554 launch) draw the entry for a going member', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final f = c.read(meetupChatEntryFlagsProvider);
    expect(meetupChatEntryVisible(f, isHost: true, myStatus: 'going'), isTrue);
  });
}
