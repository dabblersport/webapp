import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/news/news_comment.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/features/home/presentation/widgets/home_news_rows.dart';
import 'package:dabbler/features/news/presentation/screens/news_detail_screen.dart';
import 'package:dabbler/features/news/providers/news_comments_provider.dart';
import 'package:dabbler/features/social/presentation/widgets/public_activity_card.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Renders the news article and the public activity card LTR and RTL.
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
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

class _Comments extends StateNotifier<AsyncValue<List<NewsComment>>>
    implements NewsCommentsNotifier {
  _Comments(List<NewsComment> c) : super(AsyncData(c));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final FeedNewsItem _item = FeedNewsItem(
  newsId: 'n1',
  id: 'n1',
  title: const {
    'en': 'Padel league opens its winter season in Dubai',
    'ar': 'دوري البادل يفتتح موسمه الشتوي في دبي',
  },
  body: const {
    'en': 'Twelve clubs signed up for the new season. Matches run every '
        'weekend through February, with the final at the Marina courts.',
    'ar': 'اشترك اثنا عشر ناديا في الموسم الجديد. تقام المباريات كل عطلة '
        'نهاية أسبوع حتى فبراير.',
  },
  likeCount: 4,
  commentCount: 1,
  viewCount: 120,
  tags: const [],
  isPinned: false,
  priorityScore: 0,
  createdAt: DateTime(2026, 9, 30),
  feedLabel: 'Padel',
  sourceLabel: 'Dabbler Sports Desk',
  coverImageUrl: 'https://example.invalid/cover.png',
);

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  Locale locale,
  Key key,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myReactionsProvider.overrideWith((ref, id) async => <String>{}),
        homeNewsReactionCountsProvider.overrideWith(
          (ref, id) async => const {'x': 4},
        ),
        newsCommentsProvider.overrideWith(
          (ref, id) => _Comments([
            NewsComment(
              id: 'c1',
              newsId: 'n1',
              authorUserId: 'u1',
              authorProfileId: 'p1',
              body: 'Cannot wait for the final!',
              newsTitleSnapshot: const {},
              likeCount: 0,
              createdAt: DateTime.now().subtract(const Duration(hours: 1)),
              authorDisplayName: 'Layla Hassan',
            ),
          ]),
        ),
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
        home: home,
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

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('news article with cover and body — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, NewsDetailScreen(item: _item), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerPage), findsOneWidget);
      expect(find.byType(DabblerImage), findsOneWidget);
      final cover = tester.widget<DabblerImage>(find.byType(DabblerImage));
      expect(cover.headers?['User-Agent'], contains('Mozilla/5.0'));
      expect(cover.headers?['Accept'], startsWith('image/avif'));
      expect(find.text('React'), findsNothing);
      final like = tester.widget<DabblerButton>(
        find.byWidgetPredicate(
          (w) => w is DabblerButton && w.semanticLabel == 'Like',
        ),
      );
      expect(like.onLongPress, isNotNull);
      expect(find.text('Dabbler Sports Desk'), findsOneWidget);
      expect(find.byType(DabblerTextField), findsOneWidget);
      await _shoot(tester, key, 'news-detail-article-$dir');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Cannot wait for the final!'), findsOneWidget);
      await _shoot(tester, key, 'news-detail-comments-$dir');
    }, variant: desktop);

    testWidgets('public activity card row — $dir', (tester) async {
      const Key key = Key('shot');
      final activity = PublicActivity(
        id: 'a1',
        activityType: PublicActivityType.comment,
        actorProfileId: 'x',
        actorUsername: 'khalid',
        targetNewsId: 'n1',
        targetTitle: const {'en': 'Padel league opens its winter season'},
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await _pump(
        tester,
        DabblerPage(
          body: ListView(children: [PublicActivityCard(activity: activity)]),
        ),
        locale,
        key,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerActivityRow), findsOneWidget);
      expect(find.byType(DabblerAvatar), findsOneWidget);
      await _shoot(tester, key, 'public-activity-card-$dir');
    }, variant: desktop);
  }
}
