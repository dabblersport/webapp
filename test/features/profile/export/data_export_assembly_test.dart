// KAN-898 (Epic KAN-889): the export assembled by DataExportService from its
// collectors. Drives the real service and the real collectors over a fake
// HTTP client, and checks the export JSON keeps every category key and the
// same null-on-failure handling it had before the collectors were wired in.
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/services/data_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_test_client.dart';

/// Every top-level key of `UserExportData.toJson()` before KAN-898, read off
/// the code before the change.
const _categoryKeys = {
  'export_metadata',
  'profile',
  'preferences',
  'sports_profiles',
  'statistics',
  'game_history',
  'privacy_settings',
  'consents',
  'audit_logs',
  'login_history',
  'connections',
  'notifications',
  'media',
  'location_data',
  'device_info',
  'payment_data',
  'integrations',
};

/// The fourteen categories that now come from a collector (KAN-890..897).
const _collectorKeys = {
  'profile',
  'preferences',
  'sports_profiles',
  'statistics',
  'game_history',
  'privacy_settings',
  'consents',
  'audit_logs',
  'login_history',
  'connections',
  'media',
  'location_data',
  'payment_data',
  'integrations',
};

/// Answers every export read with one row. `.single()`/`.maybeSingle()`
/// reads (object Accept header) get an object; everything else a list. A
/// request whose path ends in [failPath] gets a PostgREST 500.
Future<http.Response> Function(http.Request) _handler({String? failPath}) {
  return (request) async {
    final p = request.url.path;
    if (failPath != null && p.endsWith('/$failPath')) {
      return postgrestErrorResponse(
        message: 'boom',
        status: 500,
        request: request,
      );
    }
    if ((request.headers['Accept'] ?? '').contains('vnd.pgrst.object')) {
      return jsonObjectResponse({
        'id': 'p1',
        'user_id': 'u1',
      }, request: request);
    }
    if (p.endsWith('/rpc/export_own_game_history')) {
      return jsonListResponse([
        {
          'id': 'g1',
          'event_type': 'game',
          'my_roster': {'status': 'joined'},
        },
      ], request: request);
    }
    return jsonListResponse([
      {'id': 'r1'},
    ], request: request);
  };
}

Future<Map<String, dynamic>> _export({String? failPath}) async {
  final service = DataExportService(
    supabase: buildTestSupabaseClient(_handler(failPath: failPath)),
  );
  final data = await service.gatherExportDataForTesting('u1');
  return data.toJson();
}

void main() {
  test('the export carries every category key it had before KAN-898, and '
      'each collector category is filled', () async {
    final json = await _export();

    expect(json.keys.toSet(), _categoryKeys);
    for (final key in _collectorKeys) {
      expect(json[key], isNotNull, reason: key);
    }
    // Notifications and device tokens stay on the service's own methods.
    expect(json['notifications'], isNotNull);
    expect(json['device_info'], isNotNull);
    expect(
      (json['payment_data'] as Map)['data_source'],
      'payment_intents table',
    );
    expect((json['game_history'] as List).single['game_roster'], [
      {'status': 'joined'},
    ]);
    expect((json['export_metadata'] as Map)['total_data_categories'], 16);
  });

  test('a collector that returns null leaves its key present as null and '
      'every other category intact', () async {
    final json = await _export(failPath: SupabaseConfig.paymentIntentsTable);

    expect(json.keys.toSet(), _categoryKeys);
    expect(json.containsKey('payment_data'), isTrue);
    expect(json['payment_data'], isNull);
    for (final key in {..._collectorKeys}..remove('payment_data')) {
      expect(json[key], isNotNull, reason: key);
    }
    expect(json['notifications'], isNotNull);
    expect(json['device_info'], isNotNull);
    expect((json['export_metadata'] as Map)['total_data_categories'], 15);
  });
}
