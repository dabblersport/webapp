import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/typing.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_realtime_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/typing_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/dm_thread_parts.dart';
import 'package:dabbler/features/messaging/presentation/widgets/typing_thread_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/render_mode.dart';
import '../support/fake_backend.dart';
import 'typing_fakes.dart';

/// KAN-579: the typing indicator in the real chat screen, direct and group,
/// English/light and Arabic/dark. Fake repository, fake channel, fake
/// transport: nothing real is called.
const _them = 'member-1';
const _dmConv = 'conv-dm1';
const _gameConv = 'conv-g1';

typedef _Variant = ({String name, Locale locale, Brightness brightness});

const List<_Variant> _variants = [
  (name: 'en-light', locale: Locale('en'), brightness: Brightness.light),
  (name: 'ar-dark', locale: Locale('ar'), brightness: Brightness.dark),
];

const Map<String, String> _names = {
  'u-2': 'Yousef Nabil',
  'u-3': 'Sara Haddad',
  'u-4': 'Omar Saleh',
  'u-5': 'Lina Aziz',
  'u-long': 'Abdulrahman bin Mohammed bin Salman Al Rashid Al Maktoum II',
};

final _boundary = GlobalKey();

class _Harness {
  _Harness({required this.dm});

  final bool dm;
  // Messages sent through this fake are stamped with the counterpart's id, so
  // a test can make "their message arrives" (the screen reads the sender id).
  final repo = FakeMessagingRepository(
    clock: () => DateTime(2026, 3, 3, 9),
    currentUserId: _them,
  );
  final transport = RecordingTypingTransport();
  late FakeTypingChannel channel;
  DateTime now = DateTime(2026, 10, 20, 12);

  String get conversation => dm ? _dmConv : _gameConv;

  Widget app(_Variant v, {bool open = true}) {
    if (dm) {
      repo.seedGameConversation('dm1', messageCount: 1);
      repo.seedMyConversations([
        MyConversation(
          conversationId: _dmConv,
          kind: MyConversationKind.dm,
          state: MyConversationState.send,
          counterpartUserId: _them,
          counterpartName: 'Sara',
        ),
      ]);
    } else {
      repo.seedGameConversation('g1', messageCount: 2);
    }
    return ProviderScope(
      overrides: [
        fakeMessagingBackend,
        fakeMessagingRepositoryProvider.overrideWithValue(repo),
        gameChatPollIntervalProvider.overrideWithValue(null),
        messagingClockProvider.overrideWithValue(
          () => DateTime(2026, 3, 3, 20),
        ),
        messagingRealtimeEnabledProvider.overrideWithValue(true),
        messagingUserIdProvider.overrideWith((ref) => Stream.value('me')),
        messagingWakeChannelFactoryProvider.overrideWithValue(
          (uid) => channel = FakeTypingChannel(
            uid,
            status: WakeChannelStatus.subscribed,
          ),
        ),
        typingTransportProvider.overrideWithValue(transport),
        typingClockProvider.overrideWithValue(() => now),
        profileByUserIdProvider.overrideWith(
          (ref, id) async => _names.containsKey(id)
              ? Ok<Profile, Failure>(
                  Profile(
                    id: 'p-$id',
                    userId: id,
                    profileType: 'player',
                    username: id,
                    displayName: _names[id]!,
                  ),
                )
              : Err<Profile, Failure>(const UnknownFailure()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: v.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            v.brightness == Brightness.dark
                ? ThemeData.dark()
                : ThemeData.light(),
          ),
          locale: v.locale,
        ),
        home: RepaintBoundary(
          key: _boundary,
          child: open
              ? (dm
                    ? const GameChatScreen.dm(conversationId: _dmConv)
                    : const GameChatScreen(gameId: 'g1'))
              : const Scaffold(body: SizedBox()),
        ),
      ),
    );
  }

