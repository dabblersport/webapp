import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/social/comment.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/home/presentation/widgets/home_reaction_sheet.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/screens/post_detail_screen.dart';
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

/// Renders post detail (P01-P03) LTR and RTL. Writes PNGs only with
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
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

class _Actions extends PostActionsNotifier {
  _Actions(super.ref);
  @override
  Future<void> recordView(String postId) async {}
}

const List<Vibe> _vibes = <Vibe>[
  Vibe(id: '1', key: 'happy', labelEn: 'Happy', labelAr: 'سعيد', type: 'feeling'),
  Vibe(id: '2', key: 'calm', labelEn: 'Calm', labelAr: 'هادئ', type: 'feeling'),
  Vibe(id: '3', key: 'energetic', labelEn: 'Energetic', labelAr: 'نشيط', type: 'action'),
  Vibe(id: '4', key: 'proud', labelEn: 'Proud', labelAr: 'فخور', type: 'feeling'),
];

final Post _post = Post(
  id: 'p1',
  authorProfileId: 'prof-a',
  authorUserId: 'user-a',
  authorDisplayName: 'Suraj Mehta',
  kind: PostKind.original,
  visibility: PostVisibility.followers,
  postType: PostType.dab,
  personaTypeSnapshot: 'player',
  body: 'Anyone playing cricket in Dubai this weekend? We need 2 more for a '
      'full side.',
  sport: 'Cricket',
  tags: const <String>['dabblersport', 'cricket'],
  vibes: const <Vibe>[Vibe(id: '3', key: 'energetic', labelEn: 'Energetic', labelAr: 'نشيط', type: 'action')],
  likeCount: 12,
  commentCount: 3,
  createdAt: DateTime(2026, 10, 3, 9, 30),
  updatedAt: DateTime(2026, 10, 3, 9, 30),
);

PostComment _c(String id, String name, String body, {String? parent}) =>
    PostComment(
      id: id,
      postId: 'p1',
      authorUserId: 'u-$id',
      authorProfileId: 'pr-$id',
      authorDisplayName: name,
      body: body,
      parentCommentId: parent,
      createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
    );

final List<PostComment> _comments = <PostComment>[
  _c('c1', 'Aisha Khan', 'I am in! Saturday morning works for me.'),
  _c('c2', 'Omar Ali', 'Count me in too.', parent: 'c1'),
  _c('c3', 'Lina Haddad', 'Which ground are you booking?'),
];

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  Key key, {
  List<PostComment> comments = const <PostComment>[],
  String? attachedImage,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postActionsProvider.overrideWith((ref) => _Actions(ref)),
        postDetailProvider.overrideWith((ref, id) async => _post),
        postCommentsProvider.overrideWith((ref, id) async => comments),
        hasLikedProvider.overrideWith((ref, id) async => true),
        hasRepostedProvider.overrideWith((ref, id) async => false),
        myReactionsProvider.overrideWith((ref, id) async => <String>{'2'}),
        myProfileIdProvider.overrideWith((ref) async => 'someone-else'),
        sportsProvider.overrideWith((ref) async => []),
        vibesProvider.overrideWith((ref) async => _vibes),
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
        home: PostDetailScreen(postId: 'p1', debugAttachedImageUrl: attachedImage),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Drops the screen and lets realtime / image timers drain.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    const Key key = Key('shot');

    testWidgets('post with replies — $dir', (tester) async {
      await _pump(tester, locale, key, comments: _comments);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerPostRow), findsOneWidget);
      expect(find.text('Replies'), findsOneWidget);
      expect(find.byType(DabblerAvatar), findsWidgets);
      expect(find.byType(DabblerCommentRow), findsNWidgets(3));
      expect(find.byType(DabblerReplyComposer), findsOneWidget);
      expect(find.byType(DabblerPostDetailLine), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is DabblerChip && w.vibe != null && w.label == 'Energetic',
        ),
        findsOneWidget,
      );
      await _shoot(tester, key, 'post-detail-replies-$dir');
      await _settle(tester);
    });

    testWidgets('post with no replies — $dir', (tester) async {
      await _pump(tester, locale, key);
      expect(tester.takeException(), isNull);
      expect(find.text('No replies yet'), findsOneWidget);
      await _shoot(tester, key, 'post-detail-empty-$dir');
      await _settle(tester);
    });

    testWidgets('composing a reply — $dir', (tester) async {
      await _pump(
        tester,
        locale,
        key,
        comments: _comments,
        attachedImage: 'https://example.com/a.jpg',
      );
      await tester.enterText(find.byType(EditableText), 'See you there!');
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerImage), findsWidgets);
      expect(find.byType(DabblerAttachmentChip), findsOneWidget);
      await _shoot(tester, key, 'post-detail-composing-$dir');
      await _settle(tester);
    });

    testWidgets('replying to a reply — $dir', (tester) async {
      await _pump(tester, locale, key, comments: _comments);
      await tester.tap(find.text('Reply').first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Aisha Khan'), findsWidgets);
      expect(find.text('Replying to'), findsOneWidget);
      await _shoot(tester, key, 'post-detail-replying-$dir');
      await tester.tap(find.bySemanticsLabel('Cancel reply'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Replying to'), findsNothing);
      await _settle(tester);
    });

    testWidgets('long-press a reply opens its menu — $dir', (tester) async {
      await _pump(tester, locale, key, comments: _comments);
      await tester.longPress(
        find.text('Which ground are you booking?'),
        warnIfMissed: false,
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      await _settle(tester);
    });

    testWidgets('vibe picker sheet — $dir', (tester) async {
      await _pump(tester, locale, key, comments: _comments);
      showHomeReactionSheet(
        tester.element(find.byType(DabblerPostRow)),
        postId: 'p1',
        myReactions: const <String>{'2'},
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('React with a Vibe'), findsOneWidget);
      await _shoot(tester, key, 'post-detail-vibes-$dir');
      await _settle(tester);
    });
  }
}
