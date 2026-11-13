import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns the caller's Supabase access token UNCHANGED, or null when there is
/// no session. Injectable so tests need no Supabase instance.
typedef MessagingTokenSupplier = Future<String?> Function();

/// Calls a Postgres RPC as the signed-in user and returns its decoded payload.
/// Injectable so tests need no Supabase instance.
typedef MessagingRpcCaller =
    Future<Object?> Function(String function, Map<String, dynamic> params);

/// Network cadences, not visual durations: refresh a token this close to its
/// expiry, and give up on a Worker request after this long.
const int messagingTokenRefreshMarginSeconds = 60;
const int messagingRequestTimeoutSeconds = 15;

/// An image upload may take longer than a JSON request (KAN-581).
const int messagingUploadTimeoutSeconds = 60;

/// Bytes handed to the network per progress step.
const int messagingUploadChunkBytes = 32 * 1024;

/// Thrown by [MessagingHttpClient.upload] when the caller cancelled it.
class UploadCancelledException implements Exception {
  const UploadCancelledException();
}

/// The default token supplier: the current Supabase session's access token,
/// refreshed through the Supabase client when it is expired or about to be.
/// Never a service key; never a user id.
Future<String?> supabaseAccessToken() async {
  final auth = Supabase.instance.client.auth;
  var session = auth.currentSession;
  if (session == null) return null;
  final expiresAt = session.expiresAt;
  final soon =
      DateTime.now()
          .add(const Duration(seconds: messagingTokenRefreshMarginSeconds))
          .millisecondsSinceEpoch ~/
      1000;
  if (session.isExpired || (expiresAt != null && expiresAt <= soon)) {
    final refreshed = await auth.refreshSession();
    session = refreshed.session ?? auth.currentSession;
  }
  return session?.accessToken;
}

/// The default RPC caller: the user's own Supabase session (RLS applies).
Future<Object?> supabaseRpc(String function, Map<String, dynamic> params) =>
    Supabase.instance.client.rpc(function, params: params);

/// A decoded Worker response: the status and the JSON body (null when empty).
class MessagingHttpResponse {
  const MessagingHttpResponse(this.status, this.body);
  final int status;
  final Object? body;
}

/// Thin wrapper over `package:http` for the messaging Worker
/// (`docs/messaging/openapi.yaml`). Adds the bearer token and the `/v1`
/// prefix to [baseUrl]. It may throw (network, timeout, malformed JSON); the
/// repository catches everything. It never logs request or response bodies.
class MessagingHttpClient {
  MessagingHttpClient({
    required http.Client client,
    required MessagingTokenSupplier tokenSupplier,
    required String baseUrl,
    this.timeout = const Duration(seconds: messagingRequestTimeoutSeconds),
  }) : _client = client,
       _token = tokenSupplier,
       _base = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl;

  final http.Client _client;
  final MessagingTokenSupplier _token;
  final String _base;
  final Duration timeout;

  /// The caller's current access token, or null when signed out.
  Future<String?> bearer() => _token();

  Uri uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$_base/v1$path');
    return (query == null || query.isEmpty)
        ? u
        : u.replace(queryParameters: query);
  }

  /// Streams [bytes] as the raw request body (KAN-581), reporting progress as
  /// the network takes each chunk, and stops with [UploadCancelledException]
  /// when [isCancelled] turns true. The bearer is added like any other call.
  Future<MessagingHttpResponse> upload(
    String path, {
    required Uint8List bytes,
    required String contentType,
    Map<String, String>? headers,
    void Function(int sent, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final token = await _token();
    final request = http.StreamedRequest('POST', uri(path));
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = contentType;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (headers != null) request.headers.addAll(headers);
    request.contentLength = bytes.length;
    final pending = _client.send(request);
    // A send that fails (no connection, refused) never reads the body, so
    // feeding it would wait forever. The failure ends the feed instead.
    final failed = Completer<void>();
    unawaited(failed.future.catchError((Object _) {}));
    final response = pending.then<http.StreamedResponse?>(
      (r) => r,
      onError: (Object e, StackTrace s) {
        if (!failed.isCompleted) failed.completeError(e, s);
        return null;
      },
    );
    Stream<List<int>> chunks() async* {
      var sent = 0;
      while (sent < bytes.length) {
        if (isCancelled?.call() ?? false) throw const UploadCancelledException();
        final end = math.min(sent + messagingUploadChunkBytes, bytes.length);
        yield Uint8List.sublistView(bytes, sent, end);
        sent = end;
        onProgress?.call(sent, bytes.length);
      }
    }

    try {
      await Future.any<void>([request.sink.addStream(chunks()), failed.future]);
    } on UploadCancelledException {
      await request.sink.close();
      await response;
      rethrow;
    }
    await request.sink.close();
    final streamed = await pending.timeout(
      const Duration(seconds: messagingUploadTimeoutSeconds),
    );
    final done = await http.Response.fromStream(
      streamed,
    ).timeout(const Duration(seconds: messagingUploadTimeoutSeconds));
    final text = done.body;
    return MessagingHttpResponse(
      done.statusCode,
      text.trim().isEmpty ? null : jsonDecode(text),
    );
  }

  Future<MessagingHttpResponse> send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final token = await _token();
    final request = http.Request(method, uri(path, query));
    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (headers != null) request.headers.addAll(headers);
    if (jsonBody != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(jsonBody);
    }
    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed).timeout(timeout);
    final text = response.body;
    return MessagingHttpResponse(
      response.statusCode,
      text.trim().isEmpty ? null : jsonDecode(text),
    );
  }
}
