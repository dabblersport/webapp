import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/messages_list_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/messages_list_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/messages_list_meetup_row.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/render_mode.dart';

// KAN-559: meetup rows in the Messages list beside game and DM rows. Fake
// repository only; no network.
typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

final _now = DateTime.utc(2026, 10, 15, 12);

MyConversation _meetup(String id, Duration ago, {bool ended = false}) =>
    MyConversation(
      conversationId: id,
      kind: MyConversationKind.meetup,
      title: 'Meetup $id',
      startAt: ended
          ? DateTime.utc(2026, 10, 10, 8)
          : DateTime.utc(2026, 10, 18, 8),
      state: ended ? MyConversationState.readOnly : MyConversationState.send,
      lastActivityAt: _now.subtract(ago),
    );

List<MyConversation> _seed() => [
  MyConversation(
    conversationId: 'c-g1',
    gameId: 'g1',
    title: 'Game g1',
    sport: 'Football',
    startAt: DateTime.utc(2026, 10, 17, 19),
    state: MyConversationState.send,
    lastActivityAt: _now.subtract(const Duration(hours: 2)),
  ),
  MyConversation(
    conversationId: 'd1',
    kind: MyConversationKind.dm,
    state: MyConversationState.send,
    counterpartUserId: 'u1',
    counterpartName: 'Omar',
    lastActivityAt: _now.subtract(const Duration(hours: 1)),
  ),
  _meetup('m-going', const Duration(minutes: 5)),
  _meetup('m-ended', const Duration(days: 3), ended: true),
];

class _Nav {
  String? param;
}

Widget _app(FakeMessagingRepository repo, _Variant v, _Nav nav) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (c, s) => const MessagesListScreen()),
      GoRoute(
        path: dmThreadRoutePath,
        name: dmThreadRouteName,
        builder: (c, s) {
          nav.param = s.pathParameters[messagesListDmRouteParam];
          return const SizedBox(key: ValueKey('thread'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      messagingClockProvider.overrideWithValue(() => _now),
      messagesListFlagsProvider.overrideWithValue((
        messaging: true,
        gameChat: true,
      )),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: v.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withFonts(
        DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        locale: v.locale,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(v.scale)),
        child: child!,
      ),
      routerConfig: router,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

DabblerConversationRow _dsRow(WidgetTester tester, String id) =>
    tester.widget<DabblerConversationRow>(
      find.descendant(
        of: find.byKey(
          MessagesListScreen.meetupRowKey(id),
          skipOffstage: false,
        ),
        matching: find.byType(DabblerConversationRow, skipOffstage: false),
      ),
    );

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  test('parse accepts kind meetup without game or meetup id', () {
    final c = MyConversation.parse({
      'conversation_id': 'm1',
      'state': 'read_only',
      'kind': 'meetup',
      'game_title': 'Run club',
      'start_at': '2026-10-18T08:00:00Z',
    }).requireValue;
    expect(c.isMeetup, isTrue);
    expect(c.gameId, isNull);
    expect(c.meetupId, isNull);
    expect(c.title, 'Run club');
  });

  test(
    'parse reads a meetup row\'s game_id as its meetup id, never gameId',
    () {
      final c = MyConversation.parse({
        'conversation_id': 'm1',
        'state': 'send',
        'kind': 'meetup',
        'game_id': 'meet-42',
      }).requireValue;
      expect(c.meetupId, 'meet-42');
      expect(c.gameId, isNull);
      expect(c.toJson()['game_id'], 'meet-42');
    },
  );

  test('a game row keeps gameId and has no meetup id', () {
    final c = MyConversation.parse({
      'conversation_id': 'c1',
      'state': 'send',
      'kind': 'game',
      'game_id': 'g1',
    }).requireValue;
    expect(c.gameId, 'g1');
    expect(c.meetupId, isNull);
  });

  for (final v in _variants) {
    group('[${v.name}]', () {
      testWidgets('meetup rows beside game and DM rows; no preview/unread', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()..seedMyConversations(_seed());
        await tester.pumpWidget(_app(repo, v, _Nav()));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(MessagesListScreen)),
        );
        expect(find.byKey(MessagesListScreen.rowKey('g1')), findsOneWidget);
        expect(find.byKey(MessagesListScreen.dmRowKey('d1')), findsOneWidget);
        for (final id in ['m-going', 'm-ended']) {
          final row = _dsRow(tester, id);
          expect(row.title, 'Meetup $id');
          expect(row.kind, DabblerConversationKind.squad);
          expect(row.kind.glyph, 'people');
          expect(row.preview, isNull);
          expect(row.sender, isNull);
          expect(row.unread, 0);
          expect(row.timestamp, isNotEmpty);
          expect(row.kindLabel, startsWith(l10n.messaging_meetup_mark_label));
          expect(
            row.kindLabel!.length,
            greaterThan(l10n.messaging_meetup_mark_label.length),
          );
        }
        expect(
          _dsRow(tester, 'm-going').state?.label,
          l10n.messaging_list_state_send,
        );
        expect(
          _dsRow(tester, 'm-ended').state?.label,
          l10n.messaging_list_state_read_only,
        );
      });

      testWidgets('tapping a meetup row opens the thread route by id', (
        tester,
      ) async {
        final nav = _Nav();
        final repo = FakeMessagingRepository()..seedMyConversations(_seed());
        await tester.pumpWidget(_app(repo, v, nav));
        await _settle(tester);
        await tester.tap(find.byType(MessagesListMeetupRow).first);
        await _settle(tester);
        expect(nav.param, 'm-going');
        expect(find.byKey(const ValueKey('thread')), findsOneWidget);
      });
    });
  }
}
