import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';

/// The caller's conversation id for one meetup (KAN-559), read from their own
/// Messages list ([messagesListProvider]); no other backend call. The value
/// is null when the list failed or holds no `kind = meetup` row for
/// [meetupId] (the chat is not created yet, or the caller is not a member).
/// An id is never guessed.
final meetupConversationIdProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, meetupId) async {
      final list = await ref.watch(messagesListProvider.future);
      if (list is! Ok) return null;
      for (final c in list.requireValue) {
        if (c.isMeetup && c.meetupId == meetupId) return c.conversationId;
      }
      return null;
    });
