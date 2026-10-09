import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_sheet_page.dart';
import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/social/presentation/screens/post_composer_screen.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_game_link_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_vibes_sheet.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// Renders the composer sheet bodies (media rail, location picker, link-a-game
/// picker, format body, date and time bodies) in LTR and RTL. Writes PNGs only
/// with `--dart-define=SHEET_SHOTS_DIR=<dir>`.
const String _shotsDir = String.fromEnvironment('SHEET_SHOTS_DIR');

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

const List<Map<String, dynamic>> _venues = [
  {'id': 'v1', 'name': 'Nad Al Sheba Sports Complex', 'city': 'Nad Al Sheba'},
  {'id': 'v2', 'name': 'Al Warqa Practice Nets', 'city': 'Al Warqa'},
];

final List<Map<String, dynamic>> _games = [
  {
    'id': 'g1',
    'title': 'Friday 5-a-side',
    'sport': 'football',
    'start_at': DateTime(2026, 8, 18, 20).toIso8601String(),
  },
  {
    'id': 'g2',
    'title': 'Padel doubles',
    'sport': 'padel',
    'start_at': DateTime(2026, 8, 19, 19).toIso8601String(),
  },
];

const List<Vibe> _vibes = [
  Vibe(id: 'b1', key: 'supportive', labelEn: 'Supportive', labelAr: 'داعم'),
  Vibe(id: 'b2', key: 'caring', labelEn: 'Caring', labelAr: 'مهتم'),
  Vibe(id: 'b3', key: 'excited', labelEn: 'Excited', labelAr: 'متحمس'),
];

const List<Map<String, dynamic>> _variants = [
  {'id': 'f1', 'name_en': 'Futsal 5s', 'required_players': 10},
  {'id': 'f2', 'name_en': 'Small-sided 7s', 'required_players': 14},
  {'id': 'f3', 'name_en': 'Standard', 'required_players': 22},
];

