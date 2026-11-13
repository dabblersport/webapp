import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// KAN-926: the server's minimum supported build for one platform, one row of
/// `public.app_min_versions`.
@immutable
class MinBuildRequirement {
  const MinBuildRequirement({required this.minBuild, this.storeUrl});

  /// Null when the row carries no usable number; a null never blocks.
  final int? minBuild;

  /// Where the "Update" button sends the user (iOS/Android). Null hides it.
  final String? storeUrl;

  /// Reads a row tolerantly: anything unexpected becomes a null field, which
  /// the gate treats as "not blocked". Null [row] (no row) is null.
  static MinBuildRequirement? fromRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final raw = row['min_build'];
    final int? minBuild = switch (raw) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    final url = row['store_url'];
    final storeUrl = url is String && url.trim().isNotEmpty ? url.trim() : null;
    return MinBuildRequirement(minBuild: minBuild, storeUrl: storeUrl);
  }
}

/// Reads the minimum supported build for a platform key ('web', 'ios',
/// 'android'). `Ok(null)` means the platform has no row.
abstract class MinBuildRepository {
  Future<Result<MinBuildRequirement?, Failure>> fetch(String platform);
}

class SupabaseMinBuildRepository implements MinBuildRepository {
  SupabaseMinBuildRepository(this._client, {Duration? timeout})
    : _timeout = timeout ?? DabblerMotion.timeoutShort;

  final SupabaseClient _client;

  /// Kept short: the launch waits on this, and a slow answer is no answer.
  final Duration _timeout;

  @override
  Future<Result<MinBuildRequirement?, Failure>> fetch(String platform) {
    return guardWithTimeout(() async {
      final row = await _client
          .from(SupabaseConfig.appMinVersionsTable)
          .select('min_build, store_url')
          .eq('platform', platform)
          .maybeSingle();
      return MinBuildRequirement.fromRow(row);
    }, timeout: _timeout);
  }
}
