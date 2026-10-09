import 'dart:io';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-460: the Create post shell and frame, measured against
/// `Home Feed.dc.html` "Create post" (`:470-1000`) at 393x852; and the same
/// kit widgets OUTSIDE that frame, which must keep their old measurements
/// (the game and meet-up composers share them).

Future<void> _loadFonts() async {
  await loadRenderFonts();
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

final List<Vibe> _vibes = <Vibe>[
  for (final v in DabblerVibe.values)
    Vibe(
      id: v.key,
      key: v.key,
      labelEn: v.label,
      labelAr: v.label,
      type: v.type.name,
    ),
];

final List<Override> _data = <Override>[
  vibesProvider.overrideWith((ref) async => _vibes),
  venueSearchProvider.overrideWith(
    (ref, q) async => <Map<String, dynamic>>[
      <String, dynamic>{'id': 'v1', 'name': 'Nad Al Sheba', 'city': 'Dubai'},
    ],
  ),
  gameSearchProvider.overrideWith(
    (ref, q) async => <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'g1',
        'title': 'Padel doubles',
        'sport': 'padel',
        'start_at': DateTime(2026, 8, 19, 19).toIso8601String(),
      },
    ],
  ),
  activeSportsByProfileCountryProvider.overrideWith(
    (ref) async => const <Sport>[
      Sport(id: 's1', nameEn: 'Football', sportKey: 'football'),
      Sport(id: 's2', nameEn: 'Padel', sportKey: 'padel'),
    ],
  ),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app({
  required Widget home,
  Locale locale = const Locale('en'),
  List<Override> overrides = const <Override>[],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => DabblerToastProvider(child: child!),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: DabblerDesignSystemTheme.withFonts(
      DabblerDesignSystemTheme.withTokens(renderThemeBase()),
      locale: locale,
    ),
    home: home,
  ),
);

