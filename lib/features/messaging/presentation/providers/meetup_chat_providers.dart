import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/meetup_conversation_repository.dart';
import 'package:dabbler/features/messaging/presentation/controllers/meetup_chat_controller.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';

/// Where the meetup chat's conversation comes from (KAN-928), chosen like
/// `messagingRepositoryProvider`: the fake, the Worker or unavailable.
final meetupConversationRepositoryProvider =
    Provider<MeetupConversationRepository>(
      (ref) => switch (ref.watch(messagingBackendKindProvider)) {
        MessagingBackendKind.fake => ref.watch(fakeMessagingRepositoryProvider),
        MessagingBackendKind.worker => ref.watch(
          workerMessagingRepositoryProvider,
        ),
        MessagingBackendKind.unavailable =>
          const UnavailableMessagingRepository(),
      },
    );

/// The chat of one meetup, keyed by meetup id.
final meetupChatControllerProvider =
    AsyncNotifierProvider.family<
      MeetupChatController,
      GameChatViewState,
      String
    >(MeetupChatController.new);
