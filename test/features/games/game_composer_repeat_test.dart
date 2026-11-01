// KAN-697: the Repeat control of the game composer. The database is a fake HTTP
// client: no network, no live data, nothing is written anywhere.
import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/connectivity_overrides.dart';
import '../../support/render_mode.dart';

/// Each RPC the composer called: function name -> body.
final List<(String, Map<String, dynamic>)> _rpcs =
    <(String, Map<String, dynamic>)>[];

/// The venue the fake server returns; swapped per test.
Map<String, dynamic> _venue = <String, dynamic>{
  'id': 'ven-1',
  'name_en': 'Padel Pro',
  'area': 'Marina',
};

http.Client _fakeDb() => MockClient((http.Request req) async {
  http.Response json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    request: req,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
  final String path = req.url.path;
  if (path.endsWith('/rpc/check_and_bump_cooldown')) {
    return json(<Object>[
      <String, Object>{
        'allowed': true,
        'remaining': 4,
        'reset_at': '2026-12-01T00:00:00Z',
      },
    ]);
  }
  if (path.contains('/rpc/')) {
    _rpcs.add((
      path.split('/rpc/').last,
      jsonDecode(req.body) as Map<String, dynamic>,
    ));
    return json('new-id');
  }
  if (path.endsWith('/sports')) {
    return json(<Map<String, dynamic>>[
      {
        'id': 's-padel',
        'sport_key': 'padel',
        'name_en': 'Padel',
        'emoji': '🎾',
        'color_code': null,
      },
    ]);
  }
  if (path.endsWith('/sport_variants')) {
    return json(<Map<String, dynamic>>[
      {
        'id': 'v-doubles',
        'variant_key': 'doubles',
        'name_en': 'Doubles',
        'required_players': 4,
        'players_per_side': 2,
      },
    ]);
  }
  if (path.endsWith('/venue_spaces')) {
    return json(<Map<String, dynamic>>[
      {
        'id': 'vs-1',
        'name_en': 'Court 1',
        'sport_id': 's-padel',
        'sport_variant_keys': ['doubles'],
        'venue': _venue,
      },
    ]);
  }
  return json(<Object>[]);
});

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const locale = Locale('en');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onlineConnectivity(),
        activePersonaProvider.overrideWithValue(PersonaType.player),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        routerConfig: GoRouter(
          initialLocation: '/c',
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (context, state) => const SizedBox.shrink(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'c',
                  builder: (context, state) => Builder(
                    builder: (context) => ColoredBox(
                      color: DabblerColors.of(context).bgSecondary,
                      child: DabblerSheet(
                        onClose: () => Navigator.of(context).maybePop(),
                        detent: DabblerSheetDetent.content,
                        contentMaxFraction: DabblerSheet.contentMaxFractionFull,
                        pageBackground: true,
                        showCloseButton: false,
                        title: 'Create game',
                        child: const GameComposerScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Sport -> format -> venue -> date + time, then the price.
Future<void> _fill(
  WidgetTester tester,
  AppLocalizations l, {
  required String price,
}) async {
  await _tap(tester, find.text('Padel'));
  await _tap(tester, find.text(l.game_select_format));
  await _tap(tester, find.text('Doubles'));
  await _tap(tester, find.text(l.composer_confirm));
  await _tap(tester, find.text(l.composer_select));
  await _tap(tester, find.text('Padel Pro · Court 1'));
  await _tap(tester, find.text(l.composer_confirm));
  await _tap(tester, find.text(l.game_date));
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(now.year, now.month, now.day + 1);
  if (day.month != now.month) {
    await tester.tap(find.bySemanticsLabel(RegExp('Next')).first);
    await _settle(tester);
  }
  await tester.tap(
    find
        .descendant(
          of: find.byType(DabblerCalendar),
          matching: find.text('${day.day}'),
        )
        .last,
  );
  await _settle(tester);
  await _tap(tester, find.text(l.composer_continue_time));
  await _tap(tester, find.text(l.composer_confirm));
  await tester.enterText(
    find
        .descendant(
          of: find.byType(GamePriceField),
          matching: find.byType(EditableText),
        )
        .first,
    price,
  );
  await _settle(tester, 2);
}

final Finder _submit = find.byKey(
  const ValueKey<String>('game-composer-submit'),
);

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
      httpClient: _fakeDb(),
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );
    await loadRenderFonts();
    l = lookupAppLocalizations(const Locale('en'));
  });

  setUp(() {
    _rpcs.clear();
    _venue = <String, dynamic>{
      'id': 'ven-1',
      'name_en': 'Padel Pro',
      'area': 'Marina',
    };
  });

  testWidgets('no venue place and no saved location: no RPC, a visible error', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, l, price: '0');
    await _tap(tester, find.text(l.recurring_option_weekly));
    await _tap(tester, _submit);
    expect(_rpcs, isEmpty);
    expect(find.text(l.recurring_location_required), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a venue with a place creates the series, not a single game', (
    tester,
  ) async {
    _venue = <String, dynamic>{
      ..._venue,
      'geo_location_id': 'geo-1',
      'area_id': 'area-1',
    };
    await _pump(tester);
    await _fill(tester, l, price: '0');
    await _tap(tester, find.text(l.recurring_option_biweekly));
    await _tap(tester, _submit);
    expect(_rpcs, hasLength(1));
    final (name, body) = _rpcs.single;
    expect(name, SupabaseConfig.rpcCreateGameSeriesFn);
    expect(body['p_geo_location_id'], 'geo-1');
    expect(body['p_area_id'], 'area-1');
    expect(body['p_timezone'], SupabaseConfig.defaultSeriesTimezone);
    expect(body['p_frequency'], 'biweekly');
    expect(body['p_capacity'], 4);
    expect(body['p_price_aed'], 0);
    expect(body.containsKey('p_ends_on'), isFalse);
  });

  testWidgets('a paid game cannot repeat: the row says why', (tester) async {
    await _pump(tester);
    await _fill(tester, l, price: '35');
    expect(find.textContaining(l.recurring_paid_disabled), findsOneWidget);
    expect(find.text(l.recurring_option_weekly), findsNothing);
  });

  testWidgets('without Repeat the single create RPC is unchanged', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, l, price: '35');
    await _tap(tester, _submit);
    expect(_rpcs.single.$1, SupabaseConfig.rpcCreateGameFn);
    expect(_rpcs.single.$2.containsKey('p_geo_location_id'), isFalse);
  });
}
