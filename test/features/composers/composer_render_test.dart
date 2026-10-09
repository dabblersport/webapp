import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/page_transitions.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// Renders the post and game composers (and their DS sheets) to PNG with the
/// real bundled faces. Writes files only with
/// `--dart-define=COMPOSER_SHOTS_DIR=<dir>`; otherwise it still pumps every
/// frame and checks it renders cleanly.
const String _shotsDir = String.fromEnvironment('COMPOSER_SHOTS_DIR');

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


/// The full design vibe list (`DabblerVibe`), as the vibes table serves it.
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

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale,
  Key key, {
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibesProvider.overrideWith((ref) async => _vibes),
        ...extraOverrides,
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
        home: DabblerPage(
          body: Align(alignment: Alignment.bottomCenter, child: screen),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps [screen] inside the route frame the app opens it in
/// (`AdaptiveModalPage`: scrim, rounded surface, 94% cap) at 393x852.
Future<void> _pumpModal(
  WidgetTester tester,
  Widget screen,
  Locale locale,
  Key key, {
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibesProvider.overrideWith((ref) async => _vibes),
        ...extraOverrides,
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
        home: Navigator(
          pages: <Page<void>>[
            const MaterialPage<void>(
              child: DabblerPage(body: SizedBox.expand()),
            ),
            AdaptiveModalPage(child: screen),
          ],
          onPopPage: (route, result) => route.didPop(result),
        ),
      ),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('renders the post composer — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const PostComposerScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).composer_create_post), findsOneWidget);
      expect(find.byType(DabblerComposerBox), findsOneWidget);
      expect(find.text('Add GIF'), findsNothing);
      await _shoot(tester, key, 'post-$dir');
    }, variant: desktop);

    testWidgets('post composer: vibe picker sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const PostComposerScreen(), locale, key);
      await tester.tap(find.bySemanticsLabel(lookupAppLocalizations(locale).composer_add_vibe));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Happy'), findsWidgets);
      await _shoot(tester, key, 'post-vibes-$dir');
    }, variant: desktop);

    testWidgets('post composer: media + visibility sheets — $dir',
        (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const PostComposerScreen(), locale, key);
      await tester.tap(find.bySemanticsLabel(lookupAppLocalizations(locale).composer_add_media));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).composer_take_photo), findsOneWidget);
      await _shoot(tester, key, 'post-media-$dir');
    }, variant: desktop);

    testWidgets('renders the game composer — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const GameComposerScreen(), locale, key);
      expect(tester.takeException(), isNull);
      expect(find.text(lookupAppLocalizations(locale).game_create), findsWidgets);
      await _shoot(tester, key, 'game-$dir');
    }, variant: desktop);

    testWidgets('game composer: date sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const GameComposerScreen(), locale, key);
      await tester.tap(find.text(lookupAppLocalizations(locale).game_date));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerCalendar), findsOneWidget);
      await _shoot(tester, key, 'game-date-$dir');
    }, variant: desktop);

    testWidgets('game composer: time sheet — $dir', (tester) async {
      const Key key = Key('shot');
      await _pump(tester, const GameComposerScreen(), locale, key);
      await tester.tap(find.text(lookupAppLocalizations(locale).game_time));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTimePicker), findsOneWidget);
      await _shoot(tester, key, 'game-time-$dir');
    }, variant: desktop);
  }

  // KAN-459: the Create post states the design draws (`Home Feed.dc.html`
  // "Create post"), filled and with each picker open, at 393x852 in both
  // directions. Brightness follows `--dart-define=RENDER_DARK=1`.
  final List<Override> pickerData = <Override>[
    venueSearchProvider.overrideWith(
      (ref, q) async => <Map<String, dynamic>>[
        <String, dynamic>{'id': 'v1', 'name': 'Nad Al Sheba Sports Complex', 'city': 'Nad Al Sheba'},
        <String, dynamic>{'id': 'v2', 'name': 'Al Warqa Practice Nets', 'city': 'Al Warqa'},
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
        Sport(id: 's3', nameEn: 'Gym', sportKey: 'gym'),
        Sport(id: 's4', nameEn: 'Cricket', sportKey: 'cricket'),
      ],
    ),
  ];

  Future<void> fill(WidgetTester tester) async {
    final PostComposerNotifier n = ProviderScope.containerOf(
      tester.element(find.byType(PostComposerScreen)),
    ).read(postComposerProvider.notifier);
    await tester.enterText(
      find.byType(EditableText).first,
      'Anyone up for padel this Friday? Need two more #dabblerpadel',
    );
    n.setVibe(id: 'inspired', label: 'Inspired', emoji: '\u2728');
    n.setSport(id: 's2', name: 'Padel', emoji: '\u{1F3BE}');
    n.setRawLocation(name: 'Nad Al Sheba Sports Complex');
    n.setGame(id: 'g1', name: 'Padel doubles');
    n.addMediaUrl('https://example.invalid/a.jpg');
    n.addMediaUrl('https://example.invalid/b.jpg');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final AppLocalizations l = lookupAppLocalizations(locale);
    final bool rtl = locale.languageCode == 'ar';
    String iso(String v) => rtl ? '\u2068$v\u2069' : v;

    testWidgets('KAN-459 initial state — $dir', (tester) async {
      const Key key = Key('shot');
      await _pumpModal(tester, const PostComposerScreen(), locale, key,
          extraOverrides: pickerData);
      expect(tester.takeException(), isNull);
      expect(find.text(l.composer_create_post), findsOneWidget);
      expect(find.byType(DabblerChip), findsNothing);
      expect(find.byType(DabblerBadge), findsNothing);
      expect(find.byType(DabblerAttachmentAddTile), findsNothing);
      await _shoot(tester, key, 'kan459-initial-$dir');
    }, variant: desktop);

    testWidgets('KAN-459 filled state — $dir', (tester) async {
      const Key key = Key('shot');
      await _pumpModal(tester, const PostComposerScreen(), locale, key,
          extraOverrides: pickerData);
      await fill(tester);
      expect(tester.takeException(), isNull);
      // vibe chip, sport, location and game badges share one height.
      expect(find.byType(DabblerChip), findsOneWidget);
      expect(find.byType(DabblerBadge), findsNWidgets(3));
      expect(find.byType(DabblerAttachmentChip), findsNWidgets(2));

      // Vertical rhythm of `Home Feed.dc.html` Create post (393x852): 15dp
      // author -> pills -> card -> media rail, 18dp rail -> options; pills
      // draw before the card and the card's glyph row carries the five tools.
      final Rect avatar = tester.getRect(find.byType(DabblerAvatar));
      final Rect pills = tester.getRect(find.byType(DabblerSelectPill).first);
      final Rect box = tester.getRect(find.byType(DabblerComposerBox));
      final Rect rail = tester.getRect(find.byType(DabblerAttachmentAddTile));
      final Rect options = tester.getRect(find.byType(ComposerSettingsRow).first);
      expect(pills.top - avatar.bottom, 15);
      expect(box.top - pills.bottom, 15);
      expect(rail.top - box.bottom, 15);
      expect(options.top - rail.bottom, 18);
      // Only the vibe, sport, location and game tools take the active ink.
      final List<DabblerComposerTool> tools = tester
          .widget<DabblerComposerBox>(find.byType(DabblerComposerBox))
          .tools;
      expect(tools.map((t) => t.active), <bool>[false, true, true, true, true]);
      await _shoot(tester, key, 'kan459-filled-$dir');
    }, variant: desktop);

    testWidgets('KAN-459 pickers over the filled state — $dir', (tester) async {
      const Key key = Key('shot');
      await _pumpModal(tester, const PostComposerScreen(), locale, key,
          extraOverrides: pickerData);
      await fill(tester);

      Future<void> open(Finder f, String shot, {String? type}) async {
        await tester.tap(f);
        await settle(tester);
        if (type != null) {
          await tester.enterText(find.byType(EditableText).last, type);
          await settle(tester);
        }
        expect(tester.takeException(), isNull);
        await _shoot(tester, key, 'kan459-$shot-$dir');
        await tester.tapAt(const Offset(10, 10));
        await settle(tester);
      }

      // KAN-467: the tool labels are localized now, so find them by key.
      await open(find.bySemanticsLabel(l.composer_tool_vibe_set(iso('Inspired'))), 'vibe-sheet');
      await open(find.bySemanticsLabel(l.composer_tool_sport_set(iso('Padel'))), 'sport-sheet');
      await open(
          find.bySemanticsLabel(l.composer_tool_location_set(iso('Nad Al Sheba Sports Complex'))),
          'place-sheet',
          type: 'Nad');
      await open(find.bySemanticsLabel(l.composer_tool_game_set(iso('Padel doubles'))), 'game-sheet',
          type: 'Pad');
      await open(find.text(l.composer_type_dab), 'kind-sheet');
      await open(find.text(l.composer_vis_public), 'visibility-sheet');
      await open(find.bySemanticsLabel(l.composer_add_more_media), 'media-sheet');
    }, variant: desktop);
    testWidgets('KAN-467 localized labels, filled + GIF — $dir', (tester) async {
      const Key key = Key('shot');
      await _pumpModal(tester, const PostComposerScreen(), locale, key,
          extraOverrides: <Override>[
            ...pickerData,
            activeProfileTypeProvider.overrideWith((ref) => 'player'),
          ]);
      await fill(tester);
      ProviderScope.containerOf(tester.element(find.byType(PostComposerScreen)))
          .read(postComposerProvider.notifier)
          .addMediaUrl('https://example.invalid/c.gif');
      await settle(tester);
      expect(tester.takeException(), isNull);
      final String you = l.composer_you;
      final List<String> labels = <String>[
        l.composer_posting_as_switch(iso(you)),
        l.composer_tool_vibe_set(iso('Inspired')),
        l.composer_tool_sport_set(iso('Padel')),
        l.composer_tool_location_set(iso('Nad Al Sheba Sports Complex')),
        l.composer_tool_game_set(iso('Padel doubles')),
        l.composer_media_image,
        l.composer_media_gif,
      ];
      for (final String s in labels) {
        expect(find.bySemanticsLabel(s), findsWidgets, reason: s);
      }
      expect(find.text(l.composer_media_gif), findsOneWidget);
      if (rtl) {
        expect(labels.first, 'النشر باسم \u2068أنت\u2069. اضغط لتبديل الملف الشخصي.');
        expect(labels[1], 'الأجواء: \u2068Inspired\u2069. اضغط للتغيير.');
        expect(l.composer_media_image, 'صورة');
        for (final String s in labels) {
          expect(RegExp('Vibe:|Sport:|Location:|Game:|Posting as|Tap to').hasMatch(s), isFalse);
        }
      } else {
        // English is byte-identical to the pre-KAN-467 hardcoded strings.
        expect(labels, <String>[
          'Posting as You. Tap to switch profile.',
          'Vibe: Inspired. Tap to change.',
          'Sport: Padel. Tap to change.',
          'Location: Nad Al Sheba Sports Complex. Tap to change.',
          'Game: Padel doubles. Tap to change.',
          'Image',
          'GIF',
        ]);
        expect(labels.join().contains(RegExp('[\u2066-\u2069]')), isFalse);
      }
      await _shoot(tester, key, 'kan467-filled-$dir');
    }, variant: desktop);

    testWidgets('KAN-467 "set" fallback + no-switch label — $dir', (tester) async {
      await _pumpModal(tester, const PostComposerScreen(), locale, const Key('shot'),
          extraOverrides: pickerData);
      final PostComposerNotifier n = ProviderScope.containerOf(
        tester.element(find.byType(PostComposerScreen)),
      ).read(postComposerProvider.notifier);
      n.setVibe(id: 'inspired', label: null, emoji: '\u2728');
      await settle(tester);
      expect(find.bySemanticsLabel(l.composer_posting_as(iso(l.composer_you))), findsWidgets);
      final String vibe = l.composer_tool_vibe_set(iso(l.composer_tool_value_set));
      expect(find.bySemanticsLabel(vibe), findsWidgets);
      if (!rtl) {
        expect(l.composer_posting_as(l.composer_you), 'Posting as You');
        expect(vibe, 'Vibe: set. Tap to change.');
      } else {
        expect(vibe, 'الأجواء: \u2068تم التحديد\u2069. اضغط للتغيير.');
      }
    }, variant: desktop);

    // The Content Class sheet is unreachable today (its row is hidden and
    // `_showContentClassPicker` is private), so assert the source wires the
    // keys and render the same rows with the same keys for review.
    testWidgets('KAN-467 Content Class sheet keys — $dir', (tester) async {
      final String src = File(
        'lib/features/social/presentation/screens/post_composer_screen.dart',
      ).readAsStringSync();
      for (final String old in <String>[
        "'Content Class'", "'Standard social post'",
        "'Editorial or long-form content'", "'Posting as", "Tap to change.'",
        "'GIF'", "'Image'",
      ]) {
        expect(src.contains(old), isFalse, reason: old);
      }
      for (final String k in <String>[
        'composer_content_class_title', 'composer_content_class_social',
        'composer_content_class_editorial', 'composer_content_class_social_sub',
        'composer_content_class_editorial_sub',
      ]) {
        expect(src.contains('.$k'), isTrue, reason: k);
      }
      const Key key = Key('shot');
      await _pumpModal(tester, const PostComposerScreen(), locale, key,
          extraOverrides: pickerData);
      showComposerSheet<void>(
        tester.element(find.byType(PostComposerScreen)),
        title: l.composer_content_class_title,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ComposerPickerRow(icon: 'people', title: l.composer_content_class_social,
                subtitle: l.composer_content_class_social_sub, selected: true, onTap: () {}),
            ComposerPickerRow(icon: 'document-text', title: l.composer_content_class_editorial,
                subtitle: l.composer_content_class_editorial_sub, selected: false, onTap: () {}),
          ],
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l.composer_content_class_title), findsOneWidget);
      if (!rtl) {
        expect(<String>[l.composer_content_class_title, l.composer_content_class_social,
            l.composer_content_class_editorial, l.composer_content_class_social_sub,
            l.composer_content_class_editorial_sub],
            <String>['Content Class', 'Social', 'Editorial', 'Standard social post',
            'Editorial or long-form content']);
      } else {
        expect(find.text('فئة المحتوى'), findsOneWidget);
        expect(find.text('منشور اجتماعي عادي'), findsOneWidget);
      }
      await _shoot(tester, key, 'kan467-content-class-$dir');
    }, variant: desktop);
  }
}
