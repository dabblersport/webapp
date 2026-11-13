import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_backend.dart';

import '../../../support/render_mode.dart';

/// A fake whose clock advances 10 hours per message (so a thread spans days),
/// which turns seq 2 into a server system line, records every idempotency key
/// sent, and can hold a send open.
class _Repo extends FakeMessagingRepository {
  _Repo() : super(clock: _stepClock(), currentUserId: 'me');

  static DateTime Function() _stepClock() {
    var n = 0;
    final base = DateTime(2026, 3, 1, 9);
    return () => base.add(Duration(hours: 10 * n++));
  }

  final List<String> sentKeys = [];
  Completer<void>? hold;

  @override
  Future<Result<MessagePage, Failure>> listMessages({
    required String conversationId,
    int? cursor,
    MessageDirection direction = MessageDirection.older,
    int? limit,
  }) async {
    final r = await super.listMessages(
      conversationId: conversationId,
      cursor: cursor,
      direction: direction,
      limit: limit,
    );
    if (r is Err) return r;
    final p = r.requireValue;
    return Ok(
      MessagePage(
        messages: [
          for (final m in p.messages)
            m.seq == 2
                ? Message(
                    id: m.id,
                    conversationId: m.conversationId,
                    seq: m.seq,
                    kind: MessageKind.system,
                    body: 'sys2',
                    createdAt: m.createdAt,
                  )
                : m,
        ],
        hasOlder: p.hasOlder,
        hasNewer: p.hasNewer,
        pageSize: p.pageSize,
        olderCursor: p.olderCursor,
        newerCursor: p.newerCursor,
      ),
    );
  }

