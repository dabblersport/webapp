import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/fake_moderation_reports_repository.dart';
import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/report_row.dart';
import 'package:dabbler/features/messaging/domain/moderation_reports_repository.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';

/// The two flags the admin Reports screen needs (KAN-552). Defaults to the
/// real compile-time flags (false); a test overrides this provider instead of
/// flipping a const.
typedef AdminMessageReportsFlags = ({bool messaging, bool reporting});

final adminMessageReportsFlagsProvider = Provider<AdminMessageReportsFlags>(
  (ref) => (
    messaging: FeatureFlags.messaging,
    reporting: FeatureFlags.enableMessagingReporting,
  ),
);

bool adminMessageReportsEnabled(AdminMessageReportsFlags f) =>
    f.messaging && f.reporting;

/// The in-memory fake: the default for tests and flag-off builds.
final fakeModerationReportsRepositoryProvider =
    Provider<FakeModerationReportsRepository>(
      (ref) => FakeModerationReportsRepository(),
    );

/// Real Worker repository only when both flags are on AND the build has a
/// Worker base URL; flags on without one is unavailable; otherwise the fake.
final moderationReportsRepositoryProvider =
    Provider<ModerationReportsRepository>((ref) {
      if (!adminMessageReportsEnabled(
        ref.watch(adminMessageReportsFlagsProvider),
      )) {
        return ref.watch(fakeModerationReportsRepositoryProvider);
      }
      final url = ref.watch(messagingBackendConfigProvider).baseUrl;
      return url.trim().isEmpty
          ? const UnavailableMessagingRepository()
          : ref.watch(workerMessagingRepositoryProvider);
    });

/// The report list. The value is the `Result` itself, so a failure is data,
/// never a thrown error. Loads on open and on Retry (invalidate).
final adminMessageReportsProvider =
    FutureProvider.autoDispose<Result<List<ReportRow>, Failure>>(
      (ref) =>
          ref.watch(moderationReportsRepositoryProvider).listMessageReports(),
    );
