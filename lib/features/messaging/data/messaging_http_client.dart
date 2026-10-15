import 'dart:async';
import 'dart:convert';

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

  Uri uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$_base/v1$path');
    return (query == null || query.isEmpty)
        ? u
        : u.replace(queryParameters: query);
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
