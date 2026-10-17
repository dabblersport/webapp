import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/repositories/block_repository.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_safety_sheets.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_backend.dart';

import '../../../support/render_mode.dart';

/// KAN-517 (T16b): closed/read-only, mute, report and block.

class _Repo extends FakeMessagingRepository {
  _Repo() : super(clock: _clock(), currentUserId: 'me');

  static DateTime Function() _clock() {
    var n = 0;
    final base = DateTime(2026, 3, 1, 9);
    return () => base.add(Duration(hours: n++));
  }

  final List<(String, ReportCategory)> reports = [];
  int muteCalls = 0;
  int unmuteCalls = 0;

  @override
  Future<Result<void, Failure>> reportMessage({
    required String messageId,
    required ReportCategory reason,
  }) async {
    reports.add((messageId, reason));
    return super.reportMessage(messageId: messageId, reason: reason);
  }

  @override
  Future<Result<void, Failure>> muteConversation(String conversationId) {
    muteCalls++;
    return super.muteConversation(conversationId);
  }

  @override
  Future<Result<void, Failure>> unmuteConversation(String conversationId) {
    unmuteCalls++;
    return super.unmuteConversation(conversationId);
  }
}

class _Block implements BlockRepository {
  final List<String> blocked = [];

  @override
  Future<Result<void, Failure>> blockUser(String targetUserId) async {
    blocked.add(targetUserId);
    return const Ok(null);
  }

  @override
  Future<Result<List<String>, Failure>> getBlockedUserIds() async =>
      Ok(List.of(blocked));

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>>
  getBlockedUsersWithProfiles() async => const Ok([]);

  @override
  Future<Result<bool, Failure>> isBlocked(String otherUserId) async =>
      Ok(blocked.contains(otherUserId));

  @override
  Future<Result<void, Failure>> unblockUser(String targetUserId) async =>
      const Ok(null);
}

typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

final _now = DateTime(2026, 3, 3, 20);
final _endAt = DateTime(2026, 3, 1, 12);
final _boundary = GlobalKey();

