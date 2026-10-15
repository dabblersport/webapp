import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/repositories/block_repository.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/dm_failure.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/dm_thread_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/dm_thread_parts.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_safety_sheets.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/render_mode.dart';

/// KAN-556 (DMs F3): the DM thread is the shared chat screen in its DM form.

const _them = 'member-1';
const _convId = 'conv-dm1';

class _Repo extends FakeMessagingRepository {
  _Repo() : super(clock: _clock(), currentUserId: 'me');

  static DateTime Function() _clock() {
    var n = 0;
    final base = DateTime(2026, 3, 3, 9);
    return () => base.add(Duration(minutes: n++));
  }

  Failure? listFailure;

  @override
  Future<Result<List<MyConversation>, Failure>> listMyConversations({
    int? limit,
  }) async {
    final f = listFailure;
    if (f != null) return Err(f);
    return super.listMyConversations(limit: limit);
  }
}

class _Block implements BlockRepository {
  _Block({this.mine = const [], this.theirs = const []});

  final List<String> mine;
  final List<String> theirs;
  final List<String> blocked = [];

  @override
  Future<Result<void, Failure>> blockUser(String targetUserId) async {
    blocked.add(targetUserId);
    return const Ok(null);
  }

  @override
  Future<Result<List<String>, Failure>> getBlockedUserIds() async =>
      Ok([...mine, ...theirs, ...blocked]);

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>>
  getBlockedUsersWithProfiles() async => Ok([
    for (final id in [...mine, ...blocked]) {'user_id': id},
  ]);

  @override
  Future<Result<bool, Failure>> isBlocked(String otherUserId) async =>
      Ok([...mine, ...theirs, ...blocked].contains(otherUserId));

  @override
  Future<Result<void, Failure>> unblockUser(String targetUserId) async =>
      const Ok(null);
}

/// Seeds the DM: one message from them (seq 1, sender member-1) and the
/// caller's Messages-list row for it.
_Repo _seed({
  MyConversationState state = MyConversationState.send,
  bool muted = false,
}) {
  final repo = _Repo();
  // The fake keeps messages by conversation id; `conv-dm1` holds the DM's.
  repo.seedGameConversation('dm1', messageCount: 1);
  repo.seedMyConversations([
    MyConversation(
      conversationId: _convId,
      kind: MyConversationKind.dm,
      state: state,
      counterpartUserId: _them,
      counterpartName: 'Sara',
      muted: muted,
    ),
  ]);
  return repo;
}

typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

final _now = DateTime(2026, 3, 3, 20);
final _boundary = GlobalKey();