  void typing(String user, {bool on = true, String? conversation}) =>
      channel.emitTyping(
        TypingSignal(
          conversationId: conversation ?? this.conversation,
          userId: user,
          on: on,
        ),
      );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _advance(_Harness h, WidgetTester tester, Duration d) async {
  var left = d;
  const step = Duration(milliseconds: 500);
  while (left > Duration.zero) {
    final s = left < step ? left : step;
    h.now = h.now.add(s);
    await tester.pump(s);
    left -= s;
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary =
      _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  await tester.runAsync(() async {
    try {
      final ui.Image image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final file = File('$kShotsRoot/kan579-typing/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes.buffer.asUint8List());
    } on FileSystemException {
      // A read-only shots root is not a test failure.
    }
  });
}

/// The dots text of the typing row (a message of the thread).
final Finder _row = find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (typingDotFrames.contains(w.data) || w.data == typingDotsStill),
);

/// The typing row's thread item, or null.
DabblerThreadMessage? _typingItem(WidgetTester tester) => tester
    .widget<DabblerMessageThread>(find.byType(DabblerMessageThread))
    .items
    .whereType<DabblerThreadMessage>()
    .where((m) => m.id == 'typing-row')
    .firstOrNull;

/// The label of the typing row (group only), or null.
String? _typingLabel(WidgetTester tester) => _typingItem(tester)?.sender;

DabblerConversationHeader _header(WidgetTester tester) =>
    tester.widget<DabblerConversationHeader>(find.byKey(DmThreadKeys.header));

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
    group('[${v.name}] direct chat', () {
      late AppLocalizations l10n;
      late _Harness h;
      setUp(() {
        l10n = lookupAppLocalizations(v.locale);
        h = _Harness(dm: true);
      });

      testWidgets('header subtitle says "typing…" and the dots row shows; a '
          'stop returns to normal', (tester) async {
        await tester.pumpWidget(h.app(v));
        await _settle(tester);
        expect(_header(tester).subtitle, isNull);
        expect(_row, findsNothing);

        h.typing(_them);
        await _settle(tester);
        expect(_header(tester).subtitle, l10n.messaging_typing_dm);
        expect(_row, findsOneWidget);
        // Direct: the dots bubble only, as the LAST message of the thread. No
        // label and no avatar (so no gutter).
        final item = _typingItem(tester)!;
        expect(item.sender, isNull);
        expect(item.showAvatar, isFalse);
        expect(item.showSender, isFalse);
        expect(
          find.descendant(
            of: find.byType(DabblerMessageThread),
            matching: _row,
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<DabblerMessageThread>(find.byType(DabblerMessageThread))
              .items
              .last,
          same(item),
        );
        await _shot(tester, 'dm-typing-${v.name}');

        h.typing(_them, on: false);
        await _settle(tester);
        expect(_header(tester).subtitle, isNull);
        expect(_row, findsNothing);
        await _shot(tester, 'dm-normal-${v.name}');
      });

      testWidgets('KAN-620: the header keeps its height while "typing…" shows, '
          'and the dots bubble is the last item', (tester) async {
        await tester.pumpWidget(h.app(v));
        await _settle(tester);
        final before = tester.getSize(find.byKey(DmThreadKeys.header));
        h.typing(_them);
        await _settle(tester);
        expect(_header(tester).subtitle, l10n.messaging_typing_dm);
        expect(tester.getSize(find.byKey(DmThreadKeys.header)), before);
        expect(_row, findsOneWidget);
        h.typing(_them, on: false);
        await _settle(tester);
        expect(tester.getSize(find.byKey(DmThreadKeys.header)), before);
      });

      testWidgets('KAN-620: the typing row fades in once and the dot ticks do '
          'not replay it', (tester) async {
        await tester.pumpWidget(h.app(v));
        await _settle(tester);
        h.typing(_them);
        await _settle(tester);
        expect(_typingItem(tester)!.fresh, isTrue);
        double dim() => tester
            .widgetList<Opacity>(
              find.ancestor(of: _row, matching: find.byType(Opacity)),
            )
            .fold<double>(1, (a, o) => a * o.opacity);
        expect(dim(), 1);
        await tester.pump(const Duration(milliseconds: typingDotsFrameMs + 50));
        expect(dim(), 1);
      });

      testWidgets('KAN-620: reduced motion holds the dots still', (
        tester,
      ) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(h.app(v));
        await _settle(tester);
        h.typing(_them);
        await _settle(tester);
        expect(tester.widget<Text>(_row).data, typingDotsStill);
        await tester.pump(const Duration(milliseconds: typingDotsFrameMs * 3));
        expect(tester.widget<Text>(_row).data, typingDotsStill);
      });

      testWidgets('a stale indicator (no stop) expires by itself', (
        tester,
      ) async {
        await tester.pumpWidget(h.app(v));
        await _settle(tester);
        h.typing(_them);
        await _settle(tester);
        expect(_row, findsOneWidget);
        await _advance(
          h,
          tester,
          typingReceiverTtl + const Duration(seconds: 1),
        );
        expect(_row, findsNothing);
        expect(_header(tester).subtitle, isNull);
      });

      testWidgets('the counterpart\'s message ends their typing at once', (
        tester,
      ) async {
        await tester.pumpWidget(h.app(v));
        await _settle(tester);
        h.typing(_them);
        await _settle(tester);
        expect(_row, findsOneWidget);
        await h.repo.sendTextMessage(
          conversationId: _dmConv,
          body: 'hello back',
          idempotencyKey: 'k-1',
        );
        // The chat reloads on its next fetch (the wake path); drive it.
        h.channel.emit(const MessagingWake(conversationId: _dmConv, seq: 2));
        await _settle(tester);
        expect(find.text('hello back'), findsOneWidget);
        expect(_row, findsNothing);
      });

      testWidgets('the sender: typing, clearing, sending, blur, background and '
          'leaving each end with a stop', (tester) async {
        await tester.pumpWidget(h.app(v));
        await _settle(tester);
        final field = find.byType(EditableText);

        await tester.enterText(field, 'hel');
        await tester.pump();
        expect(h.transport.sent, [(conversation: _dmConv, typing: true)]);
        await tester.enterText(field, 'hello');
        await tester.pump();
        expect(h.transport.sent.length, 1, reason: 'throttled');

        await tester.enterText(field, '');
        await tester.pump();
        expect(h.transport.sent.last, (conversation: _dmConv, typing: false));
        expect(h.transport.sent.length, 2);

        // Send ends typing before the message goes.
        await tester.enterText(field, 'to send');
        await tester.pump();
        expect(h.transport.sent.last.typing, isTrue);
        await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_send));
        await _settle(tester);
        expect(h.transport.sent.last.typing, isFalse);
        final afterSend = h.transport.sent.length;

        // Blur: focus leaves the field.
        await tester.enterText(field, 'again');
        await tester.pump();
        expect(h.transport.sent.last.typing, isTrue);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        expect(h.transport.sent.last.typing, isFalse);
        expect(h.transport.sent.length, greaterThan(afterSend));

        // Background.
        await tester.enterText(field, 'third');
        await tester.pump();
        expect(h.transport.sent.last.typing, isTrue);
        for (final st in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(st);
        }
        await tester.pump();
        expect(h.transport.sent.last.typing, isFalse);
        for (final st in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(st);
        }
        await tester.pump();

        // Leaving the chat.
        await tester.enterText(field, 'fourth');
        await tester.pump();
        expect(h.transport.sent.last.typing, isTrue);
        await tester.pumpWidget(h.app(v, open: false));
        await tester.pump();
        expect(h.transport.sent.last.typing, isFalse);
        // Every signal named this conversation and carried only a boolean.
        expect(h.transport.sent.map((s) => s.conversation).toSet(), {_dmConv});
      });

      testWidgets('a read-only chat has no composer, so nothing is sent', (
        tester,
      ) async {
        await tester.pumpWidget(h.app(v));
        await _settle(tester);
        expect(h.transport.sent, isEmpty);
      });
    });

    group('[${v.name}] group chat', () {
      late AppLocalizations l10n;
      late _Harness h;
      setUp(() {
        l10n = lookupAppLocalizations(v.locale);
        h = _Harness(dm: false);
      });

      Future<void> open(WidgetTester tester) async {
        await tester.pumpWidget(h.app(v));
        await _settle(tester);
      }

      testWidgets('one, two and many typers: the label, the avatar gutter, '
          'the header unchanged', (tester) async {
        await open(tester);
        expect(_row, findsNothing);

        h.typing('u-2');
        await _settle(tester);
        expect(
          _typingLabel(tester),
          l10n.messaging_typing_one(isolateName('Yousef Nabil')),
        );
        expect(find.text(_typingLabel(tester)!), findsOneWidget);
        // A message of the thread: first typer's avatar in the gutter, the
        // label on the sender line ABOVE the bubble (design 10).
        final item = _typingItem(tester)!;
        expect(item.avatarSeed, 'u-2');
        expect(item.showAvatar, isTrue);
        expect(item.showSender, isTrue);
        expect(
          find.descendant(
            of: find.byType(DabblerMessageThread),
            matching: _row,
          ),
          findsOneWidget,
        );
        final labelBox = tester.getRect(find.text(_typingLabel(tester)!));
        final dotsBox = tester.getRect(_row);
        expect(labelBox.bottom, lessThanOrEqualTo(dotsBox.top));
        // The dots play: another frame after a frame's time.
        final before = tester.widget<Text>(_row).data;
        await tester.pump(const Duration(milliseconds: typingDotsFrameMs + 50));
        expect(tester.widget<Text>(_row).data, isNot(before));
        // The group's top bar keeps the conversation identity (design 8).
        expect(find.byType(DabblerConversationHeader), findsNothing);
        await _shot(tester, 'group-one-${v.name}');

        h.typing('u-3');
        await _settle(tester);
        expect(
          _typingLabel(tester),
          l10n.messaging_typing_two(
            isolateName('Yousef Nabil'),
            isolateName('Sara Haddad'),
          ),
        );
        await _shot(tester, 'group-two-${v.name}');

        h.typing('u-4');
        h.typing('u-5');
        await _settle(tester);
        expect(
          _typingLabel(tester),
          l10n.messaging_typing_many(isolateName('Yousef Nabil'), 3),
        );
        await _shot(tester, 'group-many-${v.name}');

        // Back to normal: everyone stops.
        for (final u in ['u-2', 'u-3', 'u-4', 'u-5']) {
          h.typing(u, on: false);
        }
        await _settle(tester);
        expect(_row, findsNothing);
      });

      testWidgets('KAN-620: four typers read "{a} and 3 others"', (
        tester,
      ) async {
        await open(tester);
        for (final u in ['u-2', 'u-3', 'u-4', 'u-5']) {
          h.typing(u);
        }
        await _settle(tester);
        expect(
          _typingLabel(tester),
          l10n.messaging_typing_many(isolateName('Yousef Nabil'), 3),
        );
        if (v.locale.languageCode == 'en') {
          expect(
            _typingLabel(tester),
            '\u2068Yousef Nabil\u2069 and 3 others are typing',
          );
        }
      });

      Future<void> longNameTyping(WidgetTester tester) async {
        await open(tester);
        h.typing('u-long');
        await _settle(tester);
      }

      testWidgets('KAN-620: a 54+ character name stays inside the screen and '
          'does not overflow', (tester) async {
        await longNameTyping(tester);
        expect(_names['u-long']!.length, greaterThan(54));
        final label = find.text(_typingLabel(tester)!);
        expect(label, findsOneWidget);
        expect(tester.getRect(label).right, lessThanOrEqualTo(390));
        expect(tester.getRect(label).left, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull);
      });

      // DS GAP (reported on KAN-620): the design system's message sender line
      // (`DabblerMessage`, message.dart) is a Text with no maxLines or
      // ellipsis, so a long typing label wraps to a second line. Design
      // section 10 says "One line, truncates". Unskip once the DS carries it.
      testWidgets(
        'KAN-620: a long name truncates to ONE line (needs DS maxLines)',
        (tester) async {
          await open(tester);
          h.typing('u-2');
          await _settle(tester);
          final oneLine = tester
              .getSize(find.text(_typingLabel(tester)!))
              .height;
          h.typing('u-2', on: false);
          h.typing('u-long');
          await _settle(tester);
          expect(
            tester.getSize(find.text(_typingLabel(tester)!)).height,
            oneLine,
          );
        },
        skip: true, // DS GAP: sender line has no maxLines/ellipsis
      );

      testWidgets('KAN-620: reduced motion holds the dots still', (
        tester,
      ) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await open(tester);
        h.typing('u-2');
        await _settle(tester);
        expect(tester.widget<Text>(_row).data, typingDotsStill);
        await tester.pump(const Duration(milliseconds: typingDotsFrameMs * 3));
        expect(tester.widget<Text>(_row).data, typingDotsStill);
      });

      testWidgets('a typer whose name cannot load reads as "Someone"', (
        tester,
      ) async {
        await open(tester);
        h.typing('u-unknown');
        await _settle(tester);
        expect(
          _typingLabel(tester),
          l10n.messaging_typing_one(l10n.messaging_typing_someone),
        );
      });

      testWidgets('three typers name two and count the rest; nobody else is '
          'named', (tester) async {
        await open(tester);
        h.typing('u-2');
        h.typing('u-3');
        h.typing('u-4');
        await _settle(tester);
        final label = _typingLabel(tester)!;
        expect(label, contains('Yousef Nabil'));
        expect(label, isNot(contains('Sara Haddad')));
        expect(label, isNot(contains('Omar Saleh')));
      });

      testWidgets('a signal for another conversation shows nothing', (
        tester,
      ) async {
        await open(tester);
        h.typing('u-2', conversation: 'conv-other');
        await _settle(tester);
        expect(_row, findsNothing);
      });

      testWidgets('the row sits in the thread above the composer: the composer '
          'does not move and the bottom padding is not doubled', (
        tester,
      ) async {
        await open(tester);
        final composer = find.byKey(GameChatScreen.composerKey);
        final before = tester.getRect(composer);
        h.typing('u-2');
        await _settle(tester);
        expect(tester.getRect(composer), before);
        expect(_row, findsOneWidget);
        expect(tester.getRect(_row).bottom, lessThanOrEqualTo(before.top));
        // It scrolls with the messages: it is the thread's last item.
        expect(
          tester
              .widget<DabblerMessageThread>(find.byType(DabblerMessageThread))
              .items
              .last,
          same(_typingItem(tester)),
        );
      });
    });
  }
}
