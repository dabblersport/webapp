// KAN-1000 (G-02, G-03): the post-activity line in the game and meetup
// detail. The server decides, from rpc_rating_get and rpc_result_get:
// - an eligible participant inside the 48h window (not_started /
//   partly_saved) gets "Rate and score" -> /post-activity/:eventId;
// - the organiser of a competitive game whose result is still open gets
//   "Review result" -> /result/:eventId.
// The device clock only skips the reads before the activity has ended.

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/post_activity/data/post_activity_repository.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_controller.dart'
    show postActivityNowProvider;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Which lines the entry shows: (rate, review).
final postActivityEntryProvider = FutureProvider.autoDispose
    .family<(bool, bool), String>((ref, eventId) async {
      final repo = ref.watch(postActivityRepositoryProvider);
      final flow = await repo.flow(eventId);
      final rate = flow.fold(
        (_) => false,
        (f) =>
            f.state == RatingFlowState.notStarted ||
            f.state == RatingFlowState.partlySaved,
      );
      final tally = await repo.result(eventId);
      final review = tally.fold(
        (_) => false,
        (t) => t.isOrganiser && t.competitive && t.open,
      );
      return (rate, review);
    });

class PostActivityEntry extends ConsumerWidget {
  const PostActivityEntry({
    super.key,
    required this.eventId,
    this.title,
    this.endAt,
  });

  /// games.id / meetups.id, which is the events.id.
  final String eventId;
  final String? title;

  /// Before this the server is not asked (nothing can be open yet).
  final DateTime? endAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.postActivity) return const SizedBox.shrink();
    final now = ref.watch(postActivityNowProvider)();
    if (endAt != null && endAt!.isAfter(now)) return const SizedBox.shrink();
    final (rate, review) =
        ref.watch(postActivityEntryProvider(eventId)).valueOrNull ??
        (false, false);
    if (!rate && !review) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rate)
          DabblerActionRow(
            key: const ValueKey<String>('post-activity-entry-rate'),
            icon: 'star',
            label: l.pa_entry_rate,
            note: l.pa_entry_rate_note,
            onTap: () =>
                context.push(RoutePaths.postActivity(eventId, title: title)),
          ),
        if (review)
          DabblerActionRow(
            key: const ValueKey<String>('post-activity-entry-review'),
            icon: 'cup',
            label: l.pa_entry_review,
            note: l.pa_entry_review_note,
            onTap: () =>
                context.push(RoutePaths.resultApproval(eventId, title: title)),
          ),
      ],
    );
  }
}
