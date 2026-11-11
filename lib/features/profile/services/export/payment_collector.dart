import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/services/data_export_service.dart'
    show Logger;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Collects the payment section of a GDPR data export (KAN-896).
///
/// Extracted verbatim from `DataExportService._getPaymentData`. Read-only:
/// it reads the user's own `payment_intents` rows and writes nothing. This
/// is the personal payment-attempt record, not the organiser/settlement
/// views (financial_ledger, wallet_ledger).
///
/// A failed read is logged and returns `null`; this never throws.
Future<Map<String, dynamic>?> collectPaymentData(
  SupabaseClient client,
  String userId,
) async {
  try {
    final response = await client
        .from(SupabaseConfig.paymentIntentsTable)
        .select('booking_id, amount, currency, provider, status')
        .eq('user_id', userId);

    return {
      'transactions': response,
      'data_source': 'payment_intents table',
      'purpose': 'Billing and subscription management',
      'legal_basis': 'Contract performance and legal obligation',
      'note':
          'Sensitive payment details (card numbers) are not stored or exported',
      'retention_period': '7 years for tax compliance',
    };
  } catch (e) {
    Logger.warning('Could not fetch payment data', e);
    return null;
  }
}