Widget _app(_Repo repo, _Block block, _Variant v, {DateTime? endAt}) {
  var n = 0;
  return ProviderScope(
    overrides: [
      fakeMessagingBackend,
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      blockRepositoryProvider.overrideWithValue(block),
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
    final file = File('$kShotsRoot/kan517/$name.png');
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

/// No Leave, no D29 copy, no '24 hours', no ticks/typing/presence/preview.
void _expectNothingForbidden(WidgetTester tester, AppLocalizations l10n) {
  // Delivery ticks (D8): none inside the thread. (The success inline message
  // of a sheet uses its own glyph and is not a tick.)
  final icons = tester
      .widgetList<DabblerIcon>(
        find.descendant(
          of: find.byType(DabblerMessageThread),
          matching: find.byType(DabblerIcon),
        ),
      )
      .map((i) => i.name);
  expect(icons, isNot(contains('tick-circle')));
  expect(find.byType(DabblerTypingIndicator), findsNothing);
  expect(find.byType(DabblerReactionGroup), findsNothing);
  expect(find.byType(DabblerConversationRow), findsNothing);
  for (final s in const [
    '24 hours',
    '24 ساعة',
    'refund',
    'Refund',
    'price',
    'Price',
    'settlement',
    'Settlement',
    'AED',
    'see the games you organise',
    'Leave',
    'Online',
    'typing',
  ]) {
    expect(find.textContaining(s), findsNothing, reason: s);
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
      final l10n = lookupAppLocalizations(v.locale);

      for (final reason in const [
        MessagingReason.gameEnded,
        MessagingReason.gameCancelled,
      ]) {
        testWidgets('closed ${reason.wireName}: notice replaces composer', (
          tester,
        ) async {
          final repo = _Repo()
            ..seedGameConversation(
              'g1',
              messageCount: 4,
              writable: false,
              readOnlyReason: reason,
            );
          await tester.pumpWidget(_app(repo, _Block(), v, endAt: _endAt));
          await _settle(tester);
          expect(find.byKey(GameChatScreen.composerKey), findsNothing);
          expect(find.byKey(GameChatScreen.closedNoticeKey), findsOneWidget);
          expect(find.byType(EditableText), findsNothing);
          expect(
            find.text(
              reason == MessagingReason.gameEnded
                  ? l10n.messaging_chat_closed_ended
                  : l10n.messaging_chat_closed_cancelled,
            ),
            findsOneWidget,
          );
          // Reads still work; the finished line comes from end_at.
          final thread = tester.widget<DabblerMessageThread>(
            find.byKey(GameChatScreen.threadKey),
          );
          expect(
            [
              for (final i in thread.items)
                if (i is DabblerThreadMessage) i.content,
            ],
            ['m1', 'm2', 'm3', 'm4'],
          );
          expect(
            thread.items.whereType<DabblerThreadSystem>().map((s) => s.text),
            contains(l10n.messaging_chat_game_finished),
          );
          await _shot(tester, 'closed-${reason.wireName}-${v.name}');
          _expectNothingForbidden(tester, l10n);
        });
      }

      testWidgets('a send refused with game_ended closes the chat', (
        tester,
      ) async {
        final repo = _Repo()..seedGameConversation('g1', messageCount: 2);
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        repo.failNext(
          FakeMessagingOp.sendTextMessage,
          MessagingReason.gameEnded,
        );
        await tester.enterText(find.byType(EditableText), 'late');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_send));
        await _settle(tester);
        expect(find.byKey(GameChatScreen.composerKey), findsNothing);
        expect(find.byKey(GameChatScreen.closedNoticeKey), findsOneWidget);
        expect(find.byKey(GameChatScreen.threadKey), findsOneWidget);
        _expectNothingForbidden(tester, l10n);
      });

      testWidgets('mute then unmute', (tester) async {
        final repo = _Repo()..seedGameConversation('g1', messageCount: 2);
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_mute));
        await _settle(tester);
        expect(repo.muteCalls, 1);
        expect(
          (await repo.getGameConversation('g1')).requireValue.muted,
          isTrue,
        );
        expect(find.bySemanticsLabel(l10n.messaging_chat_unmute), findsOne);
        await _shot(tester, 'muted-${v.name}');
        await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_unmute));
        await _settle(tester);
        expect(repo.unmuteCalls, 1);
        expect(
          (await repo.getGameConversation('g1')).requireValue.muted,
          isFalse,
        );
        expect(find.bySemanticsLabel(l10n.messaging_chat_mute), findsOne);
        await _shot(tester, 'unmuted-${v.name}');
        _expectNothingForbidden(tester, l10n);
      });

      testWidgets('report: submit sends the chosen reason', (tester) async {
        final repo = _Repo()..seedGameConversation('g1', messageCount: 2);
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        await _tap(tester, find.text('m1'));
        expect(find.byKey(GameChatSafetyKeys.options), findsOneWidget);
        _expectNothingForbidden(tester, l10n);
        await _tap(tester, find.byKey(GameChatSafetyKeys.reportAction));
        expect(find.byKey(GameChatSafetyKeys.reportSheet), findsOneWidget);
        // All ten reasons are present; the list is lazy and height-capped
        // (KAN-503), so a row below the fold is reached by scrolling it.
        final reasonScroll = find.descendant(
          of: find.byKey(GameChatSafetyKeys.reasonList),
          matching: find.byType(Scrollable),
        );
        for (final c in ReportCategory.values) {
          await tester.pump();
          await tester.scrollUntilVisible(
            find.byKey(GameChatSafetyKeys.reason(c)),
            80,
            scrollable: reasonScroll,
          );
          expect(find.byKey(GameChatSafetyKeys.reason(c)), findsOneWidget);
        }
        await _settle(tester);
        expect(find.byKey(GameChatSafetyKeys.reportSubmit), findsOneWidget);
        expect(find.byKey(GameChatSafetyKeys.reportCancel), findsOneWidget);
        expect(find.text(l10n.messaging_report_cancel), findsOneWidget);
        await _shot(tester, 'report-${v.name}');
        await _tap(
          tester,
          find.byKey(GameChatSafetyKeys.reason(ReportCategory.harassment)),
        );
        await _tap(tester, find.byKey(GameChatSafetyKeys.reportSubmit));
        expect(find.byKey(GameChatSafetyKeys.reportSubmitted), findsOneWidget);
        final id = repo.storedMessages('conv-g1').first.id;
        expect(repo.reports, [(id, ReportCategory.harassment)]);
        expect(repo.wasReported(id), isTrue);
        await _shot(tester, 'report-submitted-${v.name}');
        _expectNothingForbidden(tester, l10n);
      });

      testWidgets('report: cancel closes without a repository call', (
        tester,
      ) async {
        final repo = _Repo()..seedGameConversation('g1', messageCount: 2);
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        await _tap(tester, find.text('m1'));
        await _tap(tester, find.byKey(GameChatSafetyKeys.reportAction));
        expect(find.byKey(GameChatSafetyKeys.reportSubmit), findsOneWidget);
        expect(find.byKey(GameChatSafetyKeys.reportCancel), findsOneWidget);
        await _tap(
          tester,
          find.byKey(GameChatSafetyKeys.reason(ReportCategory.spam)),
        );
        await _tap(tester, find.byKey(GameChatSafetyKeys.reportCancel));
        expect(find.byKey(GameChatSafetyKeys.reportSheet), findsNothing);
        expect(repo.reports, isEmpty);
        final id = repo.storedMessages('conv-g1').first.id;
        expect(repo.wasReported(id), isFalse);
        _expectNothingForbidden(tester, l10n);
      });

      testWidgets(
        'report: Send and Cancel pinned on screen, reason list capped and '
        'scrolls inside itself',
        (tester) async {
          final repo = _Repo()..seedGameConversation('g1', messageCount: 2);
          await tester.pumpWidget(_app(repo, _Block(), v));
          await _settle(tester);
          await _tap(tester, find.text('m1'));
          await _tap(tester, find.byKey(GameChatSafetyKeys.reportAction));
          final viewport = tester.getRect(find.byType(MaterialApp));
          void expectOnScreen(Finder f) {
            expect(f, findsOneWidget);
            final r = tester.getRect(f);
            expect(
              viewport.contains(r.topLeft) && viewport.contains(r.bottomRight),
              isTrue,
              reason: '$f at $r outside $viewport',
            );
            // Hittable without scrolling: the hit test lands on it.
            f.hitTestable().evaluate();
            expect(f.hitTestable(), findsOneWidget);
          }

          // No scroll performed: both actions visible and hittable.
          expectOnScreen(find.byKey(GameChatSafetyKeys.reportSubmit));
          expectOnScreen(find.byKey(GameChatSafetyKeys.reportCancel));
          // The reason list is height-capped at half the viewport.
          final list = find.byKey(GameChatSafetyKeys.reasonList);
          expect(
            tester.getSize(list).height,
            lessThanOrEqualTo(viewport.height / 2 + 0.01),
          );
          // The last reason is reachable by scrolling the LIST itself.
          final listView = find.descendant(
            of: list,
            matching: find.byType(Scrollable),
          );
          final last = find.byKey(
            GameChatSafetyKeys.reason(ReportCategory.values.last),
          );
          await tester.scrollUntilVisible(last, 80, scrollable: listView);
          await _settle(tester);
          expect(last.hitTestable(), findsOneWidget);
          // Actions are still on screen after the list scrolled.
          expectOnScreen(find.byKey(GameChatSafetyKeys.reportSubmit));
          expectOnScreen(find.byKey(GameChatSafetyKeys.reportCancel));
          // Selecting a reason enables Send.
          final submit = find.byKey(GameChatSafetyKeys.reportSubmit);
          expect(tester.widget<DabblerButton>(submit).disabled, isTrue);
          await tester.tap(last);
          await _settle(tester);
          expect(tester.widget<DabblerButton>(submit).disabled, isFalse);
          await _shot(tester, 'report-pinned-${v.name}');
          // Cancel closes without a repository call.
          await tester.tap(find.byKey(GameChatSafetyKeys.reportCancel));
          await _settle(tester);
          expect(find.byKey(GameChatSafetyKeys.reportSheet), findsNothing);
          expect(repo.reports, isEmpty);
          _expectNothingForbidden(tester, l10n);
        },
      );

      testWidgets('report: failure shows the failed state and retries', (
        tester,
      ) async {
        final repo = _Repo()..seedGameConversation('g1', messageCount: 2);
        repo.failNext(FakeMessagingOp.reportMessage, MessagingReason.offline);
        await tester.pumpWidget(_app(repo, _Block(), v));
        await _settle(tester);
        await _tap(tester, find.text('m1'));
        await _tap(tester, find.byKey(GameChatSafetyKeys.reportAction));
        await _tap(
          tester,
          find.byKey(GameChatSafetyKeys.reason(ReportCategory.spam)),
        );
        await _tap(tester, find.byKey(GameChatSafetyKeys.reportSubmit));
        expect(find.byKey(GameChatSafetyKeys.reportFailed), findsOneWidget);
        expect(find.byKey(GameChatSafetyKeys.reportRetry), findsOneWidget);
        await _shot(tester, 'report-failed-${v.name}');
        await _tap(tester, find.byKey(GameChatSafetyKeys.reportRetry));
        expect(find.byKey(GameChatSafetyKeys.reportSubmitted), findsOneWidget);
        expect(repo.reports.map((r) => r.$2), [
          ReportCategory.spam,
          ReportCategory.spam,
        ]);
        _expectNothingForbidden(tester, l10n);
      });

      testWidgets('block from the sheet calls the block repository', (
        tester,
      ) async {
        final repo = _Repo()..seedGameConversation('g1', messageCount: 2);
        final block = _Block();
        await tester.pumpWidget(_app(repo, block, v));
        await _settle(tester);
        await _tap(tester, find.text('m1'));
        await _tap(tester, find.byKey(GameChatSafetyKeys.blockAction));
        expect(find.byKey(GameChatSafetyKeys.blockSheet), findsOneWidget);
        expect(find.text(l10n.messaging_block_body), findsOneWidget);
        await _shot(tester, 'block-${v.name}');
        _expectNothingForbidden(tester, l10n);
        await _tap(tester, find.byKey(GameChatSafetyKeys.blockConfirm));
        expect(block.blocked, [
          repo.storedMessages('conv-g1').first.senderUserId,
        ]);
        expect(find.byKey(GameChatSafetyKeys.blockDone), findsOneWidget);
        _expectNothingForbidden(tester, l10n);
      });
    });
  }

  test('no D29/D13 copy in the new ARB values', () {
    for (final f in ['lib/l10n/app_en.arb', 'lib/l10n/app_ar.arb']) {
      final text = File(f).readAsStringSync();
      final lines = text
          .split('\n')
          .where(
            (l) =>
                l.contains('"messaging_report_') ||
                l.contains('"messaging_block_') ||
                l.contains('"messaging_chat_closed') ||
                l.contains('"messaging_chat_mut') ||
                l.contains('"messaging_chat_unmute'),
          )
          .join('\n');
      expect(lines, isNotEmpty);
      for (final s in const [
        '24',
        'hour',
        'refund',
        'price',
        'settle',
        'organise',
        'Leave',
        'retain',
      ]) {
        expect(
          lines.toLowerCase(),
          isNot(contains(s.toLowerCase())),
          reason: s,
        );
      }
    }
  });
}
