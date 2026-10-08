import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/data/repositories/favorites_repository.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/utils/favourite_toast.dart';
import 'package:dabbler/features/games/presentation/widgets/games_listing_card.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// Favourite toasts (CEO 2026-10-08): the heart flips the card at once, then a
/// toast names the type (success on add, neutral on remove) from the server's
/// answer, or says it could not be updated and the card rolls back.
/// Renders go to `--dart-define=FAV_TOAST_DIR=<dir>`.
const String _dir = String.fromEnvironment(
  'FAV_TOAST_DIR',
  defaultValue: '$kShotsRoot/fav-toast/app',
);
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

class _Repo implements FavoritesRepository {
  _Repo(this.answer);
  final Result<FavoriteState, Failure> answer;
  final List<String> calls = <String>[];

  /// The server holds its answer until the test completes this.
  final Completer<void> gate = Completer<void>();

  @override
  Future<Result<FavoriteState, Failure>> toggle(
    FavoriteTarget target,
    String targetId,
  ) async {
    calls.add('${target.wire}:$targetId');
    await gate.future;
    return answer;
  }
}

NearbyGameModel _game({bool mine = false}) => NearbyGameModel(
  id: 'g1',
  title: 'Evening game',
  sportName: 'Football',
  scheduledAt: DateTime.now().add(const Duration(days: 1)),
  status: 'upcoming',
  distanceMeters: 0,
  playerCount: 6,
  spotsRemaining: 4,
  isPublic: true,
  favoriteCount: 4,
  favouritedByMe: mine,
  priceAed: 0,
);

