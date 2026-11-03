// KAN-698: series fields of the game card, the series badge (LTR and RTL) and
// the outcomes of the series RPCs. No network, nothing is written anywhere.
import 'package:dabbler/features/games/data/repositories/game_series_repository.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/features/games/presentation/screens/join_game/game_series_widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

Map<String, dynamic> _card({Map<String, dynamic> extra = const {}}) => {
  'id': 'g1',
  'title': 'Sunday football',
  'start_at': '2026-11-08T16:00:00Z',
  'end_at': '2026-11-08T17:00:00Z',
  'capacity': 10,
  ...extra,
};

Widget _host(GameView game, Locale locale) => MaterialApp(
  locale: locale,
  theme: DabblerDesignSystemTheme.withFonts(
    DabblerDesignSystemTheme.withTokens(renderThemeBase()),
    locale: locale,
  ),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) =>
          gameSeriesBadge(context, game) ?? const SizedBox.shrink(),
    ),
  ),
);

void main() {
  test('a one-off game has no series fields (TC1)', () {
    final game = GameView.fromJson(_card());
    expect(game.isSeries, isFalse);
    expect(game.seriesFrequency, isNull);
    expect(game.seriesEndsOn, isNull);
  });

  test('series fields are read from the card', () {
    final game = GameView.fromJson(
      _card(
        extra: {
          'series_id': 's1',
          'series_frequency': 'biweekly',
          'series_ends_on': '2026-12-20',
        },
      ),
    );
    expect(game.isSeries, isTrue);
    expect(game.seriesFrequency, 'biweekly');
    expect(game.seriesEndsOn, DateTime(2026, 12, 20));
  });

  test('future edit outcome keeps the joined-games count', () {
    final o = SeriesFutureEditOutcome.fromJson({
      'updated': 3,
      'kept_with_players': 2,
      'created': 1,
    });
    expect((o.updated, o.keptWithPlayers, o.created), (3, 2, 1));
  });

  test('cancel outcome reads the counts', () {
    final o = SeriesCancelOutcome.fromJson({
      'cancelled': 4,
      'player_notifications': 7,
      'past_kept': 2,
    });
    expect((o.cancelled, o.playerNotifications, o.pastKept), (4, 7, 2));
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('badge shows for a series game in $locale', (tester) async {
      final game = GameView.fromJson(
        _card(extra: {'series_id': 's1', 'series_frequency': 'weekly'}),
      );
      await tester.pumpWidget(_host(game, locale));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game-series-badge')), findsOneWidget);
    });

    testWidgets('no badge for a one-off game in $locale', (tester) async {
      await tester.pumpWidget(_host(GameView.fromJson(_card()), locale));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game-series-badge')), findsNothing);
    });
  }
}
