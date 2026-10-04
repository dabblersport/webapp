import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/search/meetup_search_result.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/search/hashtag_search_result.dart';
import 'package:dabbler/data/models/search/post_search_result.dart';
import 'package:dabbler/data/models/search/search_result_bundle.dart';
import 'package:dabbler/data/repositories/search_repository.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/features/social/presentation/screens/social_search_screen.dart';
import 'package:dabbler/features/social/presentation/widgets/search_cards.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Renders the social search screen states LTR + RTL. Writes PNGs only with
/// `--dart-define=SOCIAL_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('SOCIAL_SHOTS_DIR');

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png =
        await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

final SearchResultBundle _bundle = SearchResultBundle(
  games: [
    GameModel.fromJson({
      'id': 'g1',
      'title': 'Football night at the marina',
      'sport': 'football',
      'venue_name': 'Al Maryah Island',
      'start_at': DateTime.now().add(const Duration(hours: 5)).toIso8601String(),
      'max_players': 10,
      'current_players': 3,
    }),
  ],
  meetups: [
    MeetupSearchResult(
      id: 'm1',
      title: 'Football community meetup',
      startAt: DateTime.now().add(const Duration(days: 2)),
    ),
  ],
  profiles: [
    Profile(
      id: 'p1',
      userId: 'u1',
      profileType: 'player',
      username: 'ahmed_fc',
      displayName: 'Ahmed Football',
    ),
    Profile(
      id: 'p2',
      userId: 'u2',
      profileType: 'player',
      username: 'sara.padel',
      displayName: 'Sara Footwork',
    ),
  ],
  hashtags: [
    HashtagSearchResult(id: 'h1', slug: 'football', postCount: 128),
    HashtagSearchResult(id: 'h2', slug: 'footballdubai', postCount: 34),
  ],
  posts: [
    PostSearchResult(
      id: 'po1',
      body: 'Looking for two more for football tonight at Al Quoz. Bring water!',
      authorDisplayName: 'Omar',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ],
);

class _FakeRepo implements SearchRepository {
  _FakeRepo(this.result);
  final Result<SearchResultBundle, Failure> result;

  @override
  Future<Result<SearchResultBundle, Failure>> unifiedSearch({
    required String query,
    required SearchMode mode,
    int limit = 20,
  }) async =>
      result;
}

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  Key key, {
  String? query,
  Result<SearchResultBundle, Failure>? result,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(_FakeRepo(result ?? Ok(_bundle))),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: SocialSearchScreen(initialQuery: query),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _loadFonts() => loadRenderFonts();

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    const Key key = Key('shot');

    testWidgets('default with recent searches — $dir', (tester) async {
      SharedPreferences.setMockInitialValues({
        'social_search_recent_queries': ['#football', '@ahmed_fc', 'padel'],
      });
      await _pump(tester, locale, key);
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).sfx_recent), findsOneWidget);
      expect(find.byType(DabblerSearchField), findsOneWidget);
      await _shoot(tester, key, 'search-default-$dir');
    });

    testWidgets('results — $dir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, locale, key, query: 'foot');
      expect(tester.takeException(), isNull);
      expect(find.text('Ahmed Football'), findsOneWidget);
      expect(find.byType(SearchHashtagCard), findsNWidgets(2));
      expect(find.byType(DabblerHighlightedText), findsWidgets);
      await _shoot(tester, key, 'search-results-$dir');
    });

    testWidgets('view all — $dir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, locale, key, query: 'foot');
      await tester.tap(find.text(lookupAppLocalizations(locale).sfx_view_all).first);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).sfx_list_header(2, lookupAppLocalizations(locale).sfx_people.toLowerCase(), '\u2066foot\u2069')), findsOneWidget);
      expect(find.byType(SearchPersonRow), findsWidgets);
      await _shoot(tester, key, 'search-viewall-$dir');
    });

    for (final (String, int, String, Type) v in <(String, int, String, Type)>[
      ('hashtags', 1, 'search-viewall-hashtags', SearchHashtagGridCard),
      ('events', 2, 'search-viewall-events', SearchGameEventCard),
      ('posts', 3, 'search-viewall-posts', SearchPostRow),
    ]) {
      testWidgets('view all ${v.$1} — $dir', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await _pump(tester, locale, key, query: 'foot');
        await tester.tap(find.text(locale.languageCode == 'ar' ? 'عرض الكل' : 'View all').at(v.$2));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(v.$4), findsWidgets);
        await _shoot(tester, key, '${v.$3}-$dir');
      });
    }

    testWidgets('empty — $dir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, locale, key,
          query: 'zzz', result: const Ok(SearchResultBundle.empty));
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).sfx_no_results_for('\u2066zzz\u2069')), findsOneWidget);
      await _shoot(tester, key, 'search-empty-$dir');
    });

    testWidgets('error — $dir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, locale, key,
          query: 'foot',
          result: const Err(Failure(message: 'Search failed. Try again.')));
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      await _shoot(tester, key, 'search-error-$dir');
    });
  }
}
