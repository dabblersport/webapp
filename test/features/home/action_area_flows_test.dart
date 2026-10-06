import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/controllers/join_game_feedback.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_feedback.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/supabase_test_client.dart';
import '../../support/render_mode.dart';
import 'home_test_harness.dart';
import 'shell_feedback_harness.dart';

/// The three first flows on the shell's Action Area (plan §7): join game
/// (Joining… -> Joined), its error with Retry, meetup RSVP error with Retry,
/// and the early-bird check-in result as information.

GameViewController _controller(List<String> answers) {
  final client = buildTestSupabaseClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' &&
        path.contains(SupabaseConfig.vGameCardTable)) {
      return jsonObjectResponse(<String, dynamic>{
        'id': 'g1',
        'title': 'Open game',
        'start_at': '2030-08-30T10:00:00Z',
        'end_at': '2030-08-30T11:00:00Z',
        'capacity': 10,
        'roster_count': 6,
      }, request: request);
    }
    if (request.method == 'POST' &&
        path.contains('/rpc/${SupabaseConfig.rpcJoinGameFn}')) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final a = answers.removeAt(0);
      return a == 'error'
          ? postgrestErrorResponse(
              message: 'P0001: not_host',
              status: 400,
              request: request,
            )
          : jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'result': a},
            ], request: request);
    }
    return jsonListResponse(const [], request: request);
  });
  return GameViewController(
    supabase: client,
    gameId: 'g1',
    currentUserId: 'u1',
  );
}

class _Rsvp extends MeetupActionsController {
  _Rsvp(super.ref, this.answers);
  final List<bool> answers;
  int calls = 0;

  @override
  Future<Result<RsvpStatus, Failure>> rsvp(
    String meetupId,
    RsvpAction action, {
    String? profileId,
  }) async {
    calls++;
    return answers.removeAt(0)
        ? const Ok(RsvpStatus.going)
        : const Err(Failure(message: 'x'));
  }
}

Future<ShellHarness> _pumpJoin(
  WidgetTester tester,
  List<String> answers, {
  Locale locale = const Locale('en'),
}) async {
  // Built outside fake time (their realtime socket keeps a timer), one per
  // join attempt: the controller is auto-disposed after each.
  final built = await tester.runAsync(() async {
    final c = [for (final _ in answers) _controller(answers)];
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return c;
  });
  return pumpShell(
    tester,
    locale: locale,
    overrides: [
      // Auto-disposed after each join: a Retry builds a fresh controller.
      gameViewControllerProvider.overrideWith((ref, id) {
        return built!.removeAt(0);
      }),
    ],
  );
}

/// Runs the join with real (not fake) time for the HTTP leg, pumping frames.
Future<void> _settleJoin(WidgetTester tester, ShellHarness h) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await h.advance(100);
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final l = lookupAppLocalizations(locale);
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('join: Joining… -> Joined on the Action Area — $dir', (
      tester,
    ) async {
      final h = await _pumpJoin(tester, ['joined'], locale: locale);
      await shootShell(tester, 'idle-$dir');
      if (kShellShots) {
        // Render "Joining…" settled, before the (fast) fake server answers;
        // the join below dedups onto this same keyed operation.
        h.center.begin(
          FeedbackProcessing(
            kind: ProcessingKind.spinnerLabel,
            label: l.feedback_joining,
          ),
          key: 'join-game:g1',
        );
        await h.advance(800);
        await shootShell(tester, 'joining-$dir');
      }
      joinGameWithFeedback(h.container, 'g1', l);
      await tester.pump();
      expect(h.status.payload, isA<DabblerNavigationStatusActivity>());
      await h.advance(150);
      expect(find.text(l.feedback_joining), findsOneWidget);
      await _settleJoin(tester, h);
      await h.advance(1200);
      expect(find.text(l.listing_joined), findsOneWidget);
      expect(find.byType(DabblerToast), findsNothing);
      await shootShell(tester, 'joined-$dir');
      await h.advance(5000);
    }, variant: desktop);

    testWidgets('join: error + Retry -> Joined — $dir', (tester) async {
      final h = await _pumpJoin(tester, ['error', 'joined'], locale: locale);
      joinGameWithFeedback(h.container, 'g1', l);
      await h.advance(200);
      await _settleJoin(tester, h);
      await h.advance(1200);
      expect(find.text(l.feed_retry), findsOneWidget);
      expect(h.state.current?.state, isA<FeedbackResult>());
      await shootShell(tester, 'error-retry-$dir');
      await tester.tap(find.byKey(DabblerNavigationStatus.actionTargetKey));
      // Retry re-begins the same operation in place.
      expect(h.state.current?.state, isA<FeedbackProcessing>());
      await _settleJoin(tester, h);
      await h.advance(1200);
      expect(find.text(l.listing_joined), findsOneWidget);
      expect(find.byType(DabblerToast), findsNothing);
      await h.advance(5000);
    }, variant: desktop);

    testWidgets('check-in result is information on the Action Area — $dir', (
      tester,
    ) async {
      final h = await pumpShell(tester, locale: locale);
      // The emission main_navigation_screen makes after the modal pops.
      h.center.inform(
        FeedbackInformation(
          message: l.checkin_done_day(3, 14),
          duration: DabblerMotion.toastLong,
        ),
        key: 'early-bird-check-in',
      );
      await h.advance(1200);
      expect(find.text(l.checkin_done_day(3, 14)), findsOneWidget);
      expect(find.byType(DabblerToast), findsNothing);
      await shootShell(tester, 'check-in-info-$dir');
      await h.advance(4000);
      expect(h.state.current, isNull);
    });
  }

  testWidgets('meetup RSVP: error + Retry, success stays silent', (
    tester,
  ) async {
    late _Rsvp actions;
    final h = await pumpShell(
      tester,
      overrides: [
        meetupActionsProvider.overrideWith(
          (ref) => actions = _Rsvp(ref, [false, true]),
        ),
      ],
    );
    final l = lookupAppLocalizations(const Locale('en'));
    rsvpWithFeedback(h.container, 'm1', RsvpAction.going, l);
    await h.advance(1200);
    expect(find.text(l.meetups_error_generic), findsOneWidget);
    expect(find.byType(DabblerToast), findsNothing);
    await tester.tap(find.byKey(DabblerNavigationStatus.actionTargetKey));
    await h.advance(1500);
    expect(actions.calls, 2);
    expect(h.state.current, isNull);
    expect(h.phase, DabblerActionAreaPhase.idle);
  });
}
