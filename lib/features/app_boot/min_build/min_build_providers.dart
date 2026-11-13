import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'min_build_repository.dart';

/// KAN-926: what the launch gate decided.
@immutable
class MinBuildStatus {
  const MinBuildStatus({required this.blocked, this.storeUrl, this.platform});

  /// Not blocked: the answer for every uncertainty.
  static const MinBuildStatus open = MinBuildStatus(blocked: false);

  final bool blocked;
  final String? storeUrl;

  /// 'web', 'ios' or 'android'; null when the platform is not gated.
  final String? platform;

  bool get isWeb => platform == 'web';
}

/// The `app_min_versions.platform` key for this client: 'web' on the web,
/// 'ios' / 'android' on those, null (no gate) anywhere else.
String? minBuildPlatformKey({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return 'web';
  return switch (platform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => null,
  };
}

/// The decision, pure. Blocked only when both numbers are known and the
/// running build is strictly below the minimum. A fetch error, a missing row,
/// a null minimum or an unknown build are all "not blocked" (fail open).
MinBuildStatus decideMinBuild({
  required String? platform,
  required int? currentBuild,
  required Result<MinBuildRequirement?, Failure> fetched,
}) {
  if (platform == null || currentBuild == null) return MinBuildStatus.open;
  final req = fetched.fold<MinBuildRequirement?>((_) => null, (r) => r);
  final min = req?.minBuild;
  if (min == null || currentBuild >= min) return MinBuildStatus.open;
  return MinBuildStatus(
    blocked: true,
    storeUrl: req?.storeUrl,
    platform: platform,
  );
}

final minBuildRepositoryProvider = Provider<MinBuildRepository>((ref) {
  return SupabaseMinBuildRepository(ref.watch(supabaseClientProvider));
});

final minBuildPlatformProvider = Provider<String?>((ref) {
  return minBuildPlatformKey(isWeb: kIsWeb, platform: defaultTargetPlatform);
});

/// The running build: the `+N` of pubspec's `version`, as the platform reports
/// it (CFBundleVersion / versionCode natively, `version.json` on the web).
/// Null when it cannot be read.
final currentAppBuildProvider = FutureProvider<int?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform().timeout(
      DabblerMotion.timeoutShort,
    );
    return int.tryParse(info.buildNumber.trim());
  } catch (_) {
    return null;
  }
});

/// The launch gate. Never fails and never hangs past the short timeouts of
/// its two reads; any surprise resolves to [MinBuildStatus.open].
final minBuildStatusProvider = FutureProvider<MinBuildStatus>((ref) async {
  try {
    final platform = ref.watch(minBuildPlatformProvider);
    if (platform == null) return MinBuildStatus.open;
    final build = await ref.watch(currentAppBuildProvider.future);
    if (build == null) return MinBuildStatus.open;
    final fetched = await ref.watch(minBuildRepositoryProvider).fetch(platform);
    return decideMinBuild(
      platform: platform,
      currentBuild: build,
      fetched: fetched,
    );
  } catch (_) {
    return MinBuildStatus.open;
  }
});
