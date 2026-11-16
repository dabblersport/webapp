// KAN-961: the Home feed post card shows its fields as the Home Feed design
// (`Home Feed.dc.html`) derives them: #hashtags as links where they stand in
// the body, the sport emoji before the sport label, the short post age and the
// type pill in the viewer's language, and the action names localised.
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_display.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
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

Post _post({
  String body =
      'Anyone playing cricket this weekend? DM if interested #dabblersport',
  String? sport = 'Cricket',
  List<String> tags = const <String>['dabblersport', 'nets'],
  bool moderation = false,
  List<Vibe> vibes = const <Vibe>[],
  Map<String, dynamic> reactionBreakdown = const <String, dynamic>{},
}) => Post(
  id: 'p1',
  authorProfileId: 'prof1',
  authorUserId: 'user1',
  allowReposts: true,
  authorDisplayName: 'Suraj Mehta',
  personaTypeSnapshot: 'player',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  body: body,
  sport: sport,
  tags: tags,
  requiresModeration: moderation,
  vibes: vibes,
  reactionBreakdown: reactionBreakdown,
  likeCount: 12,
  commentCount: 0,
  createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 5)),
  updatedAt: DateTime.now(),
);

Future<void> _pump(
  WidgetTester tester,
  Post post,
  Locale locale, {
  Set<String> myReactions = const <String>{},
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
        vibesProvider.overrideWith((ref) async => []),
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
}

const Vibe _motivated = Vibe(
  id: 'v1',
  key: 'motivated',
  labelEn: 'Motivated',
  labelAr: 'متحمس',
);

/// The actions row's vibe glyph (`add-square`).
DabblerIcon _vibeGlyph(WidgetTester tester) => tester.widget<DabblerIcon>(
  find.byWidgetPredicate((w) => w is DabblerIcon && w.name == 'add-square'),
);

DabblerPostRow _row(WidgetTester tester) =>
    tester.widget<DabblerPostRow>(find.byType(DabblerPostRow));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initHomeTestSupabase);

  group('homePostSegments (the design segments(p.body))', () {
    test('a body #hashtag is a link where it stands, not repeated', () {
      final runs = homePostSegments(_post());
      expect(
        runs.map((r) => r.text).join(),
        contains('interested #dabblersport'),
      );
      expect(runs.where((r) => r.link).map((r) => r.text).toList(), <String>[
        '#dabblersport',
        ' #nets',
      ], reason: 'the body tag once, then the tag the body does not show');
      expect(runs.first.link, isFalse);
    });

    test('Arabic hashtags are links too', () {
      final runs = homePostSegments(
        _post(body: 'مباراة الليلة #كريكيت في دبي', tags: const <String>[]),
      );
      expect(runs.map((r) => (r.text, r.link)).toList(), <(String, bool)>[
        ('مباراة الليلة ', false),
        ('#كريكيت', true),
        (' في دبي', false),
      ]);
    });
  });

  for (final (String lang, String age, String type, String like)
      in <(String, String, String, String)>[
        ('en', '2h', 'Dab', 'Like'),
        ('ar', '2 س', 'داب', 'إعجاب'),
      ]) {
    testWidgets('$lang: age, type pill, role, hashtags, sport emoji, actions', (
      tester,
    ) async {
      await _pump(tester, _post(), Locale(lang));
      final row = _row(tester);
      expect(row.time, age, reason: 'the design short age (p.time)');
      expect(find.text(age), findsOneWidget);
      expect(row.distance, type, reason: 'the type pill off the Nearby tab');
      expect(find.text(type), findsOneWidget);
      expect(row.roleLabel, lang == 'ar' ? 'لاعب' : 'Player');
      expect(row.likeLabel, like, reason: 'action names are localised');
      expect(row.segments!.where((s) => s.link).map((s) => s.text), <String>[
        '#dabblersport',
        ' #nets',
      ]);
      expect(find.text('🏏'), findsOneWidget, reason: 'p.sportEmoji');
      expect(find.text('Cricket'), findsOneWidget, reason: 'p.sport');
      expect(find.byType(DabblerSportIcon), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(DabblerPostRow))),
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
    });

    testWidgets('$lang: a sport the design does not list gets the medal', (
      tester,
    ) async {
      await _pump(tester, _post(sport: 'Curling'), Locale(lang));
      expect(find.text(homeSportEmojiFallback), findsOneWidget);
    });

    testWidgets('$lang: the moderation badge is localised', (tester) async {
      await _pump(tester, _post(moderation: true), Locale(lang));
      expect(
        find.text(lang == 'ar' ? 'قيد المراجعة' : 'Pending review'),
        findsOneWidget,
      );
    });

    testWidgets('$lang: no posting-vibe pill; the breakdown is a chip', (
      tester,
    ) async {
      await _pump(
        tester,
        _post(
          vibes: const <Vibe>[_motivated],
          reactionBreakdown: const <String, dynamic>{
            'breakdown': <String, dynamic>{'motivated': 4},
          },
        ),
        Locale(lang),
      );
      expect(_row(tester).vibeTagLabel, isNull, reason: 'KAN-642 stays off');
      expect(_row(tester).reactions, isNotNull, reason: 'KAN-963 chips');
      expect(
        find.byKey(const ValueKey('home-vibe-chip-motivated')),
        findsOneWidget,
      );
    });

    testWidgets('$lang: the vibe action is muted and linear at rest', (
      tester,
    ) async {
      await _pump(tester, _post(), Locale(lang));
      final glyph = _vibeGlyph(tester);
      final colors = DabblerColors.of(
        tester.element(find.byType(DabblerPostRow)),
      );
      expect(_row(tester).vibed, isFalse);
      expect(glyph.weight, DabblerIconWeight.linear);
      expect(glyph.color, colors.textSecondary);
    });

    testWidgets('$lang: the vibe action is brand and bold once vibed', (
      tester,
    ) async {
      await _pump(tester, _post(), Locale(lang), myReactions: const {'v1'});
      final glyph = _vibeGlyph(tester);
      final colors = DabblerColors.of(
        tester.element(find.byType(DabblerPostRow)),
      );
      expect(_row(tester).vibed, isTrue);
      expect(glyph.weight, DabblerIconWeight.bold);
      expect(glyph.color, colors.brandPrimary);
    });
  }
}
