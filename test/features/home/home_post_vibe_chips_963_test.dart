// KAN-963: the vibe chips under a Home post: one per vibe in the breakdown,
// "Inspired 3" in the viewer's language, the viewer's own selected; tapping
// joins (+1) or leaves (-1) at once, a chip at 0 disappears, a refused change
// rolls back, and a vibe picked in the add-square sheet adds or bumps a chip.
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_vibes.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'home_test_harness.dart';
import '../../support/render_mode.dart';

const Vibe _inspired = Vibe(
  id: 'v-insp',
  key: 'inspired',
  labelEn: 'Inspired',
  labelAr: 'ملهم',
  emoji: '✨',
  colorHex: '#F59E0B',
);
const Vibe _calm = Vibe(
  id: 'v-calm',
  key: 'calm',
  labelEn: 'Calm',
  labelAr: 'هادئ',
  emoji: '🌊',
  colorHex: '#3B82F6',
);
const Vibe _hyped = Vibe(
  id: 'v-hyp',
  key: 'hyped',
  labelEn: 'Hyped',
  labelAr: 'متحمس',
  emoji: '🔥',
  colorHex: 'not-a-colour',
);
const List<Vibe> _vibes = <Vibe>[_inspired, _calm, _hyped];

/// Records the calls and answers with [ok], without a server.
class _FakeActions extends PostActionsNotifier {
  _FakeActions(super.ref, {required this.ok});
  final bool ok;
  final List<String> calls = <String>[];

  @override
  Future<bool> reactToPost(String postId, String vibeId) async {
    calls.add('react:$vibeId');
    return ok;
  }

  @override
  Future<bool> removeReaction(String postId, String vibeId) async {
    calls.add('remove:$vibeId');
    return ok;
  }
}

Post _post(Map<String, int> breakdown) => Post(
  id: 'p1',
  authorProfileId: 'prof1',
  authorUserId: 'user1',
  allowReposts: true,
  authorDisplayName: 'Suraj Mehta',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  body: 'Padel tonight',
  reactionBreakdown: <String, dynamic>{'breakdown': breakdown},
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  updatedAt: DateTime.now(),
);