/// The Create post route frame, as the app opens it.
Widget _createPost({Locale locale = const Locale('en')}) => _app(
  locale: locale,
  overrides: _data,
  home: Navigator(
    pages: <Page<void>>[
      const MaterialPage<void>(child: DabblerPage(body: SizedBox.expand())),
      AdaptiveModalPage(child: const PostComposerScreen()),
    ],
    onDidRemovePage: (page) {},
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  group('Create post frame (design-frame ON)', () {
    testWidgets('surface, handle, gutter, rows, Post block', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_createPost());
      await _settle(tester);
      expect(tester.takeException(), isNull);

      final BuildContext ctx = tester.element(find.byType(PostComposerScreen));
      final DabblerColors colors = DabblerColors.of(ctx);

      // Sheet surface is the page colour (`--surface-page`), not the card.
      final Container surface = tester.widget<Container>(
        find.byKey(const ValueKey<String>('composer-frame-surface')),
      );
      expect((surface.decoration! as BoxDecoration).color, colors.bgPrimary);
      expect(colors.bgPrimary, isNot(colors.surfaceCard));

      // Drag handle: 40x4, centred, in its own 45dp row.
      final Finder bar = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == DabblerSheet.handleWidth &&
            w.constraints?.maxHeight == DabblerSheet.handleHeight,
      );
      expect(bar, findsOneWidget);
      final Rect barRect = tester.getRect(bar);
      expect(barRect.size, const Size(40, 4));
      expect(barRect.center.dx, closeTo(393 / 2, 0.01));

      // Gutter: 18dp inside the sheet's 1dp hairline (design: avatar at 19).
      final Rect surfaceRect = tester.getRect(
        find.byKey(const ValueKey<String>('composer-frame-surface')),
      );
      expect(
        tester.getRect(find.byType(DabblerAvatar)).left - surfaceRect.left,
        19,
      );
      expect(
        surfaceRect.right - tester.getRect(find.byType(DabblerComposerBox)).right,
        19,
      );

      // Option rows: 64dp with the hairline, the last 63 (no hairline).
      final List<ComposerSettingsRow> rows = tester
          .widgetList<ComposerSettingsRow>(find.byType(ComposerSettingsRow))
          .toList();
      expect(rows, hasLength(3));
      final Finder rowFinder = find.byType(ComposerSettingsRow);
      expect(tester.getSize(rowFinder.at(0)).height, 64);
      expect(tester.getSize(rowFinder.at(1)).height, 64);
      expect(tester.getSize(rowFinder.at(2)).height, 63);

      // Post: inside the scroll area, 48dp pill, hairline above, 12 / 24 pad,
      // 15dp below the options, 18dp of scroll padding after.
      final Finder post = find.widgetWithText(
        DabblerButton,
        lookupAppLocalizations(const Locale('en')).composer_post_cta,
      );
      expect(post, findsOneWidget);
      expect(
        find.ancestor(of: post, matching: find.byType(SingleChildScrollView)),
        findsOneWidget,
        reason: 'the Post button scrolls with the content, it is not pinned',
      );
      await tester.ensureVisible(post);
      await tester.pump();
      final Rect postRect = tester.getRect(post);
      expect(postRect.height, 48);
      // The scroll content ends 24 (block) + 18 (scroll padding) + 18 (sheet
      // body padding) under the pill. Measured on the content column, so it
      // holds whether or not this draft scrolls.
      final Finder content = find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Column),
          )
          .first;
      final Rect postEnd = tester.getRect(post);
      expect(tester.getRect(content).bottom - postEnd.bottom, 24 + 18 + 18);
      // On a phone the sheet is its 94% cap even with an empty draft
      // (`Home Feed.dc.html` measured 800.9 of 852).
      expect(surfaceRect.height, closeTo(852 * 0.94, 1.0));
      expect(surfaceRect.bottom, 852);
      // Hairline: 12dp above the pill, 1dp, in the faint colour, 18dp inset.
      final Finder hairline = find.ancestor(
        of: post,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).border is Border &&
              ((w.decoration! as BoxDecoration).border! as Border).top.color ==
                  colors.bgTertiary &&
              ((w.decoration! as BoxDecoration).border! as Border).top.width == 1 &&
              ((w.decoration! as BoxDecoration).border! as Border).bottom ==
                  BorderSide.none,
        ),
      );
      expect(hairline, findsOneWidget);
      expect(tester.getRect(hairline).top, postEnd.top - 12 - 1);
      expect(tester.getRect(hairline).left - surfaceRect.left, 19);
      // 15dp from the last option row to the hairline.
      expect(
        tester.getRect(hairline).top - tester.getRect(rowFinder.at(2)).bottom,
        15,
      );
    }, variant: desktop);

    testWidgets('sheets: header hairline where drawn, Clear, search, Dab glyph',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_createPost());
      await _settle(tester);
      final AppLocalizations l = lookupAppLocalizations(const Locale('en'));
      final DabblerColors colors = DabblerColors.of(
        tester.element(find.byType(PostComposerScreen)),
      );

      /// Whether the open sheet draws the 1dp `--faint` hairline under its
      /// header (the DS sheet's own `headerDivider`).
      bool headerHairline() =>
          tester.widget<DabblerSheet>(find.byType(DabblerSheet)).headerDivider;

      Future<void> close() async {
        await tester.tapAt(const Offset(10, 10));
        await _settle(tester);
      }

      // kind sheet: hairline, Dab row glyph filled (bold) and brand title.
      await tester.tap(find.text(l.composer_type_dab));
      await _settle(tester);
      expect(headerHairline(), isTrue, reason: 'kind sheet');
      final DabblerIcon dab = tester.widget<DabblerIcon>(
        find.descendant(
          of: find.byType(DabblerSheet),
          matching: find.byWidgetPredicate(
            (w) => w is DabblerIcon && w.name == 'like-1',
          ),
        ),
      );
      expect(dab.weight, DabblerIconWeight.bold);
      expect(dab.color, colors.brandPrimary);
      await close();

      // visibility sheet.
      await tester.tap(find.text(l.composer_vis_public));
      await _settle(tester);
      expect(headerHairline(), isTrue, reason: 'visibility sheet');
      await close();

      // media sheet.
      await tester.tap(find.bySemanticsLabel(l.composer_add_media));
      await _settle(tester);
      expect(headerHairline(), isTrue, reason: 'media sheet');
      await close();

      // sport sheet (shared with the game composer, opened from Create post).
      await tester.tap(find.bySemanticsLabel(l.composer_add_sport));
      await _settle(tester);
      expect(headerHairline(), isTrue, reason: 'sport sheet');
      await close();

      // game sheet: hairline, muted 13/18 Clear (not a button), 42dp search.
      await tester.tap(find.bySemanticsLabel(l.composer_link_game));
      await _settle(tester);
      expect(headerHairline(), isTrue, reason: 'game sheet');
      await close();

      // vibe and place sheets: the design draws NO header hairline.
      await tester.tap(find.bySemanticsLabel(l.composer_add_vibe));
      await _settle(tester);
      expect(headerHairline(), isFalse, reason: 'vibe sheet has none');
      // 42dp search at the sheet's own 18dp gutter.
      final Finder search = find.byType(DabblerTextField);
      expect(search, findsOneWidget);
      expect(tester.getSize(search).height, 42);
      expect(
        tester.getRect(search).left - tester.getRect(find.byType(DabblerSheet)).left,
        18 + 1,
        reason: 'gutter 18 + the panel hairline',
      );
      await close();

      await tester.tap(find.bySemanticsLabel(l.composer_add_location));
      await _settle(tester);
      expect(headerHairline(), isFalse, reason: 'place sheet has none');
      await close();
    }, variant: desktop);

    testWidgets('Clear is a muted 13/18 word, not a text button',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_createPost());
      await _settle(tester);
      final AppLocalizations l = lookupAppLocalizations(const Locale('en'));
      final PostComposerNotifier n = ProviderScope.containerOf(
        tester.element(find.byType(PostComposerScreen)),
      ).read(postComposerProvider.notifier);
      n.setSport(id: 's2', name: 'Padel', emoji: '');
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('Sport: Padel')));
      await _settle(tester);
      final Finder clear = find.text(l.composer_clear);
      expect(clear, findsOneWidget);
      expect(
        find.ancestor(of: clear, matching: find.byType(DabblerButton)),
        findsNothing,
      );
      final Text text = tester.widget<Text>(clear);
      final DabblerColors colors = DabblerColors.of(
        tester.element(find.byType(PostComposerScreen)),
      );
      expect(text.style!.fontSize, 13);
      expect(text.style!.height! * text.style!.fontSize!, closeTo(18, 0.01));
      expect(text.style!.color, colors.textSecondary);
    }, variant: desktop);
  });

  // The same kit widgets with NO frame scope: what the game and meet-up
  // composers (and the GIF picker) draw. These pin the pre-KAN-460 numbers.
  group('kit defaults outside Create post are unchanged', () {
    testWidgets('ComposerDrawerShell: 24dp gutter, pinned Post, ink Clear',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          home: Align(
            alignment: Alignment.bottomCenter,
            child: ComposerDrawerShell(
              title: 'Create game',
              ctaLabel: 'Go',
              onCtaTap: () {},
              children: const <Widget>[
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: 24),
                  child: ComposerSettingsRow(
                    icon: 'share',
                    title: 'Allow reposts',
                    subtitle: 'Others can share this post',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      // No frame scope was provided.
      expect(find.byType(ComposerFrameScope), findsNothing);
      // 74dp row (14 + 22.5 + 19.5 + 14 + hairline), sunken-card form.
      expect(
        tester.getSize(find.byType(ComposerSettingsRow)).height,
        closeTo(74, 0.01),
      );
      // Title row starts at the shell's 24dp gutter, with no handle.
      expect(tester.getRect(find.text('Create game')).left, 24);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == DabblerSheet.handleWidth,
        ),
        findsNothing,
      );
      // The CTA is pinned below the scroll area, not inside it.
      expect(
        find.ancestor(
          of: find.widgetWithText(DabblerButton, 'Go'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      // No page-colour panel was painted.
      expect(
        find.byKey(const ValueKey<String>('composer-frame-surface')),
        findsNothing,
      );
    }, variant: desktop);

    testWidgets('showComposerSheet / Clear / search field / picker row',
        (tester) async {
      _phone(tester);
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);
      late BuildContext opener;
      await tester.pumpWidget(
        _app(
          home: Builder(
            builder: (context) {
              opener = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      showComposerSheet<void>(
        opener,
        title: 'Which sport?',
        onClear: () {},
        confirm: ComposerSheetConfirm(label: 'Confirm', onTap: () {}),
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ComposerSearchField(
              controller: c,
              placeholder: 'Search',
              onChanged: (_) {},
            ),
            ComposerPickerRow(
              icon: 'like-1',
              title: 'Dab',
              selected: true,
              onTap: () {},
            ),
          ],
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      // No header hairline.
      final DabblerSheetRoute<void> route = ModalRoute.of(
        tester.element(find.byType(DabblerSheet)),
      )! as DabblerSheetRoute<void>;
      expect(route.headerDivider, isFalse);
      // Clear is still the text-tone DabblerButton (ink), under the old chrome.
      final Finder clear = find.widgetWithText(DabblerButton, 'Clear');
      expect(clear, findsOneWidget);
      expect(tester.widget<DabblerButton>(clear).tone, DabblerButtonTone.text);
      // Search field: 45dp (touch metrics) and 18 + 18 inset inside the sheet.
      expect(tester.getSize(find.byType(DabblerTextField)).height, 45);
      expect(
        tester.getRect(find.byType(DabblerTextField)).left -
            tester.getRect(find.byType(DabblerSheet)).left,
        36,
      );
      // Picker row: selected glyph stays linear, title stays the ink Text.
      final DabblerIcon dab = tester.widget<DabblerIcon>(
        find.byWidgetPredicate((w) => w is DabblerIcon && w.name == 'like-1'),
      );
      expect(dab.weight, DabblerIconWeight.linear);
      expect(find.text('Dab'), findsOneWidget);
    }, variant: desktop);
  });
}
