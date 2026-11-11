// KAN-897 (Epic KAN-889, PDPL data export): profile, preferences and privacy
// settings collectors, copied as top-level functions from the private
// `_getEnhancedProfileData`, `_getEnhancedPreferencesData` and
// `_getPrivacySettingsData` methods of `DataExportService`. Same queries, same
// output keys, same logging; every failed read returns null and never throws.
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/services/data_export_service.dart'
    show Logger;
import 'package:supabase_flutter/supabase_flutter.dart';

const String _logTag = 'DataExportService';

/// The `profiles` row for [userId] plus its PDPL processing metadata.
Future<Map<String, dynamic>?> collectProfile(
  SupabaseClient client,
  String userId,
) async {
  try {
    final response = await client
        .from(SupabaseConfig.usersTable) // 'profiles' table
        .select('*')
        .eq('user_id', userId) // Match by user_id FK
        .single();

    return {
      ...response,
      'data_source': 'profiles_table',
      'purpose': 'User identification and profile management',
      'legal_basis': 'Contract performance and legitimate interest',
      'retention_period': '2 years after account deletion',
    };
  } catch (e) {
    Logger.warning('Could not fetch enhanced profile data', e);
    return null;
  }
}

/// The `user_settings` and `user_preferences` rows for [userId]. When the
/// `user_preferences` table is missing, returns the settings-only map.
Future<Map<String, dynamic>?> collectPreferences(
  SupabaseClient client,
  String userId,
) async {
  try {
    final settingsResponse = await client
        .from(SupabaseConfig.userSettingsTable)
        .select()
        .eq('user_id', userId);

    final preferencesResponse = await client
        .from(SupabaseConfig.userPreferencesTable)
        .select()
        .eq('user_id', userId);

    return {
      'settings': settingsResponse,
      'preferences': preferencesResponse,
      'data_source': 'user_settings, user_preferences tables',
      'purpose': 'Personalization and user experience optimization',
      'legal_basis': 'User consent and legitimate interest',
      'retention_period': 'Until account deletion or consent withdrawal',
    };
  } catch (e) {
    if (_isMissingTableError(e, 'public.user_preferences')) {
      Logger.info(
        '$_logTag: user_preferences table missing; exporting settings only',
      );

      try {
        final settingsResponse = await client
            .from(SupabaseConfig.userSettingsTable)
            .select()
            .eq('user_id', userId);

        return {
          'settings': settingsResponse,
          'preferences': const [],
          'data_source': 'user_settings table',
          'purpose': 'Personalization and user experience optimization',
          'legal_basis': 'User consent and legitimate interest',
          'retention_period': 'Until account deletion or consent withdrawal',
        };
      } catch (settingsError) {
        Logger.warning('Could not fetch settings data', settingsError);
        return null;
      }
    }

    Logger.warning('Could not fetch preferences data', e);
    return null;
  }
}

/// The `privacy_settings` row for [userId] plus its PDPL processing metadata.
Future<Map<String, dynamic>?> collectPrivacySettings(
  SupabaseClient client,
  String userId,
) async {
  try {
    final response = await client
        .from(SupabaseConfig.privacySettingsTable)
        .select()
        .eq('user_id', userId)
        .single();

    return {
      ...response,
      'data_source': 'privacy_settings table',
      'purpose': 'Privacy preference management',
      'legal_basis': 'User consent',
      'your_rights': 'You can modify these settings at any time',
    };
  } catch (e) {
    Logger.warning('Could not fetch privacy settings', e);
    return null;
  }
}

/// Copy of `DataExportService._isMissingTableError`.
bool _isMissingTableError(Object error, String tableName) {
  if (error is! PostgrestException) {
    return false;
  }

  final lowerMessage = error.message.toLowerCase();
  final normalizedName = tableName.replaceFirst('public.', '').toLowerCase();

  return error.code == 'PGRST205' ||
      lowerMessage.contains("could not find the table '$tableName'") ||
      lowerMessage.contains("could not find the table '$normalizedName'");
}
