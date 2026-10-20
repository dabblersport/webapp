import 'dart:async';

import 'package:dabbler/features/messaging/data/messaging_http_client.dart';

/// Sends the signed-in user's typing state to the conversation's other
/// members (KAN-579). Ephemeral: no message row, no notification, no
/// retry. A failure is swallowed because the signal is a hint and the
/// receiver's own timeout clears a lost one.
abstract class TypingTransport {
  Future<void> send(String conversationId, bool typing);
}

/// No typing: the fake backend, a build without a base URL, Realtime off.
class NoopTypingTransport implements TypingTransport {
  const NoopTypingTransport();

  @override
  Future<void> send(String conversationId, bool typing) async {}
}

/// `POST /v1/conversations/{id}/typing {"typing": bool}` on the messaging
/// Worker (`workers/messaging/src/typing.ts`), which checks the caller may
/// send there now and asks Supabase to fan the signal out. The body is the
/// boolean only; nothing is logged.
class WorkerTypingTransport implements TypingTransport {
  WorkerTypingTransport(this._http);

  final MessagingHttpClient _http;

  @override
  Future<void> send(String conversationId, bool typing) async {
    try {
      await _http.send(
        'POST',
        '/conversations/${Uri.encodeComponent(conversationId)}/typing',
        jsonBody: <String, Object>{'typing': typing},
      );
    } catch (_) {
      // A hint, not a message: dropped on any failure.
    }
  }
}
