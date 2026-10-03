import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_test_harness.dart';

/// Renders the Home screen to PNG with the real bundled faces (Glory, Gloock,
/// Meral Sans, Wingx, Iconsax) so it can be compared against the design.
///
/// Writes files only when run with `--dart-define=HOME_SHOTS_DIR=<dir>`;
/// otherwise it still pumps every frame and checks it renders cleanly.
const String _shotsDir = String.fromEnvironment('HOME_SHOTS_DIR');

Future<void> _loadFonts() async {
  final String dsFonts = '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(
        file.readAsBytes().then((b) => ByteData.sublistView(b)),
      );
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
    final FontLoader loader = FontLoader('packages/iconsax_flutter/FlutterIconsax')
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
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Post _post(String id, String name, String body, String sport, int likes,
        {int comments = 0, Duration ago = const Duration(hours: 2)}) =>
    Post(
      id: id,
      authorProfileId: 'prof-$id',
      authorUserId: 'user-$id',
      authorDisplayName: name,
      kind: PostKind.original,
      visibility: PostVisibility.public,
      postType: PostType.dab,
      personaTypeSnapshot: 'player',
      body: body,
      sport: sport,
      tags: const <String>['dabblersport'],
      likeCount: likes,
      commentCount: comments,
      createdAt: DateTime.now().subtract(ago),
      updatedAt: DateTime.now(),
    );

final FeedData _feed = FeedData(
  items: <FeedItem>[
    FeedPostItem(
      _post(
        'a',
        'Suraj Mehta',
        'Anyone playing cricket in Dubai this weekend? We need 2 more for a '
            'full side. DM if interested',
        'Cricket',
        12,
        comments: 4,
      ),
    ),
    FeedNewsItem(
      newsId: 'n1',
      id: 'n1',
      title: const {'en': 'Dubai Padel Open returns with a record prize pool'},
      body: const {
        'en': 'Organisers confirmed 64 pairs will compete across three days.',
      },
      likeCount: 0,
      commentCount: 3,
      viewCount: 120,
      tags: const [],
      isPinned: false,
      priorityScore: 0,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      feedLabel: 'Padel',
    ),
    FeedPostItem(
      _post(
        'b',
        'Khalid Al Mansouri',
        'Weekly Dubai Football Night - all welcome',
        'Football',
        38,
        ago: const Duration(hours: 8),
      ),
    ),
  ],
  hasMore: false,
);

final List<ActiveEvent> _events = <ActiveEvent>[
  GameCreatedEvent(
    id: 'g1',
    createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    gameId: 'g1',
    gameTitle: 'Sunday 5-a-side',
    sport: 'Football',
    venueName: 'Al Wasl Sports Club',
  ),
  PlayerJoinedEvent(
    id: 'p1',
    createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
    gameId: 'g2',
    gameTitle: 'Padel doubles — evening',
    sport: 'Padel',
    venueName: 'JLT Padel',
    joinCount: 4,
  ),
  NewUserEvent(
    id: 'u1',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    profileId: 'u1',
    displayName: 'Moataz Mustapha',
    sport: 'Tennis',
  ),
];

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('renders Home (For You, loading) — $dir', (tester) async {
      const Key key = Key('shot');
      await pumpHome(
        tester,
        feedState: const FeedLoading(),
        locale: locale,
        boundaryKey: key,
      );
      expect(tester.takeException(), isNull);
      await _shoot(tester, key, 'home-$dir-for-you-loading');
    }, variant: desktop);

    testWidgets('renders Home (Active tab, events) — $dir', (tester) async {
      const Key key = Key('shot');
      await pumpHome(
        tester,
        feedState: const FeedLoading(),
        activeState: ActiveFeedData(events: _events, hasMore: false),
        locale: locale,
        boundaryKey: key,
      );
      await tester.tap(find.text(lookupAppLocalizations(locale).tab_active));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      await _shoot(tester, key, 'home-$dir-active');
    }, variant: desktop);

    testWidgets('renders Home (For You, posts + news) — $dir', (tester) async {
      const Key key = Key('shot');
      await pumpHome(tester, feedState: _feed, locale: locale, boundaryKey: key);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await _shoot(tester, key, 'home-$dir-for-you-posts');
    }, variant: desktop);

    testWidgets('renders Home (For You, error) — $dir', (tester) async {
      const Key key = Key('shot');
      await pumpHome(
        tester,
        feedState: const FeedFailure('Could not load the feed'),
        locale: locale,
        boundaryKey: key,
      );
      expect(tester.takeException(), isNull);
      await _shoot(tester, key, 'home-$dir-for-you-error');
    }, variant: desktop);
  }
}
