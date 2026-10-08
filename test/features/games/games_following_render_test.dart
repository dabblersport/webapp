import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/widgets/games_listing_card.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import '../../support/render_mode.dart';

/// The games card's "N following" note (CEO 2026-10-08): spots + following,
/// a full game with following only, and a card with no following note.
/// Writes `games-following-{ltr|rtl}-{light|dark}.png`; the dark set comes
/// from a run with `--dart-define=RENDER_DARK=1`.
const String _dir = String.fromEnvironment(
  'GAMES_FOLLOWING_DIR',
  defaultValue: '$kShotsRoot/games-following',
);

List<NearbyGameModel> _cards() {
  final DateTime now = DateTime.now();
  return <NearbyGameModel>[
    NearbyGameModel(
      id: 'f1',
      title: 'Tuesday 5-a-side',
      sportName: 'Football',
      scheduledAt: now.add(const Duration(days: 1)),
      venueName: 'Dubai Sports City',
      distanceMeters: 3100,
      playerCount: 7,
      spotsRemaining: 3,
      isPublic: true,
      endAt: now.add(const Duration(days: 1, minutes: 60)),
      followingJoined: 2,
    ),
    NearbyGameModel(
      id: 'f2',
      title: 'Padel doubles',
      sportName: 'Padel',
      scheduledAt: now.add(const Duration(days: 2)),
      venueName: 'Al Quoz Courts',
      distanceMeters: 1200,
      playerCount: 4,
      spotsRemaining: 0,
      minSkill: 2,
      maxSkill: 3,
      isPublic: true,
      endAt: now.add(const Duration(days: 2, minutes: 60)),
      followingJoined: 5,
    ),
    NearbyGameModel(
      id: 'f3',
      title: 'Weekend kickabout',
      sportName: 'Football',
      scheduledAt: now.add(const Duration(days: 3)),
      venueName: 'Al Barsha Pond Park',
      distanceMeters: 4100,
      playerCount: 5,
      spotsRemaining: 7,
      isPublic: true,
      endAt: now.add(const Duration(days: 3, minutes: 60)),
    ),
  ];
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    final AppLocalizations l = lookupAppLocalizations(locale);

    testWidgets('games following note - $dir', (tester) async {
      // A 320 px card: the narrowest phone less the listing gutters.
      tester.view.physicalSize = const Size(360, 980);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const Key key = Key('shot');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: DabblerDesignSystemTheme.withFonts(
              DabblerDesignSystemTheme.withTokens(renderThemeBase()),
              locale: locale,
            ),
            home: RepaintBoundary(
              key: key,
              child: DabblerPage(
                body: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: DabblerSpacing.space5,
                    vertical: DabblerSpacing.space5,
                  ),
                  child: Column(
                    spacing: DabblerSpacing.space4,
                    children: [
                      for (final NearbyGameModel g in _cards())
                        GamesListingCard(game: g),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settleImages(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          l.listing_note_join(
            l.listing_spots_left(3),
            l.listing_following_joined(2),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l.listing_following_joined(5)), findsOneWidget);
      expect(find.text(l.listing_spots_left(7)), findsOneWidget);
      expect(
        find.textContaining(l.listing_following_joined(7)),
        findsNothing,
      );

      final String mode =
          const String.fromEnvironment('RENDER_DARK') == '1' ? 'dark' : 'light';
      await tester.runAsync(() async {
        final RenderRepaintBoundary boundary =
            tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(_dir).createSync(recursive: true);
        File(
          '$_dir/games-following-$dir-$mode.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
