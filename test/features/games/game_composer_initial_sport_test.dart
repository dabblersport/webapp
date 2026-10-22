// KAN-622: the composer preselects the sport it is opened with (Create game
// on the Sport Overview page). The database is a fake HTTP client.
import 'dart:async';
import 'dart:convert';

import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/core/utils/create_request_id.dart';
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

import '../../support/render_mode.dart';
import '../../support/connectivity_overrides.dart';

/// The request id the composer held at each create RPC.
final List<String?> _ids = <String?>[];
CreateRequestId? _holder;
bool _fail = false;

/// KAN-612: the body of each create RPC, the games the fake server holds
/// (one per request id, like the KAN-611 unique index), and how many times
/// the daily creation cooldown was used.
final List<Map<String, dynamic>> _bodies = <Map<String, dynamic>>[];
final Map<String, String> _gamesByRequest = <String, String>{};
int _anonymousGames = 0;
bool _loseResponse = false;

const List<Map<String, dynamic>> _sports = <Map<String, dynamic>>[
  {
    'id': 's-padel',
    'sport_key': 'padel',
    'name_en': 'Padel',
    'emoji': '🎾',
    'color_code': null,
  },
];

const List<Map<String, dynamic>> _variants = <Map<String, dynamic>>[
  {
    'id': 'v-doubles',
    'variant_key': 'doubles',
    'name_en': 'Doubles',
    'required_players': 4,
    'players_per_side': 2,
  },
];

const List<Map<String, dynamic>> _spaces = <Map<String, dynamic>>[
  {
    'id': 'vs-1',
    'name_en': 'Court 1',
    'sport_id': 's-padel',
    'sport_variant_keys': ['doubles'],
    'venue': {'id': 'ven-1', 'name_en': 'Padel Pro', 'area': 'Marina'},
  },
];

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
    _ids.add(_holder?.current);
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    _bodies.add(body);
    if (!_fail) {
      final rid = body['p_request_id'] as String?;
      final id = rid == null
          ? 'g-anon-${_anonymousGames++}'
          : _gamesByRequest.putIfAbsent(
              rid,
              () => 'g-${_gamesByRequest.length}',
            );
      if (_loseResponse) throw TimeoutException('response lost');
      return json(id);
    }
    if (_fail) {
      return json(<String, Object>{
        'message': 'network down',
        'code': 'P0001',
      }, 400);
    }
    return json('g-new');
  }
  if (path.endsWith('/sports')) return json(_sports);
  if (path.endsWith('/sport_variants')) return json(_variants);
  if (path.endsWith('/venue_spaces')) return json(_spaces);
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

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  bool offline = false,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const locale = Locale('en');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        offline ? offlineConnectivity() : onlineConnectivity(),
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
                        child: body,
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

  testWidgets(
    'initialSportId preselects the sport: formats open without a pick',
    (tester) async {
      await _pump(tester, const GameComposerScreen(initialSportId: 's-padel'));
      await _tap(tester, find.text(l.game_select_format));
      expect(find.text('Doubles'), findsWidgets);
    },
  );

  testWidgets('an unknown initialSportId preselects nothing', (tester) async {
    await _pump(tester, const GameComposerScreen(initialSportId: 's-unknown'));
    expect(find.text(l.game_select_format), findsNothing);
  });
}