Future<void> _pump(
  WidgetTester tester,
  Widget body,
  Locale locale, {
  List<Override> overrides = const <Override>[],
  double height = 640,
}) async {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => RepaintBoundary(
          key: const Key('shot'),
          child: DabblerToastProvider(child: child!),
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
  for (var i = 0; i < 4; i++) {
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

/// Fires the favourite toast once, after the first frame.
class _ShowOnce extends StatefulWidget {
  const _ShowOnce({required this.kind, required this.added});
  final FavouriteKind kind;
  final bool? added;

  @override
  State<_ShowOnce> createState() => _ShowOnceState();
}

class _ShowOnceState extends State<_ShowOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showFavouriteToast(context, widget.kind, added: widget.added),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

final _heart = find.byWidgetPredicate(
  (w) => w is DabblerFeedAction && w.icon == 'heart',
);

/// Whether the card's heart is drawn filled (bold) rather than outlined.
bool _filled(WidgetTester tester) =>
    tester.widget<DabblerFeedAction>(_heart).weight == DabblerIconWeight.bold;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  group('game card heart', () {
    List<Override> overrides(_Repo repo) => [
      favoritesRepositoryProvider.overrideWithValue(repo),
      favouriteSignedInProvider.overrideWithValue(true),
    ];

    for (final locale in const [Locale('en'), Locale('ar')]) {
      final l = lookupAppLocalizations(locale);
      final tag = locale.languageCode;

      testWidgets('add: count +1 at once, then the success toast - $tag', (
        tester,
      ) async {
        final repo = _Repo(const Ok((favourited: true, count: 5)));
        await _pump(
          tester,
          GamesListingCard(game: _game()),
          locale,
          overrides: overrides(repo),
        );
        expect(find.text('4'), findsOneWidget);
        expect(_filled(tester), isFalse);
        await tester.tap(_heart);
        await tester.pump();
        expect(find.text('5'), findsOneWidget);
        expect(_filled(tester), isTrue);
        expect(find.text(l.fav_toast_game_added), findsNothing);
        repo.gate.complete();
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(repo.calls, ['game:g1']);
        expect(find.text(l.fav_toast_game_added), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(_filled(tester), isTrue);
      });

      testWidgets('remove: count -1, then the removed toast - $tag', (
        tester,
      ) async {
        final repo = _Repo(const Ok((favourited: false, count: 3)));
        await _pump(
          tester,
          GamesListingCard(game: _game(mine: true)),
          locale,
          overrides: overrides(repo),
        );
        expect(_filled(tester), isTrue);
        await tester.tap(_heart);
        await tester.pump();
        expect(find.text('3'), findsOneWidget);
        expect(_filled(tester), isFalse);
        repo.gate.complete();
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text(l.fav_toast_game_removed), findsOneWidget);
        expect(_filled(tester), isFalse);
      });

      testWidgets('failure: rolls back and shows the error toast - $tag', (
        tester,
      ) async {
        final repo = _Repo(Err(Failure.from('boom')));
        await _pump(
          tester,
          GamesListingCard(game: _game()),
          locale,
          overrides: overrides(repo),
        );
        await tester.tap(_heart);
        await tester.pump();
        expect(find.text('5'), findsOneWidget);
        expect(_filled(tester), isTrue);
        repo.gate.complete();
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Rolled back: outline heart and the old count.
        expect(_filled(tester), isFalse);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('5'), findsNothing);
        expect(find.text(l.fav_toast_error), findsOneWidget);
      });
    }
  });

  test('toast spec: tone per outcome, text per type', () {
    final l = lookupAppLocalizations(const Locale('en'));
    for (final k in FavouriteKind.values) {
      final add = favouriteToastSpec(l, k, true);
      final rem = favouriteToastSpec(l, k, false);
      expect(add.tone, DabblerToastTone.success);
      expect(rem.tone, DabblerToastTone.neutral);
      expect(add.message, contains('added to favourites'));
      expect(rem.message, contains('removed from favourites'));
      expect(favouriteToastSpec(l, k, null).tone, DabblerToastTone.error);
    }
    expect(
      favouriteToastSpec(l, FavouriteKind.venue, true).message,
      'Venue added to favourites',
    );
    expect(
      favouriteToastSpec(l, FavouriteKind.meetup, false).message,
      'Meetup removed from favourites',
    );
  });

  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('ltr', const Locale('en')),
    ('rtl', const Locale('ar')),
  ]) {
    final String mode = _dark ? 'dark' : 'light';
    final lc = lookupAppLocalizations(locale);
    for (final (String tag, bool mine, Result<FavoriteState, Failure> answer)
        in <(String, bool, Result<FavoriteState, Failure>)>[
          ('add', false, const Ok((favourited: true, count: 5))),
          ('remove', true, const Ok((favourited: false, count: 3))),
          ('error', false, Err(Failure.from('boom'))),
        ]) {
      testWidgets('render game card + toast $tag $mode $dir', (tester) async {
        final repo = _Repo(answer)..gate.complete();
        await _pump(
          tester,
          Padding(
            padding: const EdgeInsets.all(DabblerSpacing.space6),
            child: GamesListingCard(game: _game(mine: mine)),
          ),
          locale,
          overrides: [
            favoritesRepositoryProvider.overrideWithValue(repo),
            favouriteSignedInProvider.overrideWithValue(true),
          ],
          height: 720,
        );
        await tester.tap(_heart);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final toast = switch (tag) {
          'add' => lc.fav_toast_game_added,
          'remove' => lc.fav_toast_game_removed,
          _ => lc.fav_toast_error,
        };
        expect(find.text(toast), findsOneWidget);
        // add: filled; remove: outline; error: rolled back to the start.
        expect(_filled(tester), tag == 'add' ? true : false);
        expect(tester.takeException(), isNull);
        await _shoot(tester, 'card-game-$tag-$dir');
      });
    }
    for (final kind in FavouriteKind.values) {
      for (final (String tag, bool? added) in <(String, bool?)>[
        ('add', true),
        ('remove', false),
        if (kind == FavouriteKind.game) ('error', null),
      ]) {
        testWidgets('render toast ${kind.name} $tag $mode $dir', (
          tester,
        ) async {
          await _pump(
            tester,
            _ShowOnce(kind: kind, added: added),
            locale,
            height: 220,
          );
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull);
          final l = lookupAppLocalizations(locale);
          final text = favouriteToastSpec(l, kind, added).message;
          expect(find.text(text), findsOneWidget);
          await _shoot(tester, 'toast-${kind.name}-$tag-$dir');
        });
      }
    }
  }
}
