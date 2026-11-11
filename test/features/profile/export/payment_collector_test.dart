import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/services/export/payment_collector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_test_client.dart';

void main() {
  final intents = <Map<String, dynamic>>[
    {
      'booking_id': 'b1',
      'amount': 100,
      'currency': 'AED',
      'provider': 'stripe',
      'status': 'succeeded',
    },
    {
      'booking_id': 'b2',
      'amount': 50,
      'currency': 'AED',
      'provider': 'stripe',
      'status': 'failed',
    },
  ];

  test(
    'C3: two intents become transactions and the key set and values equal '
    'the original _getPaymentData',
    () async {
      final seen = <http.Request>[];
      final client = buildTestSupabaseClient((r) async {
        seen.add(r);
        return jsonListResponse(intents, request: r);
      });

      final result = await collectPaymentData(client, 'u1');

      expect(result, isNotNull);
      expect(result!['transactions'], intents);
      expect(result.keys.toSet(), {
        'transactions',
        'data_source',
        'purpose',
        'legal_basis',
        'note',
        'retention_period',
      });
      expect(result['data_source'], 'payment_intents table');
      expect(result['purpose'], 'Billing and subscription management');
      expect(
        result['legal_basis'],
        'Contract performance and legal obligation',
      );
      expect(
        result['note'],
        'Sensitive payment details (card numbers) are not stored or exported',
      );
      expect(result['retention_period'], '7 years for tax compliance');

      final req = seen.single;
      expect(req.method, 'GET');
      expect(req.url.path, '/rest/v1/${SupabaseConfig.paymentIntentsTable}');
      expect(
        req.url.queryParameters['select'],
        'booking_id,amount,currency,provider,status',
      );
      expect(req.url.queryParameters['user_id'], 'eq.u1');
    },
  );

  test('C4: a failed read returns null and does not throw', () async {
    final client = buildTestSupabaseClient((r) async {
      throw http.ClientException('network down', r.url);
    });

    final result = await collectPaymentData(client, 'u1');

    expect(result, isNull);
  });
}
