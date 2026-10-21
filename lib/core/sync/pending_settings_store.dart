import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One setting edit made on this device that the server has not accepted yet
/// (KAN-608). Only the setting's value is stored: no tokens, no secrets.
class PendingSettingEdit {
  const PendingSettingEdit({
    required this.key,
    required this.value,
    required this.editedAt,
    this.attempts = 0,
    this.lastAttemptAt,
  });

  /// Which setting: `notifications`, `privacy`, `theme`, `language`, `region`.
  final String key;

  /// The JSON value the handler for [key] pushes.
  final Map<String, dynamic> value;

  /// When the user made the edit (UTC, device clock): the last-write-wins stamp.
  final DateTime editedAt;

  /// Failed attempts so far, for the bounded backoff.
  final int attempts;
  final DateTime? lastAttemptAt;

  PendingSettingEdit failedAt(DateTime at) => PendingSettingEdit(
    key: key,
    value: value,
    editedAt: editedAt,
    attempts: attempts + 1,
    lastAttemptAt: at,
  );

  Map<String, dynamic> toJson() => {
    'k': key,
    'v': value,
    't': editedAt.millisecondsSinceEpoch,
    'a': attempts,
    'l': lastAttemptAt?.millisecondsSinceEpoch,
  };

  static PendingSettingEdit fromJson(Map<String, dynamic> j) =>
      PendingSettingEdit(
        key: j['k'] as String,
        value: Map<String, dynamic>.from(j['v'] as Map),
        editedAt: DateTime.fromMillisecondsSinceEpoch(
          j['t'] as int,
          isUtc: true,
        ),
        attempts: j['a'] as int? ?? 0,
        lastAttemptAt: j['l'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['l'] as int, isUtc: true),
      );
}

/// The pending queue, on the device, per account (KAN-608).
///
/// One entry per setting: a newer edit of the same setting replaces the older
/// one (duplicates collapse to the latest value). It survives an app restart
/// and is removed on sign-out and on an account switch.
class PendingSettingsStore {
  const PendingSettingsStore();

  static const String _root = 'settings_sync.v1.';

  Future<Map<String, PendingSettingEdit>> load(String accountId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        '$_root$accountId',
      );
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          e.key: PendingSettingEdit.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(
    String accountId,
    Map<String, PendingSettingEdit> edits,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (edits.isEmpty) {
      await prefs.remove('$_root$accountId');
      return;
    }
    await prefs.setString(
      '$_root$accountId',
      jsonEncode({for (final e in edits.entries) e.key: e.value.toJson()}),
    );
  }

  /// Stores [edit], replacing any older edit of the same setting.
  Future<void> put(String accountId, PendingSettingEdit edit) async {
    final edits = await load(accountId);
    final current = edits[edit.key];
    if (current != null && current.editedAt.isAfter(edit.editedAt)) return;
    edits[edit.key] = edit;
    await _save(accountId, edits);
  }

  /// Removes the edit of [key], but only while it is still the one stamped
  /// [editedAt]: an edit made while it was being sent stays queued.
  Future<void> remove(
    String accountId,
    String key, {
    DateTime? ifEditedAt,
  }) async {
    final edits = await load(accountId);
    final current = edits[key];
    if (current == null) return;
    if (ifEditedAt != null && current.editedAt != ifEditedAt) return;
    edits.remove(key);
    await _save(accountId, edits);
  }

  /// Records a failed attempt on the edit stamped [editedAt].
  Future<void> markFailed(
    String accountId,
    String key,
    DateTime editedAt,
    DateTime at,
  ) async {
    final edits = await load(accountId);
    final current = edits[key];
    if (current == null || current.editedAt != editedAt) return;
    edits[key] = current.failedAt(at);
    await _save(accountId, edits);
  }

  /// Removes every account's queue except [keepAccountId]'s (the account-switch
  /// discard); with no account, everything (sign-out).
  Future<void> wipe({String? keepAccountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final keep = keepAccountId == null ? null : '$_root$keepAccountId';
    for (final k in prefs.getKeys().toList()) {
      if (!k.startsWith(_root)) continue;
      if (k == keep) continue;
      await prefs.remove(k);
    }
  }
}