  @override
  Future<Result<Message, Failure>> sendTextMessage({
    required String conversationId,
    required String body,
    required String idempotencyKey,
  }) async {
    sentKeys.add(idempotencyKey);
    if (hold != null) await hold!.future;
    return super.sendTextMessage(
      conversationId: conversationId,
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }
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

Widget _app(_Repo repo, _Variant v, {DateTime? endAt}) {
  var n = 0;
  return ProviderScope(
    overrides: [
      fakeMessagingBackend,
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      messagingClientKeyGeneratorProvider.overrideWithValue(() => 'key-${++n}'),
      gameChatPollIntervalProvider.overrideWithValue(null),
      messagingClockProvider.overrideWithValue(() => _now),
    ],
    child: MaterialApp(
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
      home: GameChatScreen(gameId: 'g1', gameEndAt: endAt),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Writes a PNG of the screen under SHOTS_ROOT/kan516 (best effort).
Future<void> _shot(WidgetTester tester, String name) async {
  final boundary =
      _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;
    final file = File('$kShotsRoot/kan516/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

/// The out-of-scope list: nothing of these is drawn. (KAN-580 supersedes D8:
/// a sent message of your own now carries the Sent tick.)
void _expectNothingForbidden(WidgetTester tester) {
  expect(find.byType(DabblerTypingIndicator), findsNothing);
  expect(find.byType(DabblerReactionGroup), findsNothing);
  for (final s in const [
    '24 hours',
    'refund',
    'or see the games you organise',
    'Leave',
  ]) {
    expect(find.textContaining(s), findsNothing);
  }
  expect(tester.takeException(), isNull);
}

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

  for (final v in _variants) {
    group('[${v.name}]', () {
      testWidgets('loading shows the thread skeleton', (tester) async {
        final repo = _Repo()..seedGameConversation('g1', messageCount: 3);
        await tester.pumpWidget(_app(repo, v));
        expect(find.byKey(GameChatScreen.loadingKey), findsOneWidget);
        expect(find.byType(DabblerThreadSkeleton), findsOneWidget);
        await _shot(tester, 'loading-${v.name}');
        await _settle(tester);
        expect(find.byKey(GameChatScreen.loadingKey), findsNothing);
        _expectNothingForbidden(tester);
      });

      testWidgets('empty shows the empty state and the composer', (
        tester,
      ) async {
        final repo = _Repo()..seedGameConversation('g1');
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        expect(find.byKey(GameChatScreen.emptyKey), findsOneWidget);
        expect(find.byKey(GameChatScreen.composerKey), findsOneWidget);
        await _shot(tester, 'empty-${v.name}');
        _expectNothingForbidden(tester);
      });

      testWidgets(
        'populated: seq order, date separators, system line, older page',
        (tester) async {
          final repo = _Repo()..seedGameConversation('g1', messageCount: 35);
          await tester.pumpWidget(
            _app(repo, v, endAt: DateTime(2026, 3, 3, 12)),
          );
          await _settle(tester);
          final thread = tester.widget<DabblerMessageThread>(
            find.byKey(GameChatScreen.threadKey),
          );
          final bodies = [
            for (final i in thread.items)
              if (i is DabblerThreadMessage) i.content!,
          ];
          // Newest page: seq 6..35, ascending.
          expect(bodies.first, 'm6');
          expect(bodies.last, 'm35');
          expect(bodies, [for (var s = 6; s <= 35; s++) 'm$s']);
          expect(thread.items.whereType<DabblerThreadDate>(), isNotEmpty);
          // The client "game finished" line.
          final l10n = lookupAppLocalizations(v.locale);
          expect(
            thread.items.whereType<DabblerThreadSystem>().map((s) => s.text),
            contains(l10n.messaging_chat_game_finished),
          );
          // No sent message carries a delivery state (D8).
          expect(
            thread.items.whereType<DabblerThreadMessage>().where(
              (m) => m.deliveryState != null,
            ),
            isEmpty,
          );
          await _shot(tester, 'populated-${v.name}');

          // Older page through the pager.
          expect(find.byKey(GameChatScreen.pagerKey), findsOneWidget);
          await tester.ensureVisible(find.byKey(GameChatScreen.pagerKey));
          await tester.pump();
          await tester.tap(find.text(l10n.messaging_chat_older_load));
          await _settle(tester);
          final after = tester.widget<DabblerMessageThread>(
            find.byKey(GameChatScreen.threadKey),
          );
          final all = [
            for (final i in after.items)
              if (i is DabblerThreadMessage) i.content!,
          ];
          expect(all.first, 'm1');
          expect(all.length, 34); // seq 2 is a system line
          expect(
            after.items.whereType<DabblerThreadSystem>().map((s) => s.text),
            contains('sys2'),
          );
          expect(find.byKey(GameChatScreen.pagerKey), findsNothing);
          final dates = after.items.whereType<DabblerThreadDate>().length;
          expect(dates, greaterThan(3));
          _expectNothingForbidden(tester);
        },
      );

      testWidgets('sending then sent; failed then Retry with the same key', (
        tester,
      ) async {
        final repo = _Repo()..seedGameConversation('g1', messageCount: 2);
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = lookupAppLocalizations(v.locale);

        // Sending.
        repo.hold = Completer<void>();
        await tester.enterText(find.byType(EditableText), 'hello');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_send));
        await tester.pump();
        var thread = tester.widget<DabblerMessageThread>(
          find.byKey(GameChatScreen.threadKey),
        );
        final pending = thread.items.whereType<DabblerThreadMessage>().last;
        expect(pending.content, 'hello');
        expect(pending.direction, DabblerMessageDirection.outgoing);
        expect(pending.deliveryState, DabblerDeliveryState.sending);
        expect(
          tester
              .widget<DabblerChatComposer>(
                find.byKey(GameChatScreen.composerKey),
              )
              .state,
          DabblerChatComposerState.sending,
        );
        await _shot(tester, 'sending-${v.name}');
        repo.hold!.complete();
        repo.hold = null;
        await _settle(tester);
        thread = tester.widget<DabblerMessageThread>(
          find.byKey(GameChatScreen.threadKey),
        );
        expect(
          thread.items.whereType<DabblerThreadMessage>().last.deliveryState,
          DabblerDeliveryState.sent, // KAN-580: the server has it
        );

        // Failed.
        repo.failNext(FakeMessagingOp.sendTextMessage, MessagingReason.offline);
        await tester.enterText(find.byType(EditableText), 'again');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_send));
        await _settle(tester);
        thread = tester.widget<DabblerMessageThread>(
          find.byKey(GameChatScreen.threadKey),
        );
        final failed = thread.items.whereType<DabblerThreadMessage>().last;
        expect(failed.deliveryState, DabblerDeliveryState.failed);
        expect(find.text(l10n.messaging_chat_retry), findsOneWidget);
        await _shot(tester, 'failed-${v.name}');

        // Retry resends with the SAME idempotency key.
        await tester.tap(find.text(l10n.messaging_chat_retry));
        await _settle(tester);
        expect(repo.sentKeys, ['key-1', 'key-2', 'key-2']);
        thread = tester.widget<DabblerMessageThread>(
          find.byKey(GameChatScreen.threadKey),
        );
        final retried = thread.items.whereType<DabblerThreadMessage>().last;
        expect(retried.content, 'again');
        expect(retried.deliveryState, DabblerDeliveryState.sent);
        expect(
          repo.storedMessages('conv-g1').where((m) => m.body == 'again'),
          hasLength(1),
        );
        _expectNothingForbidden(tester);
      });

      testWidgets('offline shows the connection notice and retries', (
        tester,
      ) async {
        final repo = _Repo()..seedGameConversation('g1', messageCount: 3);
        repo.offline = true;
        await tester.pumpWidget(_app(repo, v));
        await _settle(tester);
        final l10n = lookupAppLocalizations(v.locale);
        expect(find.byKey(GameChatScreen.offlineKey), findsOneWidget);
        expect(find.byType(DabblerConnectionNotice), findsOneWidget);
        expect(find.byKey(GameChatScreen.composerKey), findsNothing);
        await _shot(tester, 'offline-${v.name}');
        repo.offline = false;
        await tester.tap(find.text(l10n.messaging_chat_offline_retry));
        await _settle(tester);
        expect(find.byKey(GameChatScreen.threadKey), findsOneWidget);
        _expectNothingForbidden(tester);
      });
    });
  }

  testWidgets('polling refresh adds messages sent elsewhere', (tester) async {
    final repo = _Repo()..seedGameConversation('g1', messageCount: 3);
    await tester.pumpWidget(_app(repo, _variants.first));
    await _settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameChatScreen)),
    );
    // Another member's message lands on the server.
    await repo.sendTextMessage(
      conversationId: 'conv-g1',
      body: 'from elsewhere',
      idempotencyKey: 'other-key',
    );
    await container
        .read(gameChatControllerProvider('g1').notifier)
        .refreshNewest();
    await _settle(tester);
    final thread = tester.widget<DabblerMessageThread>(
      find.byKey(GameChatScreen.threadKey),
    );
    expect(
      thread.items.whereType<DabblerThreadMessage>().last.content,
      'from elsewhere',
    );
  });
}
