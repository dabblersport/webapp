import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/constants/timing/export_timing.dart';

/// PDPL/GDPR export collectors for consent history and audit logs
/// (KAN-891). Copied verbatim in behaviour from
/// `DataExportService._getConsentHistory` and `_getAuditLogsData`; each
/// returns `null` on failure and never throws.

void _warning(String message, [dynamic error]) =>
    debugPrint('[WARNING] $message${error != null ? ': $error' : ''}');

Future<List<Map<String, dynamic>>?> collectConsentHistory(
  SupabaseClient client,
  String userId,
) async {
  try {
    final response = await client
        .from(SupabaseConfig.consentRecordsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response
        .map<Map<String, dynamic>>(
          (item) => {
            ...item,
            'data_source': 'consent_records table',
            'purpose': 'Legal compliance and consent tracking',
            'legal_basis': 'Legal obligation (GDPR Article 7)',
          },
        )
        .toList();
  } catch (e) {
    _warning('Could not fetch consent history', e);
    return null;
  }
}

Future<List<Map<String, dynamic>>?> collectAuditLogs(
  SupabaseClient client,
  String userId,
) async {
  try {
    final twoYearsAgo = DateTime.now().subtract(
      ExportTiming.consentAuditExportWindow,
    );
    final response = await client
        .from(SupabaseConfig.auditEventsTable)
        .select()
        .eq('actor_user_id', userId)
        .gte('created_at', twoYearsAgo.toIso8601String())
        .order('created_at', ascending: false)
        .limit(5000);

    return response
        .map<Map<String, dynamic>>(
          (item) => {
            ...item,
            'data_source': 'audit_events table',
            'purpose': 'Security monitoring and compliance',
            'legal_basis': 'Legitimate interest (security)',
            'retention_period': '2 years',
          },
        )
        .toList();
  } catch (e) {
    _warning('Could not fetch audit logs', e);
    return null;
  }
}
