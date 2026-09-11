import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a real [SupabaseClient] wired to a [MockClient] so repository code
/// runs its actual HTTP-shaped request path (query building, error mapping,
/// JSON decoding) without touching the network.
///
/// [handler] receives every outgoing [http.Request] and returns the canned
/// [http.Response] to respond with.
SupabaseClient buildTestSupabaseClient(
  Future<http.Response> Function(http.Request request) handler,
) {
  final mockClient = MockClient(handler);
  return SupabaseClient(
    'https://test.supabase.co',
    'test-anon-key',
    httpClient: mockClient,
  );
}

http.Response jsonListResponse(
  List<Map<String, dynamic>> rows, {
  int status = 200,
  http.BaseRequest? request,
}) {
  return http.Response(jsonEncode(rows), status, headers: {
    'content-type': 'application/json',
  }, request: request);
}

http.Response jsonObjectResponse(
  Map<String, dynamic> row, {
  int status = 200,
  http.BaseRequest? request,
}) {
  return http.Response(jsonEncode(row), status, headers: {
    'content-type': 'application/json',
  }, request: request);
}

http.Response emptyOkResponse({int status = 204, http.BaseRequest? request}) {
  return http.Response('', status, request: request);
}

http.Response postgrestErrorResponse({
  required String message,
  String code = '400',
  int status = 400,
  http.BaseRequest? request,
}) {
  return http.Response(
    jsonEncode({'message': message, 'code': code, 'details': null, 'hint': null}),
    status,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}

/// A local (non-network) session JSON string that [GoTrueClient.setInitialSession]
/// accepts. Lets tests authenticate a [SupabaseClient] without hitting the
/// GoTrue HTTP API — the accessor is a plain in-memory session parse.
String fakeSessionJson({required String userId, String email = 'test@example.com'}) {
  final expiresAt = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  return jsonEncode({
    'access_token': 'fake-access-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': expiresAt,
    'refresh_token': 'fake-refresh-token',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'app_metadata': {},
      'user_metadata': {},
      'created_at': DateTime.now().toIso8601String(),
    },
  });
}
