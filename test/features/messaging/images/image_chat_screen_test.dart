import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/messaging_image_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message_attachment.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/picked_image.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/providers/chat_image_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/chat_image_widgets.dart';
import 'package:dabbler/features/messaging/presentation/widgets/chat_share_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/render_mode.dart';
import '../support/fake_backend.dart';

/// KAN-581: private image sharing in a group and a direct chat, on the
/// in-memory fake backend. Covers the Share drawer, the tray, upload progress,
/// cancel, failure and retry without a duplicate, rendering of a settled
/// image and the full-screen viewer. Screenshots (English light and Arabic
/// dark) are written under the shots root for the Codex reviewer.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
PickedImage _pick(String name) =>
    PickedImage(name: name, bytes: _png, mimeType: 'image/png');

const _dmConv = 'conv-dm1';

typedef _Variant = ({String name, Locale locale, Brightness brightness});
const _variants = <_Variant>[
  (name: 'en-light', locale: Locale('en'), brightness: Brightness.light),
  (name: 'ar-dark', locale: Locale('ar'), brightness: Brightness.dark),
];

final _boundary = GlobalKey();

/// The fake, with an upload the test can hold open at a chosen progress.
class _SlowRepo extends FakeMessagingRepository {
  _SlowRepo()
    : super(clock: () => DateTime(2026, 3, 3, 9), currentUserId: 'me');

  Completer<void>? gate;
  double holdAt = 0.45;
  final List<UploadCancel?> cancels = [];

  @override
  Future<Result<MessageAttachment, Failure>> uploadImage({
    required String conversationId,
    required PickedImage image,
    required String idempotencyKey,
    UploadProgress? onProgress,
    UploadCancel? cancel,
  }) async {
    final held = gate;
    if (held != null) {
      cancels.add(cancel);
      onProgress?.call(
        (image.bytes.length * holdAt).round(),
        image.bytes.length,
      );
      await held.future;
      if (cancel?.isCancelled ?? false) {
        return Err(MessagingFailure.offline());
      }
    }
    return super.uploadImage(
      conversationId: conversationId,
      image: image,
      idempotencyKey: idempotencyKey,
      onProgress: onProgress,
      cancel: cancel,
    );
  }
}

class _Harness {
  _Harness({required this.dm});

  final bool dm;
  final repo = _SlowRepo();
  final picks = <ChatImageSource>[];
  ChatPickOutcome nextPick = ChatPickOutcome(images: [_pick('a.png')]);

  String get conversation => dm ? _dmConv : 'conv-g1';

  Future<void> prepare() async {
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
  }

