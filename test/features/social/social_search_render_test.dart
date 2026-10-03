import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/search/hashtag_search_result.dart';
import 'package:dabbler/data/models/search/post_search_result.dart';
import 'package:dabbler/data/models/search/search_result_bundle.dart';
import 'package:dabbler/data/repositories/search_repository.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/features/social/presentation/screens/social_search_screen.dart';
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

Future<void> _loadFonts() async {
  final String dsFonts =
      '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf', 'Glory-Regular.ttf', 'Glory-Medium.ttf',
    'Glory-SemiBold.ttf', 'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf', 'meral-sans-regular.ttf', 'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf', 'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader =
        FontLoader('packages/iconsax_flutter/FlutterIconsax')
          ..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

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

const SearchResultBundle _bundle = SearchResultBundle(
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
  Result<SearchResultBundle, Failure> result = const Ok(_bundle),
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [searchRepositoryProvider.overrideWithValue(_FakeRepo(result))],
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
      expect(find.text('Recent'), findsOneWidget);
      expect(find.byType(DabblerSearchField), findsOneWidget);
      await _shoot(tester, key, 'search-default-$dir');
    });

    testWidgets('results — $dir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, locale, key, query: 'foot');
      expect(tester.takeException(), isNull);
      expect(find.text('Ahmed Football'), findsOneWidget);
      expect(find.text('#football'), findsOneWidget);
      expect(find.byType(DabblerHighlightedText), findsWidgets);
      expect(find.byType(DabblerTabs), findsOneWidget);
      await _shoot(tester, key, 'search-results-$dir');
    });

    testWidgets('view all — $dir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, locale, key, query: 'foot');
      await tester.tap(find.text('View all').first);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('All people for "foot"'), findsOneWidget);
      await _shoot(tester, key, 'search-viewall-$dir');
    });

    testWidgets('empty — $dir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, locale, key,
          query: 'zzz', result: const Ok(SearchResultBundle.empty));
      expect(tester.takeException(), isNull);
      expect(find.text('No results for "zzz"'), findsOneWidget);
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
