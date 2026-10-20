import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/presentation/providers/chat_gif_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/render_mode.dart';
import '../support/fake_backend.dart';

/// KAN-582: sharing a GIF in a direct and a group chat. The attach control
/// opens the app's GIF picker (faked here to pick at once; the real picker is
/// tested in gif_picker_states_test.dart), the choice is sent as one ordinary
/// text message, and the thread draws such a message as a GIF with the
/// provider credit.
const _gif = 'https://media1.giphy.com/media/abc/giphy.gif?cid=1';
const _dmConv = 'conv-dm1';

typedef _Variant = ({String name, Locale locale, Brightness brightness});
const _variants = <_Variant>[
  (name: 'en-light', locale: Locale('en'), brightness: Brightness.light),
  (name: 'ar-dark', locale: Locale('ar'), brightness: Brightness.dark),
];

final _boundary = GlobalKey();

class _Harness {
  _Harness({required this.dm});

  final bool dm;
  final repo = FakeMessagingRepository(
    clock: () => DateTime(2026, 3, 3, 9),
    currentUserId: 'me',
  );
  int pickerOpened = 0;
  BuildContext? pickerContext;

  String get conversation => dm ? _dmConv : 'conv-g1';

  /// Seeds the conversation, then sends [history] bodies as earlier messages.
  Future<void> prepare([List<String> history = const []]) async {
    if (dm) {
      repo.seedGameConversation('dm1', messageCount: 1);
      repo.seedMyConversations([
        MyConversation(
          conversationId: _dmConv,
          kind: MyConversationKind.dm,
          state: MyConversationState.send,
          counterpartUserId: 'member-1',
          counterpartName: 'Sara',
        ),
      ]);
    } else {
      repo.seedGameConversation('g1', messageCount: 2);
    }
    for (var i = 0; i < history.length; i++) {
      await repo.sendTextMessage(
        conversationId: conversation,
        body: history[i],
        idempotencyKey: 'old-$i',
      );
    }
  }

  Widget app(_Variant v, {String? picked = _gif}) {
    return ProviderScope(
      overrides: [
        fakeMessagingBackend,
        fakeMessagingRepositoryProvider.overrideWithValue(repo),
        gameChatPollIntervalProvider.overrideWithValue(null),
        messagingClockProvider.overrideWithValue(
          () => DateTime(2026, 3, 3, 20),
        ),
        chatGifPickerProvider.overrideWithValue((
          context, {
          required onSelected,
        }) async {
          pickerOpened++;
          pickerContext = context;
          if (picked != null) onSelected(picked);
        }),
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
          child: dm
              ? const GameChatScreen.dm(conversationId: _dmConv)
              : const GameChatScreen(gameId: 'g1'),
        ),
      ),
    );
  }
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
    try {
      final ui.Image image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final file = File('$kShotsRoot/kan582-gif/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes.buffer.asUint8List());
    } on FileSystemException {
      // A read-only shots root is not a test failure.
    }
  });
}

List<DabblerThreadMessage> _messages(WidgetTester tester) => tester
    .widget<DabblerMessageThread>(find.byType(DabblerMessageThread))
    .items
    .whereType<DabblerThreadMessage>()
    .toList();

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

  for (final dm in [true, false]) {
    for (final v in _variants) {
      group('[${dm ? 'direct' : 'group'} ${v.name}]', () {
        late AppLocalizations l10n;
        late _Harness h;
        setUp(() {
          l10n = lookupAppLocalizations(v.locale);
          h = _Harness(dm: dm);
        });

        testWidgets('TC1: the attach control is there, named, and opens the '
            'GIF picker', (tester) async {
          await h.prepare();
          await tester.pumpWidget(h.app(v, picked: null));
          await _settle(tester);
          final attach = find.bySemanticsLabel(l10n.messaging_chat_attach_gif);
          expect(attach, findsOneWidget);
          await tester.tap(attach);
          await _settle(tester);
          expect(h.pickerOpened, 1);
        });

        testWidgets('TC2: picking sends ONE text message whose body is the '
            'GIF url; the thread draws it as a GIF with the provider credit', (
          tester,
        ) async {
          await h.prepare();
          await tester.pumpWidget(h.app(v));
          await _settle(tester);
          final before = h.repo.sendAttempts;
          await tester.tap(
            find.bySemanticsLabel(l10n.messaging_chat_attach_gif),
          );
          await _settle(tester);
          expect(h.repo.sendAttempts, before + 1);

          final gifs = _messages(tester).where((m) => m.attachment != null);
          expect(gifs.length, 1);
          expect(
            gifs.single.content,
            isNull,
            reason: 'drawn as image, not text',
          );
          expect(gifs.single.attachment!.isImage, isTrue);
          final image = tester.widget<DabblerImage>(
            find.byWidgetPredicate((w) => w is DabblerImage && w.url == _gif),
          );
          expect(image.semanticLabel, l10n.messaging_gif_semantic);
          // The raw url is never shown as text; the credit is.
          expect(find.text(_gif), findsNothing);
          expect(find.text(l10n.messaging_gif_badge), findsOneWidget);
          await _shot(tester, '${dm ? 'direct' : 'group'}-gif-${v.name}');
        });

        testWidgets('a GIF url already in the history is drawn as a GIF; a '
            'sentence that merely contains a link is not', (tester) async {
          await h.prepare([
            _gif,
            'see https://media1.giphy.com/media/abc/giphy.gif',
          ]);
          await tester.pumpWidget(h.app(v, picked: null));
          await _settle(tester);
          final all = _messages(tester);
          expect(all.where((m) => m.attachment != null).length, 1);
          expect(
            all.where((m) => m.content?.startsWith('see') ?? false).length,
            1,
          );
        });

        testWidgets('a message that only mentions a link stays text', (
          tester,
        ) async {
          await h.prepare();
          await tester.pumpWidget(h.app(v));
          await _settle(tester);
          await tester.enterText(
            find.byType(EditableText),
            'see https://media1.giphy.com/media/abc/giphy.gif',
          );
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_send));
          await _settle(tester);
          final mine = _messages(tester).last;
          expect(mine.attachment, isNull);
          expect(mine.content, contains('see'));
        });
      });
    }
  }
}
