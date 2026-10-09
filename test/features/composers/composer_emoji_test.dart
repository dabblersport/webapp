import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_create_request.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/social/presentation/composer_emoji.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_vibes_sheet.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-462: Create Post shows the design's emoji (`Home Feed.dc.html` VIBES,
/// SPORT_EMOJI, postTags) through the DS emoji slots only, display only, and
/// the text box's empty field area is the design's 162dp. Writes PNGs only
/// with `--dart-define=KAN462_SHOTS_DIR=<dir>`; brightness follows
/// `--dart-define=RENDER_DARK=1`.
const String _shotsDir = String.fromEnvironment('KAN462_SHOTS_DIR');
const Key _key = Key('kan462-shot');

/// Screenshot harness only: tries a real colour emoji face from the system.
/// Measured 2026-10-09: the test engine still draws Apple Color Emoji (.ttc,
/// sbix) as boxes, so emoji in these PNGs are placeholders.
Future<void> _loadEmojiFont() async {
  for (final String path in <String>[
    '/System/Library/Fonts/Apple Color Emoji.ttc',
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
  ]) {
    final File f = File(path);
    if (!f.existsSync()) continue;
    for (final String name in <String>[
      'Apple Color Emoji',
      'Noto Color Emoji',
    ]) {
      final FontLoader loader = FontLoader(name)
        ..addFont(f.readAsBytes().then((b) => ByteData.sublistView(b)));
      await loader.load();
    }
    return;
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_shotsDir.isEmpty) return;
  const String theme = String.fromEnvironment('RENDER_DARK') == '1'
      ? 'dark'
      : 'light';
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File(
      '$_shotsDir/$name-$theme.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Every design vibe, plus one key the design does not know. The vibe's
/// database emoji is deliberately different from the design's.
final List<Vibe> _vibes = <Vibe>[
  for (final DabblerVibe v in DabblerVibe.values)
    Vibe(
      id: v.key,
      key: v.key,
      labelEn: v.label,
      labelAr: v.label,
      emoji: 'db',
    ),
  const Vibe(id: 'x', key: 'not-in-design', labelEn: 'Mystery', labelAr: ''),
];

class _CapturingRepo implements PostRepository {
  PostCreateRequest? last;

  @override
  Future<Result<Post, Failure>> createFullPost(
    PostCreateRequest request,
  ) async {
    last = request;
    return const Err(
      Failure(category: FailureCode.validation, message: 'captured'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _app(
  WidgetTester tester,
  Locale locale,
  Widget home, {
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        vibesProvider.overrideWith((ref) async => _vibes),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _key, child: child),
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
  await _settle(tester, 12);
}

Widget _modal(Widget screen) => Navigator(
  pages: <Page<void>>[
    const MaterialPage<void>(child: DabblerPage(body: SizedBox.expand())),
    AdaptiveModalPage(child: screen),
  ],
  onPopPage: (route, result) => route.didPop(result),
);

String? _badgeEmoji(WidgetTester tester, String label) => tester
    .widget<DabblerBadge>(
      find.byWidgetPredicate((w) => w is DabblerBadge && w.label == label),
    )
    .emoji;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
    if (_shotsDir.isNotEmpty) await _loadEmojiFont();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  test('mapping: all 119 design vibes, 9 design sports, unknown is null', () {
    expect(composerVibeEmojiByKey.length, 119);
    for (final DabblerVibe v in DabblerVibe.values) {
      expect(composerVibeEmoji(v.key), isNotNull, reason: v.key);
    }
    expect(composerVibeEmoji('happy'), '😄');
    expect(composerVibeEmoji('Inspired'), '✨');
    expect(composerVibeEmoji("Let's Rally"), '🙌');
    expect(composerVibeEmoji('not-in-design'), isNull);
    expect(composerVibeEmoji(null), isNull);
    expect(composerSportEmojiByKey.length, 9);
    expect(composerSportEmoji('padel'), '🎾');
    expect(composerSportEmoji('Football'), '⚽️');
    expect(composerSportEmoji('yoga'), isNull);
    expect(composerSportEmoji('table_tennis'), isNull);
    expect(composerPlaceTagEmoji, '📍');
    expect(composerGameTagEmoji, '🗓️');
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String lang = locale.languageCode;
    final AppLocalizations l = lookupAppLocalizations(locale);

    testWidgets('vibe sheet chips carry the design emoji — $lang', (
      tester,
    ) async {
      await _app(
        tester,
        locale,
        DabblerPage(
          body: Consumer(
            builder: (context, ref, _) {
              ref.watch(vibesProvider);
              return Center(
                child: DabblerButton(
                  label: 'open',
                  onPressed: () => showComposerVibesSheet(
                    context,
                    ref,
                    selectedVibeId: null,
                    kindLabel: 'Moment',
                    onConfirm: (_) {},
                    onClear: () {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      final Map<String?, String?> byKey = <String?, String?>{
        for (final DabblerChip c in tester.widgetList<DabblerChip>(
          find.byType(DabblerChip, skipOffstage: false),
        ))
          c.vibe?.key ?? c.label: c.emoji,
      };
      expect(byKey['happy'], '😄');
      expect(byKey['supportive'], '🤝');
      expect(byKey['neutral'], '🙂');
      // The design's emoji, never the database's.
      expect(byKey.values, isNot(contains('db')));
      // A vibe the design does not list draws no emoji.
      expect(byKey.containsKey('Mystery'), isTrue);
      expect(byKey['Mystery'], isNull);
      await _shoot(tester, 'vibe-sheet-$lang');
    });

    testWidgets('tag row: designed emoji per tag, equal heights — $lang', (
      tester,
    ) async {
      await _app(
        tester,
        locale,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: composerTagRow(
              vibeName: 'Inspired',
              // A localized name still resolves through its sport_key.
              sportName: lang == 'ar' ? 'بادل' : 'Padel',
              sportKey: 'padel',
              locationName: 'Nad Al Sheba',
              gameName: 'Padel doubles',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final DabblerChip vibe = tester.widget(find.byType(DabblerChip));
      expect(vibe.emoji, '✨');
      expect(_badgeEmoji(tester, lang == 'ar' ? 'بادل' : 'Padel'), '🎾');
      expect(_badgeEmoji(tester, 'Nad Al Sheba'), '📍');
      expect(_badgeEmoji(tester, 'Padel doubles'), '🗓️');
      // KAN-456 retained: one height across vibe, sport, place and game.
      final double h = tester.getSize(find.byType(DabblerChip)).height;
      final Finder badges = find.byType(DabblerBadge);
      expect(badges, findsNWidgets(3));
      for (final Element e in badges.evaluate()) {
        expect((e.renderObject! as RenderBox).size.height, h);
      }
      await _shoot(tester, 'tag-row-$lang');
    });

    testWidgets('tag row: unlisted vibe and sport draw no emoji — $lang', (
      tester,
    ) async {
      await _app(
        tester,
        locale,
        Scaffold(
          body: composerTagRow(
            vibeName: 'Mystery',
            sportName: 'Yoga',
            sportKey: 'yoga',
          ),
        ),
      );
      expect(
        tester.widget<DabblerChip>(find.byType(DabblerChip)).emoji,
        isNull,
      );
      expect(_badgeEmoji(tester, 'Yoga'), isNull);
    });

    testWidgets('text box: empty field area is 162dp; filled — $lang', (
      tester,
    ) async {
      await _app(tester, locale, _modal(const PostComposerScreen()));
      expect(tester.takeException(), isNull);
      final Finder area = find.byKey(
        const ValueKey<String>('dabbler-composer-field-area'),
      );
      expect(area, findsOneWidget);
      expect(
        tester.getSize(area).height,
        DabblerComposerBox.designedFieldMinHeight,
      );
      final Finder padded = find
          .ancestor(of: area, matching: find.byType(Padding))
          .first;
      expect(tester.getSize(padded).height, DabblerComposerBox.designedHeight);
      expect(DabblerComposerBox.designedHeight, 162);

      final PostComposerNotifier n = ProviderScope.containerOf(
        tester.element(find.byType(PostComposerScreen)),
      ).read(postComposerProvider.notifier);
      await tester.enterText(
        find.byType(EditableText).first,
        'Anyone up for padel this Friday? Need two more #dabblerpadel',
      );
      n.setVibe(id: 'inspired', label: 'Inspired', emoji: 'db');
      n.setSport(id: 's2', name: 'Padel', emoji: 'db');
      n.setRawLocation(name: 'Nad Al Sheba Sports Complex');
      n.setGame(id: 'g1', name: 'Padel doubles');
      await _settle(tester, 4);
      expect(tester.takeException(), isNull);
      expect(tester.widget<DabblerChip>(find.byType(DabblerChip)).emoji, '✨');
      expect(_badgeEmoji(tester, 'Padel'), '🎾');
      expect(l.composer_create_post, isNotEmpty);
      await _shoot(tester, 'filled-$lang');
    }, variant: desktop);
  }

  test('payload: no display emoji enters the post payload', () async {
    final _CapturingRepo repo = _CapturingRepo();
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[postRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final PostComposerNotifier n = c.read(postComposerProvider.notifier);
    final ProviderSubscription<PostComposerState> keep = c.listen(
      postComposerProvider,
      (_, __) {},
    );
    addTearDown(keep.close);
    n.setBody('Padel tonight');
    // A mapped vibe and sport; the database emoji is a distinct marker.
    n.setVibe(id: 'inspired', label: 'Inspired', emoji: 'DB-VIBE');
    n.setSport(id: 's2', name: 'Padel', emoji: 'DB-SPORT');
    await n.submit();
    final Map<String, dynamic> payload = repo.last!.toInsertPayload(
      authorProfileId: 'p',
      authorUserId: 'u',
    );
    // Baseline: the keys the request already carried before KAN-462.
    expect(payload['vibe_id'], 'inspired');
    expect(payload['sport_id'], 's2');
    expect(payload['body'], 'Padel tonight');
    expect(payload.keys.where((k) => k.contains('emoji')), isEmpty);
    final Set<String> display = <String>{
      ...composerVibeEmojiByKey.values,
      ...composerSportEmojiByKey.values,
      composerPlaceTagEmoji,
      composerGameTagEmoji,
    };
    final String flat = payload.values.join('|');
    for (final String e in display) {
      expect(flat.contains(e), isFalse, reason: e);
    }
    expect(flat.contains('DB-VIBE'), isFalse);
    expect(flat.contains('DB-SPORT'), isFalse);
    // The state keeps the database emoji it was given, untouched.
    expect(c.read(postComposerProvider).vibeEmoji, 'DB-VIBE');
    expect(c.read(postComposerProvider).sportEmoji, 'DB-SPORT');
  });
}