Widget _app(
  _Repo repo,
  _Block block,
  _Variant v, {
  String conversationId = _convId,
  List<String>? profileOpened,
}) {
  var n = 0;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => GameChatScreen.dm(conversationId: conversationId),
      ),
      GoRoute(
        path: '${RoutePaths.userProfile}/:userId',
        builder: (_, s) {
          profileOpened?.add(s.pathParameters['userId']!);
          return const SizedBox(key: ValueKey('profile'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      blockRepositoryProvider.overrideWithValue(block),
      messagingClientKeyGeneratorProvider.overrideWithValue(() => 'key-${++n}'),
      gameChatPollIntervalProvider.overrideWithValue(null),
      messagingClockProvider.overrideWithValue(() => _now),
    ],
    child: MaterialApp.router(
      routerConfig: router,
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
        child: RepaintBoundary(key: _boundary, child: child),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary =
      _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;
    final file = File('$kShotsRoot/kan556/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _openOptions(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.bySemanticsLabel(l10n.messaging_dm_options_title));
  await _settle(tester);
  expect(find.byKey(DmThreadKeys.options), findsOneWidget);
}

/// No presence, typing, ticks, previews, unread or system lines in a DM.
void _expectNothingForbidden(WidgetTester tester, AppLocalizations l10n) {
  expect(find.byType(DabblerTypingIndicator), findsNothing);
  expect(find.byType(DabblerConversationRow), findsNothing);
  expect(find.text(l10n.messaging_chat_game_finished), findsNothing);
  final icons = tester
      .widgetList<DabblerIcon>(
        find.descendant(
          of: find.byType(DabblerMessageThread),
          matching: find.byType(DabblerIcon),
        ),
      )
      .map((i) => i.name);
  expect(icons, isNot(contains('tick-circle')));
  final header = tester.widget<DabblerConversationHeader>(
    find.byKey(DmThreadKeys.header),
  );
  expect(header.subtitle, isNull);
  expect(header.typing, isNull);
  expect(header.online, isFalse);
}

void main() {
  for (final v in _variants) {
    group('[${v.name}]', () {
      late AppLocalizations l10n;
      setUp(() => l10n = lookupAppLocalizations(v.locale));

      testWidgets('header shows name + avatar; send appears in the thread', (
        tester,
      ) async {
        final repo = _seed();
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        final header = tester.widget<DabblerConversationHeader>(
          find.byKey(DmThreadKeys.header),
        );
        expect(header.title, 'Sara');
        expect(header.seed, _them);
        expect(header.onTitlePress, isNotNull);
        expect(find.text('m1'), findsOneWidget);
        expect(
          tester
              .widget<DabblerMessageThread>(find.byType(DabblerMessageThread))
              .context,
          DabblerMessageContext.direct,
        );
        await tester.enterText(find.byType(EditableText), 'hello Sara');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_send));
        await _settle(tester);
        expect(find.text('hello Sara'), findsOneWidget);
        expect(repo.storedMessages(_convId).last.body, 'hello Sara');
        _expectNothingForbidden(tester, l10n);
        await _shot(tester, 'send-${v.name}');
      });

      testWidgets('read-only: they blocked you', (tester) async {
        final repo = _seed(state: MyConversationState.readOnly);
        await tester.pumpWidget(_app(repo, _Block(theirs: [_them]), v));
        await _settle(tester);
        expect(find.byKey(GameChatScreen.composerKey), findsNothing);
        expect(find.byKey(DmThreadKeys.readOnly), findsOneWidget);
        expect(find.text(l10n.messaging_dm_read_only_blocked_you), findsOne);
        expect(find.text('m1'), findsOneWidget);
        await _shot(tester, 'blocked-you-${v.name}');
      });

      testWidgets('read-only: you blocked them', (tester) async {
        final repo = _seed(state: MyConversationState.readOnly);
        await tester.pumpWidget(_app(repo, _Block(mine: [_them]), v));
        await _settle(tester);
        expect(find.byKey(GameChatScreen.composerKey), findsNothing);
        expect(find.text(l10n.messaging_dm_read_only_you_blocked), findsOne);
        expect(find.text('m1'), findsOneWidget);
      });

      testWidgets('read-only: counterpart deleted', (tester) async {
        final repo = _seed(state: MyConversationState.readOnly);
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        expect(find.byKey(GameChatScreen.composerKey), findsNothing);
        expect(find.text(l10n.messaging_dm_read_only_gone), findsOneWidget);
        expect(find.text('m1'), findsOneWidget);
        await _shot(tester, 'gone-${v.name}');
      });

      testWidgets('mute toggles; a refused unmute rolls back with a message', (
        tester,
      ) async {
        final repo = _seed();
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        await _openOptions(tester, l10n);
        expect(find.text(l10n.messaging_dm_menu_mute), findsOneWidget);
        await _tap(tester, find.byKey(DmThreadKeys.mute));
        expect(repo.setMutedCalls, 1);
        expect(find.byKey(DmThreadKeys.muteFailed), findsNothing);
        await _openOptions(tester, l10n);
        expect(find.text(l10n.messaging_dm_menu_unmute), findsOneWidget);
        repo.failNextDm(FakeDmOp.setMuted, MessagingReason.rateLimited);
        await _tap(tester, find.byKey(DmThreadKeys.mute));
        expect(repo.setMutedCalls, 2);
        expect(find.text(l10n.messaging_dm_mute_failed), findsOneWidget);
        await _shot(tester, 'mute-rollback-${v.name}');
        // Rolled back: still muted, so the menu still offers Unmute.
        await _openOptions(tester, l10n);
        expect(find.text(l10n.messaging_dm_menu_unmute), findsOneWidget);
      });

      testWidgets('block: confirmation, then the read-only line', (
        tester,
      ) async {
        final repo = _seed();
        final block = _Block();
        await tester.pumpWidget(_app(repo, block, v));
        await _settle(tester);
        await _openOptions(tester, l10n);
        await _tap(tester, find.byKey(DmThreadKeys.block));
        expect(find.byKey(GameChatSafetyKeys.blockSheet), findsOneWidget);
        expect(block.blocked, isEmpty);
        await _tap(tester, find.byKey(GameChatSafetyKeys.blockConfirm));
        expect(block.blocked, [_them]);
        expect(find.byKey(GameChatSafetyKeys.blockDone), findsOneWidget);
        await _tap(tester, find.text(l10n.messaging_report_done));
        expect(find.byKey(GameChatScreen.composerKey), findsNothing);
        expect(find.text(l10n.messaging_dm_read_only_you_blocked), findsOne);
        expect(find.text('m1'), findsOneWidget);
        await _shot(tester, 'blocked-${v.name}');
      });

      testWidgets('report user: the existing report flow submits', (
        tester,
      ) async {
        final repo = _seed();
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        await _openOptions(tester, l10n);
        await _tap(tester, find.byKey(DmThreadKeys.report));
        expect(find.byKey(GameChatSafetyKeys.reportSheet), findsOneWidget);
        await _tap(
          tester,
          find.byKey(GameChatSafetyKeys.reason(ReportCategory.spam)),
        );
        await _tap(tester, find.byKey(GameChatSafetyKeys.reportSubmit));
        expect(find.byKey(GameChatSafetyKeys.reportSubmitted), findsOneWidget);
        final id = repo.storedMessages(_convId).single.id;
        expect(repo.wasReported(id), isTrue);
        await _shot(tester, 'report-${v.name}');
      });

      testWidgets('rate_limited send shows its localized line', (tester) async {
        final repo = _seed();
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        repo.failNext(
          FakeMessagingOp.sendTextMessage,
          MessagingReason.rateLimited,
        );
        await tester.enterText(find.byType(EditableText), 'too fast');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_send));
        await _settle(tester);
        expect(find.text(l10n.messaging_reason_rate_limited), findsOneWidget);
        await _shot(tester, 'rate-limited-${v.name}');
      });

      testWidgets('dm_cap_reached shows its localized line', (tester) async {
        final repo = _seed()..listFailure = DmCapReachedFailure();
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        expect(find.text(l10n.messaging_reason_dm_cap_reached), findsOne);
        await _shot(tester, 'cap-${v.name}');
      });

      testWidgets('not found / no access is the unavailable state', (
        tester,
      ) async {
        final repo = _seed();
        await tester.pumpWidget(
          _app(repo, _Block(), v, conversationId: 'conv-unknown'),
        );
        await _settle(tester);
        expect(find.byType(GameChatAccessState), findsOneWidget);
        expect(find.byKey(GameChatScreen.composerKey), findsNothing);
        await _shot(tester, 'unavailable-${v.name}');
      });
    });
  }

  testWidgets('header tap opens the counterpart profile', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _app(_seed(), _Block(), _variants.first, profileOpened: opened),
    );
    await _settle(tester);
    await _tap(tester, find.text('Sara'));
    expect(opened, [_them]);
  });

  test('flags off: the route body is the unavailable state', () {
    expect(
      dmThreadRouteBody(conversationId: _convId, messaging: false),
      isA<GameChatAccessState>(),
    );
    expect(
      dmThreadRouteBody(
        conversationId: _convId,
        messaging: true,
        gameChat: true,
      ),
      isA<GameChatScreen>().having(
        (s) => s.conversationId,
        'conversationId',
        _convId,
      ),
    );
  });

  test('route registered: messagingThread at /messaging/thread/:id', () {
    final r = dmThreadRoute();
    expect(r.name, 'messagingThread');
    expect(r.path, '/messaging/thread/:conversationId');
  });
}
