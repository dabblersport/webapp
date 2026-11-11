// KAN-897: the profile, preferences and privacy-settings collectors keep the
// exact output keys and failure behaviour of the DataExportService methods
// they were copied from. A real SupabaseClient runs over a fake HTTP client.
import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/services/export/profile_settings_collectors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef _Handler = Future<http.Response> Function(http.Request request);

// postgrest reads `response.request`, so every fake response carries it.
SupabaseClient _client(_Handler handler) => SupabaseClient(
  'http://localhost',
  'anon-key',
  httpClient: MockClient((r) async {
    final res = await handler(r);
    return http.Response(
      res.body,
      res.statusCode,
      headers: res.headers,
      request: r,
    );
  }),
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

String _table(http.Request r) => r.url.pathSegments.last;

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _missingTable() => _json({
  'code': 'PGRST205',
  'message': "Could not find the table 'public.user_preferences'",
  'details': null,
  'hint': null,
}, 404);

void main() {
  const userId = 'u-1';

  group('collectProfile', () {
    test('one row -> row columns plus the original metadata keys', () async {
      String? table;
      final client = _client((r) async {
        table = _table(r);
        return _json({'id': 'p-1', 'user_id': userId});
      });

      final result = await collectProfile(client, userId);

      expect(table, SupabaseConfig.usersTable);
      expect(result!.keys.toSet(), {
        'id',
        'user_id',
        'data_source',
        'purpose',
        'legal_basis',
        'retention_period',
      });
      expect(result['data_source'], 'profiles_table');
    });

    test('client throws -> null, no throw', () async {
      final client = _client((_) async => throw http.ClientException('down'));
      expect(await collectProfile(client, userId), isNull);
    });
  });

  group('collectPreferences', () {
    test('one row each -> the original key set', () async {
      final tables = <String>[];
      final client = _client((r) async {
        tables.add(_table(r));
        return _json([
          {'user_id': userId, 'k': 'v'},
        ]);
      });

      final result = await collectPreferences(client, userId);

      expect(tables, [
        SupabaseConfig.userSettingsTable,
        SupabaseConfig.userPreferencesTable,
      ]);
      expect(result!.keys.toSet(), {
        'settings',
        'preferences',
        'data_source',
        'purpose',
        'legal_basis',
        'retention_period',
      });
      expect(result['settings'], hasLength(1));
      expect(result['preferences'], hasLength(1));
      expect(result['data_source'], 'user_settings, user_preferences tables');
    });

    test('user_preferences missing -> settings-only map', () async {
      final client = _client((r) async {
        if (_table(r) == SupabaseConfig.userPreferencesTable) {
          return _missingTable();
        }
        return _json([
          {'user_id': userId},
        ]);
      });

      final result = await collectPreferences(client, userId);

      expect(result!.keys.toSet(), {
        'settings',
        'preferences',
        'data_source',
        'purpose',
        'legal_basis',
        'retention_period',
      });
      expect(result['settings'], hasLength(1));
      expect(result['preferences'], isEmpty);
      expect(result['data_source'], 'user_settings table');
    });

    test('user_preferences fails for another reason -> null', () async {
      final client = _client((r) async {
        if (_table(r) == SupabaseConfig.userPreferencesTable) {
          return _json({'code': '42501', 'message': 'permission denied'}, 403);
        }
        return _json([]);
      });
      expect(await collectPreferences(client, userId), isNull);
    });

    test('client throws -> null, no throw', () async {
      final client = _client((_) async => throw http.ClientException('down'));
      expect(await collectPreferences(client, userId), isNull);
    });
  });

  group('collectPrivacySettings', () {
    test('one row -> row columns plus the original metadata keys', () async {
      String? table;
      final client = _client((r) async {
        table = _table(r);
        return _json({'user_id': userId, 'profile_visibility': 'public'});
      });

      final result = await collectPrivacySettings(client, userId);

      expect(table, SupabaseConfig.privacySettingsTable);
      expect(result!.keys.toSet(), {
        'user_id',
        'profile_visibility',
        'data_source',
        'purpose',
        'legal_basis',
        'your_rights',
      });
    });

    test('client throws -> null, no throw', () async {
      final client = _client((_) async => throw http.ClientException('down'));
      expect(await collectPrivacySettings(client, userId), isNull);
    });
  });
}
