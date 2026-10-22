// KAN-618: the game composer owns one client request id per create attempt.
// It is held and exposed only; the RPC payload is unchanged. The database is
// a fake HTTP client: no network, no live data.
import 'dart:async';
import 'dart:convert';

import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
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
int _cooldownCalls = 0;
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
    _cooldownCalls++;
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

/// Sport -> format -> venue -> date + time -> price, the create path's choices.
Future<void> _fill(WidgetTester tester, AppLocalizations l) async {
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
    '35',
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
    _ids.clear();
    _bodies.clear();
    _gamesByRequest.clear();
    _anonymousGames = 0;
    _cooldownCalls = 0;
    _loseResponse = false;
    _fail = false;
    _holder = CreateRequestId();
  });

  Future<void> open(WidgetTester tester, {bool offline = false}) async {
    await _pump(
      tester,
      GameComposerScreen(requestId: _holder),
      offline: offline,
    );
    await _fill(tester, l);
  }

  testWidgets('criterion 2: the id is null until the first Create tap', (
    tester,
  ) async {
    await open(tester);
    expect(_holder!.current, isNull);
    await _tap(tester, _submit);
    expect(_ids.single, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('criterion 3: after a failure the retry reuses the same id', (
    tester,
  ) async {
    await open(tester);
    _fail = true;
    await _tap(tester, _submit);
    final first = _holder!.current;
    expect(first, isNotNull);
    // The form is kept: Create is still live.
    expect(tester.widget<DabblerComposerSubmit>(_submit).enabled, isTrue);

    await _tap(tester, _submit);
    expect(_ids, [first, first]);
    expect(_holder!.current, first);
  });

  testWidgets('criterion 4: success clears the id', (tester) async {
    await open(tester);
    _fail = true;
    await _tap(tester, _submit);
    final failedId = _holder!.current;

    _fail = false;
    await _tap(tester, _submit);
    expect(_ids.last, failedId);
    // The composer closed on success; its attempt is over, so the next
    // composer opens with no id and makes a new one.
    expect(_holder!.current, isNull);
    expect(_holder!.begin(), isNot(failedId));
  });

  testWidgets('criterion 5: editing after a failure gives a new id', (
    tester,
  ) async {
    await open(tester);
    _fail = true;
    await _tap(tester, _submit);
    final first = _holder!.current;

    await _tap(tester, find.text(l.game_join_request));
    await _tap(tester, _submit);
    expect(_ids, hasLength(2));
    expect(_ids.last, isNotNull);
    expect(_ids.last, isNot(first));
  });

  testWidgets('criterion 5: an edit then restoring the value still gives a '
      'new id', (tester) async {
    await open(tester);
    _fail = true;
    await _tap(tester, _submit);
    final first = _holder!.current;

    await _tap(tester, find.text(l.game_join_request));
    await _tap(tester, find.text(l.game_join_open));
    await _tap(tester, _submit);
    expect(_ids, hasLength(2));
    expect(_ids.last, isNotNull);
    expect(_ids.last, isNot(first));
  });

  testWidgets('criterion 5: closing the composer clears the id', (
    tester,
  ) async {
    await open(tester);
    _fail = true;
    await _tap(tester, _submit);
    expect(_holder!.current, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(_holder!.current, isNull);
  });

  testWidgets('criterion 6: two Create taps in one frame make one submission', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(_submit);
    final submit = tester.widget<DabblerComposerSubmit>(_submit);
    submit.onPressed!();
    submit.onPressed!();
    await _settle(tester);
    expect(_ids, hasLength(1));
  });

  testWidgets('KAN-612: the create RPC carries the held id as p_request_id', (
    tester,
  ) async {
    await open(tester);
    await _tap(tester, _submit);
    expect(_bodies.single['p_request_id'], isNotNull);
    expect(_bodies.single['p_request_id'], _ids.single);
  });

  testWidgets('KAN-612: lost response, then retry: one game, the same id, '
      'one cooldown use', (tester) async {
    await open(tester);
    _loseResponse = true;
    await _tap(tester, _submit);
    expect(_gamesByRequest, hasLength(1), reason: 'the server did create it');
    // The form is kept: Create is still live.
    expect(tester.widget<DabblerComposerSubmit>(_submit).enabled, isTrue);

    _loseResponse = false;
    await _tap(tester, _submit);
    expect(_bodies, hasLength(2));
    expect(_bodies[1]['p_request_id'], _bodies[0]['p_request_id']);
    expect(_gamesByRequest, hasLength(1), reason: 'no second game');
    expect(
      _cooldownCalls,
      1,
      reason: 'a retry does not use a second daily creation slot',
    );
  });

  testWidgets('KAN-612: double tap is one create RPC', (tester) async {
    await open(tester);
    await tester.ensureVisible(_submit);
    final submit = tester.widget<DabblerComposerSubmit>(_submit);
    submit.onPressed!();
    submit.onPressed!();
    await _settle(tester);
    expect(_bodies, hasLength(1));
    expect(_gamesByRequest, hasLength(1));
  });

  testWidgets('KAN-612: offline: Create is refused up front, the form is '
      'kept', (tester) async {
    await open(tester, offline: true);
    await tester.ensureVisible(_submit);
    tester.widget<DabblerComposerSubmit>(_submit).onPressed!();
    await _settle(tester);
    expect(_bodies, isEmpty, reason: 'nothing was sent');
    expect(_cooldownCalls, 0);
    expect(_holder!.current, isNull, reason: 'no id was made');
    expect(find.text(l.offline_create_refused), findsOneWidget);
    // Still on the form, still ready to Create.
    expect(tester.widget<DabblerComposerSubmit>(_submit).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
