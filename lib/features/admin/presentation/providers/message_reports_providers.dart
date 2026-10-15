import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/message_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message_report.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';

/// The two flags the admin Reports surfaces read (the entry row and the
/// route). Defaults to the real compile-time flags (false in committed code);
/// a test overrides the provider instead of flipping a const.
typedef MessageReportsFlags = ({bool messaging, bool reporting});

final messageReportsFlagsProvider = Provider<MessageReportsFlags>(
  (ref) => (
    messaging: FeatureFlags.messaging,
    reporting: FeatureFlags.enableMessagingReporting,
  ),
);

/// Whether the Reports screen and its entry row may exist at all (the user
/// must also be an admin).
bool messageReportsEnabled(MessageReportsFlags flags) =>
    flags.messaging && flags.reporting;

/// The repository behind the Reports screen: the real Worker + RPC when both
/// flags are on and a base URL is configured, the fake otherwise (flag-off
/// builds and tests).
final messageReportsRepositoryProvider = Provider<MessageReportsRepository>((
  ref,
) {
  final flags = ref.watch(messageReportsFlagsProvider);
  if (!messageReportsEnabled(flags)) {
    return ref.watch(fakeMessagingRepositoryProvider);
  }
  final baseUrl = ref.watch(messagingBackendConfigProvider).baseUrl;
  return baseUrl.trim().isEmpty
      ? const UnavailableMessagingRepository()
      : ref.watch(workerMessagingRepositoryProvider);
});

/// The message reports, newest first. The value is the `Result` itself, so a
/// failure is data. Loads on open and on Retry (invalidate); no polling.
final messageReportsProvider =
    FutureProvider.autoDispose<Result<List<MessageReport>, Failure>>(
      (ref) => ref.watch(messageReportsRepositoryProvider).listMessageReports(),
    );
