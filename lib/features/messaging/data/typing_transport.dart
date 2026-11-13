import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

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

  /// Set when the Worker answers that the route does not exist (404), is not
  /// allowed (405) or is not implemented (501): a Worker deployed before
  /// KAN-579. The user's typing is then not sent again until the app restarts,
  /// so a backend without the feature costs one request, not one every 3 s.
  bool _unsupported = false;

  @visibleForTesting
  bool get unsupported => _unsupported;

  @override
  Future<void> send(String conversationId, bool typing) async {
    if (_unsupported) return;
    try {
      final response = await _http.send(
        'POST',
        '/conversations/${Uri.encodeComponent(conversationId)}/typing',
        jsonBody: <String, Object>{'typing': typing},
      );
      if (response.status == 404 ||
          response.status == 405 ||
          response.status == 501) {
        _unsupported = true;
      }
    } catch (_) {
      // A hint, not a message: dropped on any failure.
    }
  }
}