Future<void> _host(
  WidgetTester tester,
  Locale locale,
  Key key,
  Widget Function(BuildContext, WidgetRef) home,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        venueSearchProvider.overrideWith((ref, q) async => _venues),
        gameSearchProvider.overrideWith((ref, q) async => _games),
        composerJoinedGamesProvider.overrideWith((ref) async => _games),
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
        home: DabblerPage(
          body: Consumer(builder: (context, ref, _) => home(context, ref)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _sportsProvider = Provider<AsyncValue<List<Sport>>>(
  (ref) => const AsyncData([
    Sport(id: 's1', nameEn: 'Football', sportKey: 'football'),
    Sport(id: 's2', nameEn: 'Padel', sportKey: 'padel'),
    Sport(id: 's3', nameEn: 'Gym', sportKey: 'gym'),
    Sport(id: 's4', nameEn: 'Cricket', sportKey: 'cricket'),
  ]),
);

Future<void> _loadFonts() => loadRenderFonts();

/// The DabblerSheet the Create game route pushes (GameComposerSheetPage),
/// built inline for a test with no route.
Widget _gameSheet(Widget child, {bool editing = false}) => Builder(
  builder: (context) => DabblerSheet(
    onClose: () => Navigator.of(context).maybePop(),
    detent: DabblerSheetDetent.content,
    contentMaxFraction: DabblerSheet.contentMaxFractionFull,
    pageBackground: true,
    showCloseButton: false,
    titleWidget: GameComposerSheetTitle(editing: editing),
    headerAction: GameComposerCancel(
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    child: child,
  ),
);

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await _loadFonts();
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final l = lookupAppLocalizations(locale);
    final isAr = locale.languageCode == 'ar';
    const key = Key('shot');

    testWidgets('media rail — $dir', (tester) async {
      await _host(
        tester,
        locale,
        key,
        (_, __) => const Align(
          alignment: Alignment.bottomCenter,
          child: PostComposerScreen(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PostComposerScreen)),
      );
      final notifier = container.read(postComposerProvider.notifier);
      notifier.addMediaUrl('https://example.invalid/a.jpg');
      notifier.addMediaUrl('https://example.invalid/b.jpg');
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerAttachmentAddTile), findsOneWidget);
      expect(find.byType(DabblerAttachmentChip), findsNWidgets(2));
      await _shoot(tester, key, 'sheet-media-rail-$dir');
    });

    testWidgets('location picker — $dir', (tester) async {
      await _host(
        tester,
        locale,
        key,
        (context, ref) => Center(
          child: DabblerButton(
            label: 'open',
            onPressed: () => showComposerPlaceSheet(context, ref),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      // KAN-465: title and search hint come from the ARB in both locales.
      expect(find.text(l.composer_add_location), findsWidgets);
      expect(find.text(l.composer_place_search), findsOneWidget);
      expect(find.text(isAr ? 'إضافة موقع' : 'Add location'), findsWidgets);
      expect(
        find.text(isAr ? 'ابحث عن ملاعب ومناطق' : 'Search venues and areas'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(EditableText), 'Nad');
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Nad Al Sheba Sports Complex'), findsOneWidget);
      expect(find.text(l.composer_results), findsOneWidget);
      await _shoot(tester, key, 'sheet-location-$dir');
      await _shoot(tester, key, 'kan465-place-$dir');
    });

    testWidgets('link a game picker — $dir', (tester) async {
      await _host(
        tester,
        locale,
        key,
        (context, ref) => Center(
          child: DabblerButton(
            label: 'open',
            onPressed: () => showComposerGameLinkSheet(context, ref),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      // KAN-465: the subtitle is the "games you have joined" hint, localized.
      expect(find.text(l.composer_link_a_game), findsWidgets);
      expect(
        find.text(
          isAr ? 'المباريات التي انضممت إليها' : 'Games you have joined',
        ),
        findsOneWidget,
      );
      expect(find.text(l.composer_games_hint), findsNothing);
      expect(find.text(l.composer_games_search), findsOneWidget);
      await _shoot(tester, key, 'kan465-game-$dir');
      await tester.enterText(find.byType(EditableText), 'Fri');
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerGameLinkRow), findsNWidgets(2));
      await tester.tap(find.byType(DabblerGameLinkRow).first);
      await _settle(tester);
      await _shoot(tester, key, 'sheet-link-game-$dir');
    });

    testWidgets('KAN-465 vibe sheet strings — $dir', (tester) async {
      await _host(tester, locale, key, (context, ref) {
        ref.watch(vibesProvider);
        return Center(
          child: DabblerButton(
            label: 'open',
            onPressed: () => showComposerVibesSheet(
              context,
              ref,
              selectedVibeId: 'b2',
              kindLabel: l.composer_type_dab,
              onConfirm: (_) {},
              onClear: () {},
            ),
          ),
        );
      });
      await _settle(tester);
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text(isAr ? 'ما الأجواء؟' : "What's the vibe?"),
        findsWidgets,
      );
      expect(
        find.text(isAr ? '3 أجواء لنوع «داب»' : '3 vibes for dab'),
        findsOneWidget,
      );
      expect(find.text(l.composer_vibe_search), findsOneWidget);
      expect(find.text(l.composer_confirm), findsOneWidget);
      expect(find.text(isAr ? 'داعم' : 'Supportive'), findsOneWidget);
      if (isAr) {
        expect(find.textContaining('vibes'), findsNothing);
        expect(find.text("What's the vibe?"), findsNothing);
      }
      await _shoot(tester, key, 'kan465-vibe-$dir');
    });

    testWidgets('format body — $dir', (tester) async {
      final pending = ValueNotifier<Map<String, dynamic>?>(_variants[1]);
      await _host(
        tester,
        locale,
        key,
        (context, ref) => Center(
          child: DabblerButton(
            label: 'open',
            onPressed: () => showComposerSheet<void>(
              context,
              title: l.composer_format_title('Football'),
              confirm: ComposerSheetConfirm(
                label: l.composer_confirm,
                onTap: () {},
              ),
              builder: (_) =>
                  ComposerVariantSheet(variants: _variants, pending: pending),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Small-sided 7s'), findsOneWidget);
      await _shoot(tester, key, 'sheet-format-$dir');
    });

    testWidgets('date and time bodies — $dir', (tester) async {
      await _host(
        tester,
        locale,
        key,
        (_, __) => _gameSheet(const GameComposerScreen()),
      );
      await tester.tap(find.text(l.game_date));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l.composer_pick_date), findsOneWidget);
      expect(find.text(l.composer_step_1), findsOneWidget);
      expect(find.byType(DabblerCalendar), findsOneWidget);
      await _shoot(tester, key, 'sheet-date-$dir');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      await tester.tap(find.text(l.game_time));
      await _settle(tester);
      expect(find.text(l.composer_pick_time), findsOneWidget);
      expect(find.byType(DabblerTimePicker), findsOneWidget);
      await _shoot(tester, key, 'sheet-time-$dir');
    });

    testWidgets('sport sheet — $dir', (tester) async {
      await _host(
        tester,
        locale,
        key,
        (context, ref) => Center(
          child: DabblerButton(
            label: 'open',
            onPressed: () => showComposerSportSheet(
              context,
              title: l.composer_which_sport,
              sportsProvider: _sportsProvider,
              selected: const Sport(id: 's2', nameEn: 'Padel'),
              showClear: true,
              onClear: () {},
              onConfirm: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Football'), findsOneWidget);
      await _shoot(tester, key, 'sheet-sport-$dir');
    });

    testWidgets('type and audience sheets — $dir', (tester) async {
      await _host(
        tester,
        locale,
        key,
        (context, ref) => Center(
          child: DabblerButton(
            label: 'open',
            onPressed: () => showComposerChoiceSheet<int>(
              context,
              title: l.composer_kind_of_post,
              selected: 1,
              onConfirm: (_) {},
              choices: [
                ComposerChoice(
                  value: 0,
                  icon: 'flash',
                  title: l.composer_type_moment,
                  subtitle: l.composer_type_moment_sub,
                ),
                ComposerChoice(
                  value: 1,
                  icon: 'like-1',
                  title: l.composer_type_dab,
                  subtitle: l.composer_type_dab_sub,
                ),
                ComposerChoice(
                  value: 2,
                  icon: 'people',
                  title: l.composer_type_kickin,
                  subtitle: l.composer_type_kickin_sub,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l.composer_type_dab), findsOneWidget);
      await _shoot(tester, key, 'sheet-type-$dir');
    });
  }

  test('KAN-465 game_select_sport_first wording', () {
    expect(
      lookupAppLocalizations(const Locale('en')).game_select_sport_first,
      'Pick a sport first',
    );
    expect(
      lookupAppLocalizations(const Locale('ar')).game_select_sport_first,
      'اختر رياضة أولًا',
    );
  });

  // KAN-456: the composer tag row draws vibe, sport, location and game at one
  // height, at phone width, both directions and both brightnesses.
  for (final bool dark in const <bool>[false, true]) {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
      final String mode = dark ? 'dark' : 'light';
      testWidgets('KAN-456 tag row: equal heights — $dir $mode', (
        tester,
      ) async {
        const key = Key('kan456-tags');
        tester.view.physicalSize = const Size(360, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: DabblerDesignSystemTheme.withTokens(
              dark ? ThemeData.dark() : ThemeData.light(),
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: composerTagRow(
                    vibeName: 'Disappointed',
                    sportName: 'Gym',
                    locationName: 'al quoz',
                    gameName:
                        'Friday night 5-a-side at Nad Al Sheba Sports Complex',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final vibe = find.byType(DabblerChip);
        final badges = find.byType(DabblerBadge);
        expect(vibe, findsOneWidget);
        expect(badges, findsNWidgets(3));
        expect(find.text('Gym'), findsOneWidget);
        final double h = tester.getSize(vibe).height;
        for (final Element e in badges.evaluate()) {
          expect((e.renderObject! as RenderBox).size.height, h);
        }
        // The long game label wraps onto its own run without overflowing.
        final Rect row = tester.getRect(find.byType(Wrap));
        final Rect game = tester.getRect(badges.last);
        expect(game.top, greaterThan(tester.getRect(vibe).top));
        expect(game.left, greaterThanOrEqualTo(row.left));
        expect(game.right, lessThanOrEqualTo(row.right));
        await _shoot(tester, key, 'kan456-tags-$dir-$mode');
      });
    }
  }

  test('KAN-456 tag row: nothing set draws no row', () {
    expect(composerTagRow(), isNull);
  });

  // KAN-459: the design draws the tags sport, vibe, location, game
  // (`Home Feed.dc.html:3264-3269`) with the labels as written.
  testWidgets('KAN-459 tag row: design order, labels as written', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        home: Scaffold(
          body: composerTagRow(
            vibeName: 'Inspired',
            sportName: 'Padel',
            locationName: 'Nad Al Sheba',
            gameName: 'Padel doubles',
          ),
        ),
      ),
    );
    expect(find.text('PADEL'), findsNothing);
    final double padel = tester.getTopLeft(find.text('Padel').first).dx;
    final double vibe = tester.getTopLeft(find.text('Inspired')).dx;
    final double place = tester.getTopLeft(find.text('Nad Al Sheba')).dx;
    expect(padel, lessThan(vibe));
    expect(vibe, lessThan(place));
  });
}
