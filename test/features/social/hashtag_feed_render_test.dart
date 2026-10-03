import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/screens/hashtag_feed_screen.dart';
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

/// Renders the hashtag feed (posts, empty) LTR and RTL. Writes PNGs only with
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

class _Repo extends Fake implements PostRepository {
  _Repo(this.posts);
  final List<Post> posts;
  @override
  Future<Result<List<Post>, Failure>> getHashtagFeed({
    required String hashtag,
    int limit = 20,
    int offset = 0,
  }) async => Ok(offset == 0 ? posts : const <Post>[]);
}

Post _post(String id, String body) => Post(
  id: id,
  authorProfileId: 'prof-$id',
  authorUserId: 'user-$id',
  authorDisplayName: 'Suraj Mehta',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  body: body,
  tags: const <String>['padel'],
  likeCount: 3,
  commentCount: 1,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  updatedAt: DateTime.now(),
);

Future<void> _pump(
  WidgetTester tester,
  List<Post> posts,
  Locale locale,
  Key key,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postRepositoryProvider.overrideWithValue(_Repo(posts)),
        hasLikedProvider.overrideWith((ref, id) async => false),
        hasRepostedProvider.overrideWith((ref, id) async => false),
        myReactionsProvider.overrideWith((ref, id) async => <String>{}),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        sportsProvider.overrideWith((ref) async => []),
        vibesProvider.overrideWith((ref) async => []),
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
          DabblerDesignSystemTheme.withTokens(ThemeData.light()),
          locale: locale,
        ),
        home: const HashtagFeedScreen(hashtagSlug: 'padel'),
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

    testWidgets('hashtag feed with posts — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, [
        _post('p1', 'Who is up for #padel tonight?'),
        _post('p2', 'Great #padel session at the club.'),
      ], locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerPage), findsOneWidget);
      expect(find.textContaining('#padel'), findsWidgets);
      expect(find.text('2 posts'), findsOneWidget);
      expect(find.byType(DabblerPostRow), findsNWidgets(2));
      await _shoot(tester, key, 'hashtag-feed-posts-$dir');
    }, variant: desktop);

    testWidgets('hashtag feed empty — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const <Post>[], locale, key);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      expect(find.text('No posts found for #padel'), findsOneWidget);
      await _shoot(tester, key, 'hashtag-feed-empty-$dir');
    }, variant: desktop);
  }
}
