import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/constants/timing/export_timing.dart';

/// PDPL/GDPR export collectors for login history and linked sign-in
/// identities (KAN-890). Copied verbatim in behaviour from
/// `DataExportService._getLoginHistory` and `_getThirdPartyData`; each
/// returns `null` on failure and never throws.

void _warning(String message, [dynamic error]) =>
    debugPrint('[WARNING] $message${error != null ? ': $error' : ''}');

Future<List<Map<String, dynamic>>?> collectLoginHistory(
  SupabaseClient client,
  String userId,
) async {
  try {
    // Reconciled (KAN-103): `login_history` never existed as a public
    // table. Real login events live in Supabase's own
    // `auth.audit_log_entries`, which isn't directly client-readable
    // (PostgREST doesn't expose `auth`, and anon/authenticated have no
    // grants on it). This calls the `get_my_login_history` SECURITY
    // DEFINER wrapper instead, which filters strictly to auth.uid() so
    // only the caller's own login events ever come back - same pattern
    // as `can_view_venue_bookings`.
    final sixMonthsAgo = DateTime.now().subtract(
      ExportTiming.loginHistoryExportWindow,
    );
    final response = await client.rpc(
      SupabaseConfig.getMyLoginHistoryFn,
      params: {'p_since': sixMonthsAgo.toIso8601String(), 'p_limit': 1000},
    );

    return (response as List)
        .map<Map<String, dynamic>>(
          (item) => {
            ...(item as Map<String, dynamic>),
            'data_source': 'auth.audit_log_entries (via get_my_login_history)',
            'purpose': 'Security monitoring and fraud prevention',
            'legal_basis': 'Legitimate interest (security)',
            'retention_period': '6 months',
          },
        )
        .toList();
  } catch (e) {
    _warning('Could not fetch login history', e);
    return null;
  }
}

Future<List<Map<String, dynamic>>?> collectLinkedIdentities(
  SupabaseClient client,
  String userId,
) async {
  try {
    // Reconciled (KAN-103): `third_party_connections` never existed as a
    // public table. The real record of which third-party sign-in
    // providers are linked to this account (e.g. Google Sign-In) lives
    // in Supabase's own `auth.identities`, which isn't directly
    // client-readable. This calls the `get_my_linked_identities`
    // SECURITY DEFINER wrapper instead, filtered strictly to auth.uid()
    // - same pattern as `get_my_login_history` /
    // `can_view_venue_bookings`. Only connection metadata comes back;
    // OAuth tokens and provider profile payloads are never exposed.
    final response = await client.rpc(SupabaseConfig.getMyLinkedIdentitiesFn);

    return (response as List)
        .map<Map<String, dynamic>>(
          (item) => {
            ...(item as Map<String, dynamic>),
            'data_source': 'auth.identities (via get_my_linked_identities)',
            'purpose': 'Sign-in method management and account security',
            'legal_basis': 'User consent',
            'note': 'Third-party data is not stored - only connection metadata',
          },
        )
        .toList();
  } catch (e) {
    _warning('Could not fetch third-party data', e);
    return null;
  }
}