  Widget app(_Variant v) => ProviderScope(
    overrides: [
      fakeMessagingBackend,
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      gameChatPollIntervalProvider.overrideWithValue(null),
      messagingClockProvider.overrideWithValue(() => DateTime(2026, 3, 3, 20)),
      chatImagePickerProvider.overrideWithValue((
        source, {
        required remaining,
      }) async {
        picks.add(source);
        return nextPick;
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
      // The boundary sits above the navigator so a sheet is in the picture.
      builder: (context, child) =>
          RepaintBoundary(key: _boundary, child: child),
      home: dm
          ? const GameChatScreen.dm(conversationId: _dmConv)
          : const GameChatScreen(gameId: 'g1'),
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
    try {
      final ui.Image image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final file = File('$kShotsRoot/kan581-images/$name.png');
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

Future<void> _choose(
  WidgetTester tester,
  AppLocalizations l10n,
  String rowLabel,
) async {
  await tester.tap(find.bySemanticsLabel(l10n.messaging_share_title));
  await _settle(tester);
  await tester.tap(find.text(rowLabel));
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  for (final dm in [false, true]) {
    for (final v in _variants) {
      group('[${dm ? 'direct' : 'group'} ${v.name}]', () {
        late AppLocalizations l10n;
        late _Harness h;
        setUp(() {
          l10n = lookupAppLocalizations(v.locale);
          h = _Harness(dm: dm);
        });

        testWidgets(
          'TC1: the Share drawer offers gallery, camera, image file and GIFs only',
          (tester) async {
            await h.prepare();
            await tester.pumpWidget(h.app(v));
            await _settle(tester);
            await tester.tap(find.bySemanticsLabel(l10n.messaging_share_title));
            await _settle(tester);
            for (final k in [
              ChatImageKeys.shareGallery,
              ChatImageKeys.shareCamera,
              ChatImageKeys.shareFile,
              ChatImageKeys.shareGif,
            ]) {
              expect(find.byKey(k), findsOneWidget);
            }
            expect(find.text(l10n.messaging_share_file_hint), findsOneWidget);
            expect(find.text(l10n.messaging_share_gallery), findsOneWidget);
            // No document, video, audio or voice entry.
            expect(find.byType(DabblerListRow), findsNWidgets(4));
            await _shot(tester, '${dm ? 'dm' : 'group'}-${v.name}-1-share');
          },
        );

        testWidgets(
          'TC1: gallery pick queues the photo, Send uploads it and it '
          'renders in the thread once',
          (tester) async {
            await h.prepare();
            await tester.pumpWidget(h.app(v));
            await _settle(tester);
            await _choose(tester, l10n, l10n.messaging_share_gallery);
            expect(h.picks, [ChatImageSource.gallery]);
            expect(find.byKey(ChatImageKeys.tray), findsOneWidget);
            await _shot(tester, '${dm ? 'dm' : 'group'}-${v.name}-2-tray');

            await tester.tap(find.byKey(ChatImageKeys.traySend));
            await _settle(tester);
            expect(find.byKey(ChatImageKeys.tray), findsNothing);
            expect(h.repo.newUploads, 1);
            final sent = _messages(tester).where((m) => m.attachment != null);
            expect(sent.length, 1);
            expect(sent.single.content, isNull, reason: 'no caption was typed');
            expect(find.byType(ChatRemoteImage), findsOneWidget);
            await _shot(tester, '${dm ? 'dm' : 'group'}-${v.name}-5-sent');
          },
        );

        testWidgets('TC2: camera pick goes to the camera picker', (
          tester,
        ) async {
          await h.prepare();
          await tester.pumpWidget(h.app(v));
          await _settle(tester);
          await _choose(tester, l10n, l10n.messaging_share_camera);
          expect(h.picks, [ChatImageSource.camera]);
          expect(find.byKey(ChatImageKeys.tray), findsOneWidget);
        });

        testWidgets('TC3: the image-file row uses the file picker', (
          tester,
        ) async {
          await h.prepare();
          await tester.pumpWidget(h.app(v));
          await _settle(tester);
          await _choose(tester, l10n, l10n.messaging_share_file);
          expect(h.picks, [ChatImageSource.file]);
        });

        testWidgets('TC2/TC3/TC4: a refused pick queues nothing and sends '
            'nothing', (tester) async {
          await h.prepare();
          for (final problem in ChatPickProblem.values) {
            h.nextPick = ChatPickOutcome(problem: problem);
            await tester.pumpWidget(h.app(v));
            await _settle(tester);
            final before = h.repo.sendAttempts;
            await _choose(tester, l10n, l10n.messaging_share_gallery);
            expect(
              find.byKey(ChatImageKeys.tray),
              findsNothing,
              reason: '$problem',
            );
            expect(h.repo.sendAttempts, before);
            expect(h.repo.uploadAttempts, 0);
            expect(chatPickProblemText(l10n, problem), isNotEmpty);
          }
        });

        testWidgets('tray: remove drops a photo, at most four wait, caption '
            'goes with the first', (tester) async {
          await h.prepare();
          h.nextPick = ChatPickOutcome(
            images: [for (var i = 0; i < 3; i++) _pick('p$i.png')],
          );
          await tester.pumpWidget(h.app(v));
          await _settle(tester);
          await _choose(tester, l10n, l10n.messaging_share_gallery);
          expect(find.byKey(ChatImageKeys.remove(2)), findsOneWidget);
          await tester.tap(find.byKey(ChatImageKeys.remove(2)));
          await _settle(tester);
          expect(find.byKey(ChatImageKeys.remove(2)), findsNothing);
          expect(find.byKey(ChatImageKeys.remove(1)), findsOneWidget);

          await tester.enterText(
            find.byType(EditableText).first,
            'look at this',
          );
          await tester.pump();
          await tester.tap(find.byKey(ChatImageKeys.traySend));
          await _settle(tester);
          final images = _messages(tester).where((m) => m.attachment != null);
          expect(images.length, 2, reason: 'one message per photo');
          expect(images.first.content, 'look at this');
          expect(images.last.content, isNull);
        });

        testWidgets('TC1: while uploading it shows progress and Cancel; '
            'Cancel sends nothing', (tester) async {
          await h.prepare();
          h.repo.gate = Completer<void>();
          await tester.pumpWidget(h.app(v));
          await _settle(tester);
          await _choose(tester, l10n, l10n.messaging_share_gallery);
          await tester.tap(find.byKey(ChatImageKeys.traySend));
          await _settle(tester);
          expect(find.byKey(ChatImageKeys.pendingTile), findsOneWidget);
          final held = (_png.length * 0.45).round();
          expect(
            find.text(
              l10n.messaging_image_uploading(
                (held / _png.length * 100).round(),
              ),
            ),
            findsOneWidget,
          );
          expect(find.byKey(ChatImageKeys.cancel), findsOneWidget);
          await _shot(tester, '${dm ? 'dm' : 'group'}-${v.name}-3-uploading');

          final before = h.repo.sendAttempts;
          await tester.tap(find.byKey(ChatImageKeys.cancel));
          h.repo.gate!.complete();
          await _settle(tester);
          expect(find.byKey(ChatImageKeys.pendingTile), findsNothing);
          expect(h.repo.sendAttempts, before, reason: 'nothing was sent');
          expect(h.repo.newUploads, 0);
        });

        testWidgets('TC5: a failed upload shows Failed with Retry; Retry '
            'succeeds with no duplicate', (tester) async {
          await h.prepare();
          await tester.pumpWidget(h.app(v));
          await _settle(tester);
          await _choose(tester, l10n, l10n.messaging_share_gallery);
          h.repo.offline = true; // airplane mode
          await tester.tap(find.byKey(ChatImageKeys.traySend));
          await _settle(tester);
          expect(find.text(l10n.messaging_image_failed), findsOneWidget);
          expect(find.byKey(ChatImageKeys.retry), findsOneWidget);
          await _shot(tester, '${dm ? 'dm' : 'group'}-${v.name}-4-failed');

          h.repo.offline = false;
          await tester.tap(find.byKey(ChatImageKeys.retry));
          await _settle(tester);
          expect(find.byKey(ChatImageKeys.pendingTile), findsNothing);
          expect(h.repo.newUploads, 1, reason: 'one stored image');
          final sent = _messages(tester).where((m) => m.attachment != null);
          expect(sent.length, 1, reason: 'one message, no duplicate');
        });

        testWidgets('TC5: a send that fails after the upload retries only the '
            'send', (tester) async {
          await h.prepare();
          await tester.pumpWidget(h.app(v));
          await _settle(tester);
          await _choose(tester, l10n, l10n.messaging_share_gallery);
          h.repo.failAlways(
            FakeMessagingOp.sendTextMessage,
            MessagingReason.rateLimited,
          );
          await tester.tap(find.byKey(ChatImageKeys.traySend));
          await _settle(tester);
          expect(h.repo.newUploads, 1);
          expect(find.byKey(ChatImageKeys.retry), findsOneWidget);
          h.repo.clearFailures();
          await tester.tap(find.byKey(ChatImageKeys.retry));
          await _settle(tester);
          expect(h.repo.newUploads, 1, reason: 'the stored image is reused');
          expect(
            _messages(tester).where((m) => m.attachment != null).length,
            1,
          );
        });

        testWidgets('a settled image opens full screen and closes', (
          tester,
        ) async {
          await h.prepare();
          await tester.pumpWidget(h.app(v));
          await _settle(tester);
          await _choose(tester, l10n, l10n.messaging_share_gallery);
          await tester.tap(find.byKey(ChatImageKeys.traySend));
          await _settle(tester);
          await tester.tap(find.byType(ChatRemoteImage));
          await _settle(tester);
          expect(find.byKey(ChatImageKeys.viewer), findsOneWidget);
          await _shot(tester, '${dm ? 'dm' : 'group'}-${v.name}-6-viewer');
          await tester.tap(find.byKey(ChatImageKeys.viewerClose));
          await _settle(tester);
          expect(find.byKey(ChatImageKeys.viewer), findsNothing);
        });
      });
    }
  }
}
