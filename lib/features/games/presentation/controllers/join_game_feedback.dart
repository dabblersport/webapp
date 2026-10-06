import 'dart:async';

import 'package:dabbler/core/feedback/feedback_center.dart';
import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/controllers/join_action_toast.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Joins game [id] through the game detail's own controller and reports it as
/// one operation on the feedback center: "Joining…" -> the outcome, or an
/// error with Retry (Action Area plan §7, flows 1-2). Emits intents only.
///
/// Everything is taken from [container], not a widget: the listing card can
/// be disposed while the server works, and Retry runs after it is gone.
Future<Result<JoinActionResult, Failure>> joinGameWithFeedback(
  ProviderContainer container,
  String id,
  AppLocalizations l,
) {
  return container
      .read(feedbackCenterProvider.notifier)
      .run<JoinActionResult>(
        key: 'join-game:$id',
        processing: FeedbackProcessing(
          kind: ProcessingKind.spinnerLabel,
          label: l.feedback_joining,
        ),
        task: () => _join(container, id),
        success: (action) => FeedbackResult.success(
          action == JoinActionResult.joined
              ? l.listing_joined
              : joinActionMessage(action),
        ),
        // The controller's own error copy (the detail screen's), else ours.
        failure: (f, retry) => FeedbackResult.error(
          f.message.isNotEmpty ? f.message : l.feedback_join_failed,
          action: FeedbackAction(label: l.feed_retry, onPressed: retry),
        ),
      );
}

Future<Result<JoinActionResult, Failure>> _join(
  ProviderContainer container,
  String id,
) async {
  final provider = gameViewControllerProvider(id);
  // The controller is auto-disposed; hold it for the length of the call.
  final loaded = Completer<void>();
  final hold = container.listen(provider, (_, next) {
    if (!next.isLoading && !loaded.isCompleted) loaded.complete();
  });
  try {
    await container.read(provider.notifier).joinGame();
    // The controller's own first load runs alongside the join; let it land
    // before the controller is released.
    if (hold.read().isLoading) await loaded.future;
    final result = hold.read();
    final action = result.lastAction;
    if (action == null) {
      return Err(Failure(message: result.error ?? ''));
    }
    if (action == JoinActionResult.joined) {
      container.invalidate(nearbyGamesProvider);
      container.invalidate(myPinnedGamesProvider);
    }
    return Ok(action);
  } finally {
    hold.close();
  }
}
