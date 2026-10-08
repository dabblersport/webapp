import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/games_listing_card.dart';
import 'package:dabbler/features/meetups/data/datasources/meetup_datasource.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_inputs.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_composer_screen.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_listing_card.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';
import '../meetups/meetup_screens_harness.dart';

/// CEO 2026-10-08: a game needs a price (AED, 0 is Free) to be created or saved;
/// a card shows "AED N" / "Free" / "Ask" (never Free for a game with no price);
/// a meetup earns "Popular" at half its capacity going (20 going with no cap);
/// a meetup with no venue must say Indoor or Outdoor.
/// Renders go to `--dart-define=PRICE_MEETUP_DIR=<dir>`.
const String _dir = String.fromEnvironment(
  'PRICE_MEETUP_DIR',
  defaultValue: '$kShotsRoot/price-meetup/app',
);
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

Future<void> _pump(
  WidgetTester tester,
  Widget body,
  Locale locale, {
  double height = 852,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activePersonaProvider.overrideWithValue(PersonaType.player),
        myProfileIdProvider.overrideWith((ref) async => 'me'),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: const Key('shot'), child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: Builder(
          builder: (context) => ColoredBox(
            color: DabblerColors.of(context).bgPrimary,
            child: SafeArea(
              child: Align(alignment: Alignment.topCenter, child: body),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final b =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

NearbyGameModel _game(double? price) => NearbyGameModel(
  id: 'g',
  title: 'Evening game',
  sportName: 'Football',
  scheduledAt: DateTime.now().add(const Duration(days: 1)),
  status: 'upcoming',
  venueName: 'Dubai Sports City',
  distanceMeters: 3100,
  playerCount: 6,
  spotsRemaining: 4,
  isPublic: true,
  priceAed: price,
);

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  group('migration', () {
    final sql = File(
      'supabase/migrations/20261008140000_game_price_meetup_setting.sql',
    ).readAsStringSync();
    test(
      'adds the columns, the guards and the view columns; drops nothing',
      () {
        expect(sql, contains('price_aed numeric(10,2)'));
        expect(sql, contains('CHECK (price_aed >= 0)'));
        expect(sql, contains('is_indoor boolean'));
        expect(sql, contains("message='price_required'"));
        expect(sql, contains("message='setting_required'"));
        expect(sql, contains('setting_is_indoor'));
        expect(sql, contains('p_max_price'));
        expect(
          RegExp(r'\bDROP\b', caseSensitive: false).hasMatch(sql),
          isFalse,
        );
      },
    );
  });

  group('model and copy', () {
    test('price_aed is read as a number; absent stays null', () {
      final m = NearbyGameModel.fromJson({
        'id': 'g',
        'title': 'T',
        'distance_meters': 0,
        'price_aed': 35,
      });
      expect(m.priceAed, 35.0);
      expect(
        NearbyGameModel.fromJson({'id': 'g', 'title': 'T'}).priceAed,
        isNull,
      );
      expect(m.withFavourite(favourited: true, count: 1).priceAed, 35.0);
    });

    test('Popular: half the capacity, or 20 going with no cap', () {
      expect(meetupIsPopular(goingCount: 4, capacity: 8), isTrue);
      expect(meetupIsPopular(goingCount: 3, capacity: 8), isFalse);
      expect(meetupIsPopular(goingCount: 25, capacity: 50), isTrue);
      expect(meetupIsPopular(goingCount: 24, capacity: 50), isFalse);
      expect(meetupIsPopular(goingCount: 20, capacity: null), isTrue);
      expect(meetupIsPopular(goingCount: 19, capacity: null), isFalse);
    });

    test('create params carry p_is_indoor only without a venue', () {
      CreateMeetupInput input({String? venue, bool? indoor}) =>
          CreateMeetupInput(
            sportId: 's',
            sportVariantId: 'v',
            title: 'Run',
            locationName: 'Park',
            startAt: DateTime.utc(2030),
            venueId: venue,
            isIndoor: indoor,
          );
      expect(
        MeetupRpcParams.create(input(indoor: false))['p_is_indoor'],
        false,
      );
      expect(MeetupRpcParams.create(input(indoor: true))['p_is_indoor'], true);
      expect(
        MeetupRpcParams.create(input(venue: 'x', indoor: true))['p_is_indoor'],
        isNull,
      );
    });
  });

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('ltr', const Locale('en')),
    ('rtl', const Locale('ar')),
  ]) {
    final String mode = _dark ? 'dark' : 'light';
    final bool ar = locale.languageCode == 'ar';
    final l = lookupAppLocalizations(locale);

    testWidgets('game composer: required price, empty-state error $mode $dir', (
      tester,
    ) async {
      await _pump(tester, const GameComposerScreen(), locale, height: 1700);
      final field = find.byWidgetPredicate(
        (w) => w is DabblerTextField && w.placeholder == l.game_price_hint,
      );
      expect(field, findsOneWidget);
      expect(find.text(l.game_price_sub), findsOneWidget);
      expect(find.text(l.game_price_required), findsNothing);
      final input = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      await tester.enterText(input, '35');
      await tester.pump();
      expect(find.text(l.game_price_required), findsNothing);
      // Emptying the field is the empty state: the error names the rule.
      await tester.enterText(input, '');
      await tester.pump();
      expect(find.text(l.game_price_required), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'game-composer-price-empty-$dir');
      await tester.enterText(input, '0');
      await tester.pump();
      expect(find.text(l.game_price_required), findsNothing);
      await _shoot(tester, 'game-composer-price-free-$dir');
    });

    for (final (String tag, double? price, String text) c
        in <(String, double?, String)>[
          ('aed', 35, l.listing_price_aed('35')),
          ('free', 0, l.listing_free),
          ('ask', null, l.listing_price_ask),
        ]) {
      testWidgets('game card price ${c.$1} $mode $dir', (tester) async {
        await _pump(
          tester,
          Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space6),
            child: GamesListingCard(game: _game(c.$2)),
          ),
          locale,
          height: 520,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(c.$3), findsOneWidget);
        if (c.$2 == null) {
          expect(find.text(l.listing_free), findsNothing);
          expect(find.text(c.$3), findsOneWidget);
        }
        await _shoot(tester, 'game-card-${c.$1}-$dir');
      });
    }

    testWidgets('meetup composer: Indoor/Outdoor required without a venue '
        '$mode $dir', (tester) async {
      final repo = FakeMeetupRepository();
      await _pump(
        tester,
        SingleChildScrollView(
          child: MeetupComposerScreen(
            initialDate: DateTime(2030, 1, 15),
            initialStart: const TimeOfDay(hour: 18, minute: 0),
            initialPlace: const ComposerPlacePick(name: 'Kite Beach'),
          ),
        ),
        locale,
        height: 1500,
        overrides: [meetupRepositoryProvider.overrideWithValue(repo)],
      );
      tester.takeException();
      expect(find.text(l.meetup_setting), findsOneWidget);
      expect(find.text(l.listing_indoor), findsOneWidget);
      expect(find.text(l.listing_outdoor), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, 'Sunrise run');
      await tester.pump();
      await tester.ensureVisible(find.byType(DabblerComposerSubmit));
      await tester.tap(find.byType(DabblerComposerSubmit));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(repo.createCalls, isEmpty);
      expect(find.text(l.meetup_setting_required), findsWidgets);
      await _shoot(tester, 'meetup-composer-setting-required-$dir');
      await tester.tap(find.text(l.listing_outdoor));
      await tester.pump();
      tester.takeException();
      expect(find.text(l.meetup_setting_sub), findsOneWidget);
      await _shoot(tester, 'meetup-composer-setting-chosen-$dir');
    });

    testWidgets('meetup card Popular tag $mode $dir', (tester) async {
      Widget card(String id, int going, int? cap) => Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space4),
        child: MeetupListingCard(
          meetup: meetupRow(id, going: going, capacity: cap),
          isIndoor: false,
        ),
      );
      await _pump(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              card('a', 24, 40),
              card('b', 3, 40),
              card('c', 22, null),
            ],
          ),
        ),
        locale,
        overrides: [
          meetupRepositoryProvider.overrideWithValue(FakeMeetupRepository()),
        ],
      );
      tester.takeException();
      // 24/40 and 22 with no cap are popular; 3/40 is not.
      expect(find.text(l.listing_popular), findsNWidgets(2));
      await _shoot(tester, 'meetup-card-popular-$dir');
      expect(ar, ar);
    });
  }
}
