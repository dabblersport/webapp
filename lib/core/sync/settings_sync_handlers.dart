import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/theme_service.dart';
import 'package:dabbler/core/sync/pending_settings_store.dart';

/// Setting keys of the offline queue (KAN-608).
abstract class SettingKeys {
  static const String notifications = 'notifications';
  static const String privacy = 'privacy';
  static const String theme = 'theme';
  static const String language = 'language';
  static const String region = 'region';
}

/// How one queued setting talks to the server (KAN-608).
abstract class SettingSyncHandler {
  /// The server row's `updated_at` for [accountId], or null when there is no
  /// row yet or the setting has no per-setting server timestamp (then the
  /// queued edit is sent without a comparison).
  Future<DateTime?> serverUpdatedAt(String accountId);

  /// Sends [edit]. Throws when the server did not take it.
  Future<void> push(String accountId, PendingSettingEdit edit);

  /// The server's value is newer than the local edit: take it as the local one.
  Future<void> adoptServer(String accountId);
}

/// Where the mirrors of server-backed settings are kept for offline reads.
String settingsMirrorKey(String key) => 'settings.$key';

abstract class _RowHandler implements SettingSyncHandler {
  _RowHandler(this._client);

  final SupabaseClient Function() _client;

  String get table;

  @override
  Future<DateTime?> serverUpdatedAt(String accountId) async {
    final row = await _client()
        .from(table)
        .select('updated_at')
        .eq('user_id', accountId)
        .maybeSingle();
    final raw = row?['updated_at'];
    return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  }
}

/// `notification_settings`: one row per account, written whole.
class NotificationsSyncHandler extends _RowHandler {
  NotificationsSyncHandler(super.client);

  @override
  String get table => SupabaseConfig.notificationSettingsTable;

  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async {
    final v = edit.value;
    await _client().from(table).upsert({
      'user_id': accountId,
      'tz': v['tz'],
      'quiet_start_min': v['quiet_start_min'],
      'quiet_end_min': v['quiet_end_min'],
      'push_enabled': v['push_enabled'],
      'email_enabled': v['email_enabled'],
      'sms_enabled': v['sms_enabled'],
      'muted_kinds': v['muted_kinds'],
      'allow_high_priority_override': v['allow_high_priority_override'],
      'allow_all_override': v['allow_all_override'],
      // The edit's own time, so the later edit wins whichever device syncs
      // first.
      'updated_at': edit.editedAt.toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  @override
  Future<void> adoptServer(String accountId) async {
    final row = await _client()
        .from(table)
        .select()
        .eq('user_id', accountId)
        .maybeSingle();
    if (row != null) {
      await OfflineCache.instance.write(
        accountId,
        settingsMirrorKey(SettingKeys.notifications),
        row,
      );
    }
  }
}

/// `privacy_settings`: one row per account, written whole.
class PrivacySyncHandler extends _RowHandler {
  PrivacySyncHandler(super.client);

  @override
  String get table => SupabaseConfig.privacySettingsTable;

  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async {
    await _client().from(table).upsert({
      ...edit.value,
      'user_id': accountId,
      'updated_at': edit.editedAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> adoptServer(String accountId) async {
    final row = await _client()
        .from(table)
        .select()
        .eq('user_id', accountId)
        .maybeSingle();
    if (row != null) {
      await OfflineCache.instance.write(
        accountId,
        settingsMirrorKey(SettingKeys.privacy),
        row,
      );
    }
  }
}

/// `user_settings` theme columns.
class ThemeSyncHandler extends _RowHandler {
  ThemeSyncHandler(super.client);

  @override
  String get table => SupabaseConfig.userSettingsTable;

  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async {
    final payload = {
      ...edit.value,
      'updated_at': edit.editedAt.toUtc().toIso8601String(),
    };
    final existing = await _client()
        .from(table)
        .select('user_id')
        .eq('user_id', accountId)
        .maybeSingle();
    if (existing != null) {
      await _client().from(table).update(payload).eq('user_id', accountId);
      return;
    }
    await _client().from(table).insert({'user_id': accountId, ...payload});
  }

  @override
  Future<void> adoptServer(String accountId) =>
      ThemeService().hydrateFromAccount();
}

/// The profile language (`users.language`). The `users` row has one
/// `updated_at` for every profile edit, so there is no per-setting server
/// timestamp: the edit is sent without a comparison (a backend ticket is
/// needed for a comparable timestamp).
class LanguageSyncHandler implements SettingSyncHandler {
  LanguageSyncHandler(this._client);

  final SupabaseClient Function() _client;

  @override
  Future<DateTime?> serverUpdatedAt(String accountId) async => null;

  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async {
    await _client()
        .from(SupabaseConfig.usersTable)
        .update({'language': edit.value['language']})
        .eq('id', edit.value['profile_id'] as String);
  }

  @override
  Future<void> adoptServer(String accountId) async {}
}

/// `account_service_region` (KAN-584).
class RegionSyncHandler extends _RowHandler {
  RegionSyncHandler(super.client);

  @override
  String get table => 'account_service_region';

  @override
  Future<void> push(String accountId, PendingSettingEdit edit) async {
    await _client().from(table).upsert({
      'user_id': accountId,
      'region': edit.value['region'],
      'updated_at': edit.editedAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> adoptServer(String accountId) async {
    final row = await _client()
        .from(table)
        .select('region')
        .eq('user_id', accountId)
        .maybeSingle();
    final region = row?['region'];
    if (region is String) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_country.$accountId', region);
    }
  }
}

/// The handlers the app runs with, against the live Supabase client.
Map<String, SettingSyncHandler> defaultSettingSyncHandlers() {
  SupabaseClient client() => Supabase.instance.client;
  return {
    SettingKeys.notifications: NotificationsSyncHandler(client),
    SettingKeys.privacy: PrivacySyncHandler(client),
    SettingKeys.theme: ThemeSyncHandler(client),
    SettingKeys.language: LanguageSyncHandler(client),
    SettingKeys.region: RegionSyncHandler(client),
  };
}
