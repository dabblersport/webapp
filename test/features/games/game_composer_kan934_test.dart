// KAN-934: the create-game composer sends the chosen actor, refuses price 0 at
// a paid venue space, hides a format no venue space carries, and shows words,
// never a raw server code. The database is a fake HTTP client: no network, no
// live data, nothing is written anywhere.
import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_formats.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/connectivity_overrides.dart';
import '../../support/render_mode.dart';

/// Each RPC the composer called: function name -> body.
final List<(String, Map<String, dynamic>)> _rpcs =
    <(String, Map<String, dynamic>)>[];

/// The chosen space's joining rule; swapped per test.
String _joiningRule = 'free';

/// When set, the create RPCs fail with this server message.
String? _failWith;

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
    final String name = path.split('/rpc/').last;
    _rpcs.add((name, jsonDecode(req.body) as Map<String, dynamic>));
    if (_failWith != null && name.startsWith('rpc_create_game')) {
      return json(<String, Object?>{
        'code': 'P0001',
        'message': _failWith!,
        'details': null,
        'hint': null,
      }, 400);
    }
    return json('new-id');
  }
  if (path.endsWith('/sports')) {
    return json(<Map<String, dynamic>>[
      {
        'id': 's-football',
        'sport_key': 'football',
        'name_en': 'Football',
        'emoji': '⚽',
        'color_code': null,
      },
    ]);
  }
  if (path.endsWith('/sport_variants')) {
    return json(<Map<String, dynamic>>[
      {
        'id': 'v-standard',
        'variant_key': 'football_standard',
        'name_en': 'Standard',
        'required_players': 14,
        'players_per_side': 7,
      },
      {
        'id': 'v-street',
        'variant_key': 'football_street',
        'name_en': 'Street',
        'required_players': 10,
        'players_per_side': 5,
      },
    ]);
  }
  if (path.endsWith('/venue_spaces')) {
    final String select = req.url.queryParameters['select'] ?? '';
    if (!select.contains('venue')) {
      // The format filter's read: the keys the sport's spaces carry.
      return json(<Map<String, dynamic>>[
        {
          'sport_variant_keys': ['football_standard'],
        },
        {'sport_variant_keys': null},
      ]);
    }
    return json(<Map<String, dynamic>>[
      {
        'id': 'vs-1',
        'name_en': 'Pitch 1',
        'sport_id': 's-football',
        'sport_variant_keys': ['football_standard'],
        'joining_rule': _joiningRule,
        'venue': {'id': 'ven-1', 'name_en': 'Dome', 'area': 'Marina'},
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

Future<void> _pump(WidgetTester tester, PersonaType persona) async {
  tester.view.physicalSize = const Size(393, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const locale = Locale('en');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onlineConnectivity(),
        activePersonaProvider.overrideWithValue(persona),
      ],
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
        home: Builder(
          builder: (context) => ColoredBox(
            color: DabblerColors.of(context).bgSecondary,
            child: DabblerSheet(
              onClose: () {},
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
    ),
  );
  await _settle(tester);
}

Future<void> _pickFormat(WidgetTester tester, AppLocalizations l) async {
  await _tap(tester, find.text('Football'));
  await _tap(tester, find.text(l.game_select_format));
}

/// Sport -> Standard -> the venue -> date + time, then the price.
Future<void> _fill(
  WidgetTester tester,
  AppLocalizations l, {
  required String price,
}) async {
  await _pickFormat(tester, l);
  await _tap(tester, find.text('Standard'));
  await _tap(tester, find.text(l.composer_confirm));
  await _tap(tester, find.text(l.composer_select));
  await _tap(tester, find.text('Dome · Pitch 1'));
  await _tap(tester, find.text(l.composer_confirm));
  await _tap(tester, find.text(l.game_date));
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(now.year, now.month, now.day + 1);
  if (day.month != now.month) {
    await tester.tap(find.bySemanticsLabel(RegExp('Next')).first);
    await _settle(tester);
  }
  final Finder dayCells = find.descendant(
    of: find.byType(DabblerCalendar),
    matching: find.text('${day.day}'),
  );
  await tester.tap(day.day <= 15 ? dayCells.first : dayCells.last);
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

List<(String, Map<String, dynamic>)> get _creates =>
    _rpcs.where((r) => r.$1 != SupabaseConfig.rpcTrackEventFn).toList();

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
    _joiningRule = 'free';
    _failWith = null;
  });

  group('actor (p_actor_type)', () {
    testWidgets('a player creates as player, with no Create as row', (
      tester,
    ) async {
      await _pump(tester, PersonaType.player);
      expect(find.text(l.game_create_as), findsNothing);
      await _fill(tester, l, price: '0');
      await _tap(tester, _submit);
      expect(_creates.single.$1, SupabaseConfig.rpcCreateGameFn);
      expect(_creates.single.$2['p_actor_type'], 'player');
    });

    testWidgets('an organiser creates as organiser', (tester) async {
      await _pump(tester, PersonaType.organiser);
      expect(find.text(l.game_create_as), findsNothing);
      await _fill(tester, l, price: '0');
      await _tap(tester, _submit);
      expect(_creates.single.$2['p_actor_type'], 'organiser');
    });

    testWidgets('a contributor picks Organiser and creates as organiser', (
      tester,
    ) async {
      await _pump(tester, PersonaType.contributor);
      expect(find.text(l.game_create_as), findsOneWidget);
      await _tap(tester, find.text(l.persona_organiser_name));
      await _fill(tester, l, price: '0');
      await _tap(tester, _submit);
      expect(_creates.single.$2['p_actor_type'], 'organiser');
    });

    test('actorFor: one capability decides; both take the choice', () {
      expect(gameComposerActorFor(PersonaType.player, null), 'player');
      expect(
        gameComposerActorFor(PersonaType.organiser, 'player'),
        'organiser',
      );
      expect(gameComposerActorFor(PersonaType.contributor, null), 'player');
      expect(
        gameComposerActorFor(PersonaType.contributor, 'organiser'),
        'organiser',
      );
      expect(gameComposerActorFor(null, null), 'player');
    });
  });

  group('price at a paid venue space (rule: above 0)', () {
    testWidgets('price 0 at a paid space: nothing sent, EN message shown', (
      tester,
    ) async {
      _joiningRule = 'paid';
      await _pump(tester, PersonaType.player);
      await _fill(tester, l, price: '0');
      await _tap(tester, _submit);
      expect(_creates, isEmpty);
      expect(find.text(l.game_err_paid_space_price), findsWidgets);
    });

    testWidgets('a price above 0 at a paid space is sent', (tester) async {
      _joiningRule = 'paid';
      await _pump(tester, PersonaType.player);
      await _fill(tester, l, price: '40');
      await _tap(tester, _submit);
      expect(_creates.single.$2['p_price_aed'], 40);
    });

    testWidgets('price 0 at a free space is allowed', (tester) async {
      await _pump(tester, PersonaType.player);
      await _fill(tester, l, price: '0');
      await _tap(tester, _submit);
      expect(_creates.single.$2['p_price_aed'], 0);
    });

    test('the message is Arabic in Arabic', () {
      final ar = lookupAppLocalizations(const Locale('ar'));
      const e = GameComposerError(GameComposerErrorCode.paidSpacePrice);
      expect(RegExp(r'[؀-ۿ]').hasMatch(e.text(ar, 'ar')), isTrue);
      expect(e.text(l, 'en'), l.game_err_paid_space_price);
    });
  });

  testWidgets('a format no venue space carries (Street) is not offered', (
    tester,
  ) async {
    await _pump(tester, PersonaType.player);
    await _pickFormat(tester, l);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Street'), findsNothing);
  });

  for (final code in <String>[
    'persona_not_allowed',
    'no_profile_of_requested_type',
  ]) {
    testWidgets('$code shows the refusal copy, never the code', (tester) async {
      _failWith = code;
      await _pump(tester, PersonaType.player);
      await _fill(tester, l, price: '0');
      await _tap(tester, _submit);
      expect(_creates, hasLength(1));
      expect(find.text(l.game_err_create_refused), findsWidgets);
      expect(find.textContaining(code), findsNothing);
    });
  }

  testWidgets('an unknown server code shows the generic sentence', (
    tester,
  ) async {
    _failWith = 'some_new_server_code';
    await _pump(tester, PersonaType.player);
    await _fill(tester, l, price: '0');
    await _tap(tester, _submit);
    expect(find.text(l.game_error_generic), findsWidgets);
    expect(find.textContaining('some_new_server_code'), findsNothing);
  });
}