Future<_FakeActions> _pump(
  WidgetTester tester,
  Post post,
  Locale locale, {
  Set<String> myReactions = const <String>{},
  bool ok = true,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late _FakeActions actions;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Material(
          child: SingleChildScrollView(
            child: HomePostRow(post: post, metrics: DabblerFeedMetrics.drawn),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hasLikedProvider.overrideWith((ref, id) async => false),
        hasRepostedProvider.overrideWith((ref, id) async => false),
        myReactionsProvider.overrideWith((ref, id) async => myReactions),
        myProfileIdProvider.overrideWith((ref) async => 'someone-else'),
        sportsProvider.overrideWith((ref) async => []),
        vibesProvider.overrideWith((ref) async => _vibes),
        postActionsProvider.overrideWith(
          (ref) => actions = _FakeActions(ref, ok: ok),
        ),
      ],
      child: MaterialApp.router(
        builder: (context, child) => DabblerToastProvider(child: child!),
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // The notifier is built lazily; read it once so `actions` is set.
  ProviderScope.containerOf(
    tester.element(find.byType(HomePostRow)),
  ).read(postActionsProvider.notifier);
  return actions;
}

DabblerFeedPill _chip(WidgetTester tester, String key) =>
    tester.widget<DabblerFeedPill>(find.byKey(ValueKey('home-vibe-chip-$key')));

BoxDecoration _deco(WidgetTester tester, String key) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byKey(ValueKey('home-vibe-chip-$key')),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  group('homeVibeToggle', () {
    test('join +1, leaving the vibe held before', () {
      final r = homeVibeToggle(
        const {'inspired': 3, 'calm': 1},
        const {'calm'},
        'inspired',
      );
      expect(r.counts, const {'inspired': 4});
      expect(r.mine, const {'inspired'});
    });

    test('leave -1; a vibe at 0 is dropped', () {
      final r = homeVibeToggle(
        const {'calm': 1, 'hyped': 2},
        const {'calm'},
        'calm',
      );
      expect(r.counts, const {'hyped': 2});
      expect(r.mine, isEmpty);
    });
  });

  for (final (String lang, String inspired, String calm, String hyped)
      in <(String, String, String, String)>[
        ('en', 'Inspired', 'Calm', 'Hyped'),
        ('ar', 'ملهم', 'هادئ', 'متحمس'),
      ]) {
    testWidgets('$lang: one chip per vibe with its count; mine is selected', (
      tester,
    ) async {
      await _pump(
        tester,
        _post(const {'inspired': 3, 'calm': 1}),
        Locale(lang),
        myReactions: const {'v-calm'},
      );
      expect(find.text('$inspired 3'), findsOneWidget);
      expect(find.text('$calm 1'), findsOneWidget);
      expect(_chip(tester, 'calm').selected, isTrue, reason: 'mine: brand');
      expect(_chip(tester, 'inspired').selected, isFalse, reason: 'outlined');
    });

    testWidgets('$lang: tapping another chip joins it (+1) and leaves mine', (
      tester,
    ) async {
      final actions = await _pump(
        tester,
        _post(const {'inspired': 3, 'calm': 1}),
        Locale(lang),
        myReactions: const {'v-calm'},
      );
      await tester.tap(find.text('$inspired 3'));
      await tester.pump();
      expect(find.text('$inspired 4'), findsOneWidget);
      expect(find.textContaining(calm), findsNothing, reason: 'calm hit 0');
      expect(_chip(tester, 'inspired').selected, isTrue);
      expect(actions.calls, <String>['react:v-insp']);
    });

    testWidgets('$lang: tapping my chip leaves it (-1)', (tester) async {
      final actions = await _pump(
        tester,
        _post(const {'inspired': 3}),
        Locale(lang),
        myReactions: const {'v-insp'},
      );
      await tester.tap(find.text('$inspired 3'));
      await tester.pump();
      expect(find.text('$inspired 2'), findsOneWidget);
      expect(_chip(tester, 'inspired').selected, isFalse);
      expect(actions.calls, <String>['remove:v-insp']);
    });

    testWidgets('$lang: a refused change rolls the chip back', (tester) async {
      await _pump(
        tester,
        _post(const {'inspired': 3}),
        Locale(lang),
        ok: false,
      );
      await tester.tap(find.text('$inspired 3'));
      await tester.pump();
      await tester.pump();
      expect(find.text('$inspired 3'), findsOneWidget);
      expect(_chip(tester, 'inspired').selected, isFalse);
    });

    testWidgets('$lang: the picker adds a new chip and bumps an existing one', (
      tester,
    ) async {
      final actions = await _pump(
        tester,
        _post(const {'inspired': 3}),
        Locale(lang),
      );
      final l = lookupAppLocalizations(Locale(lang));
      await tester.tap(find.bySemanticsLabel(l.home_post_action_vibe));
      await tester.pumpAndSettle();
      await tester.tap(find.text(hyped).last);
      await tester.pumpAndSettle();
      expect(find.text('$hyped 1'), findsOneWidget, reason: 'new chip');
      expect(_chip(tester, 'hyped').selected, isTrue);
      expect(find.text('$inspired 3'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(l.home_post_action_vibe));
      await tester.pumpAndSettle();
      await tester.tap(find.text(inspired).last);
      await tester.pumpAndSettle();
      expect(find.text('$inspired 4'), findsOneWidget, reason: 'bumped');
      expect(find.textContaining(hyped), findsNothing, reason: 'one vibe each');
      expect(actions.calls, <String>['react:v-hyp', 'react:v-insp']);
    });

    testWidgets('$lang: each chip is the sport pill, with emoji and colour', (
      tester,
    ) async {
      await _pump(
        tester,
        _post(const {'inspired': 3, 'calm': 1, 'hyped': 2}),
        Locale(lang),
        myReactions: const {'v-calm'},
      );
      // The sport pill's own metrics: drawn, the same widget as the sport tag.
      for (final k in <String>['inspired', 'calm', 'hyped']) {
        expect(_chip(tester, k).metrics, DabblerFeedMetrics.drawn);
        final h = tester.getSize(find.byKey(ValueKey('home-vibe-chip-$k')));
        expect(h.height >= DabblerHomeFrame.sportPillHeight, isTrue);
      }
      expect(find.text('✨'), findsOneWidget, reason: 'vibes.emoji');
      expect(find.text('🌊'), findsOneWidget);
      // Tint from color_hex, pastels only: outlined in the vibe's pale tone;
      // mine a deeper pastel with the hue's deep border, never a solid fill.
      final insp = DabblerHueTone.fromHex('#F59E0B')!;
      final calmTone = DabblerHueTone.fromHex('#3B82F6')!;
      expect(
        _chip(tester, 'inspired').tint,
        DabblerHueTone.parseHex('#F59E0B'),
      );
      expect(_deco(tester, 'inspired').color, insp.surface);
      final mine = _deco(tester, 'calm');
      expect(mine.color, calmTone.edge, reason: 'mine: deeper pastel');
      expect(mine.color, isNot(calmTone.solid));
      expect(mine.color!.computeLuminance() > 0.5, isTrue, reason: 'pastel');
      expect((mine.border! as Border).top.color, calmTone.deep);
      expect(_chip(tester, 'calm').selected, isTrue);
      // A bad color_hex falls back to the neutral pill.
      expect(_chip(tester, 'hyped').tint, isNull);
      expect(_deco(tester, 'hyped').color, isNull);
    });

    testWidgets('$lang: chips are as tall as the sport tag', (tester) async {
      await _pump(
        tester,
        _post(const {'inspired': 3}).copyWith(sport: 'Cricket'),
        Locale(lang),
      );
      final pills = find.byType(DabblerFeedPill);
      expect(pills, findsNWidgets(2), reason: 'sport tag + one vibe chip');
      expect(
        tester.getSize(pills.at(0)).height,
        tester.getSize(pills.at(1)).height,
      );
    });
  }
}
