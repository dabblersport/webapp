import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/worker_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/image_policy.dart';
import 'package:dabbler/features/messaging/domain/messaging_image_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/picked_image.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/providers/chat_image_providers.dart';

// Clearly-fake fixture; nothing here touches the network (MockClient).
const _base = 'https://worker.example.invalid';

/// A real 1x1 PNG.
final Uint8List png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Uint8List padded(Uint8List head, int length) {
  final out = Uint8List(length);
  out.setRange(0, head.length, head);
  return out;
}

PickedImage pickedPng([int? length]) => PickedImage(
  name: 'a.png',
  bytes: length == null ? png : padded(png, length),
  mimeType: 'image/png',
);

class Seen {
  String? method;
  Uri? url;
  Map<String, String> headers = {};
  int received = 0;
}

WorkerMessagingRepository repo(
  Seen seen, {
  required int status,
  Object? body,
  Object? throws,
}) => WorkerMessagingRepository(
  http: MessagingHttpClient(
    client: MockClient.streaming((request, bodyStream) async {
      seen
        ..method = request.method
        ..url = request.url
        ..headers = request.headers;
      if (throws != null) throw throws;
      await bodyStream.forEach((chunk) => seen.received += chunk.length);
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body ?? const {}))),
        status,
        headers: {'content-type': 'application/json'},
      );
    }),
    tokenSupplier: () async => 'tok-1',
    baseUrl: _base,
  ),
  rpc: (fn, params) async => null,
);

const _attachment = {
  'id': 'att-1',
  'mime_type': 'image/png',
  'byte_size': 67,
  'width': 1,
  'height': 1,
};

void main() {
  group('policy (AC1, AC2): the real type and size, not the name', () {
    test('JPEG, PNG and WebP bytes are accepted and named by their bytes', () {
      expect(MessagingImagePolicy.sniff(png), 'image/png');
      final jpeg = padded(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]), 64);
      expect(MessagingImagePolicy.sniff(jpeg), 'image/jpeg');
      final webp = padded(
        Uint8List.fromList([
          ...'RIFF'.codeUnits,
          0,
          0,
          0,
          0,
          ...'WEBP'.codeUnits,
        ]),
        64,
      );
      expect(MessagingImagePolicy.sniff(webp), 'image/webp');
      expect(MessagingImagePolicy.check(png), isNull);
    });

    test('a PDF, an executable, HEIC and an empty file are not images', () {
      final pdf = padded(Uint8List.fromList('%PDF-1.7'.codeUnits), 64);
      final exe = padded(Uint8List.fromList([0x4d, 0x5a, 0x90]), 64);
      final heic = padded(
        Uint8List.fromList([0, 0, 0, 24, ...'ftypheic'.codeUnits]),
        64,
      );
      for (final bytes in [pdf, exe, heic, Uint8List(0)]) {
        expect(MessagingImagePolicy.check(bytes), ImageProblem.unsupportedType);
      }
    });

    test('an image over the limit is too large', () {
      final big = padded(png, MessagingImagePolicy.maxBytes + 1);
      expect(MessagingImagePolicy.check(big), ImageProblem.tooLarge);
      final atLimit = padded(png, MessagingImagePolicy.maxBytes);
      expect(MessagingImagePolicy.check(atLimit), isNull);
    });

    test('picked files are classified by their bytes, never their names', () {
      final outcome = classifyPicked([
        (name: 'photo.jpg', bytes: png),
        (name: 'holiday.png', bytes: padded(Uint8List.fromList([1, 2, 3]), 64)),
      ]);
      expect(outcome.images.single.name, 'photo.jpg');
      expect(outcome.images.single.mimeType, 'image/png');
      expect(outcome.problem, ChatPickProblem.unsupportedType);
      final big = classifyPicked([
        (
          name: 'big.png',
          bytes: padded(png, MessagingImagePolicy.maxBytes + 1),
        ),
      ]);
      expect(big.images, isEmpty);
      expect(big.problem, ChatPickProblem.tooLarge);
    });

    test('the file picker offers image extensions only', () {
      expect(MessagingImagePolicy.extensions, ['jpg', 'jpeg', 'png', 'webp']);
    });

    test('the app and the Worker enforce the same numbers (AC2)', () {
      final ts = File(
        'workers/messaging/src/media_policy.ts',
      ).readAsStringSync();
      int constant(String name) {
        final m = RegExp('export const $name = ([0-9 *]+);').firstMatch(ts)!;
        return m
            .group(1)!
            .split('*')
            .map((p) => int.parse(p.trim()))
            .reduce((a, b) => a * b);
      }

      expect(constant('MAX_IMAGE_BYTES'), MessagingImagePolicy.maxBytes);
      expect(constant('MIN_IMAGE_BYTES'), MessagingImagePolicy.minBytes);
      // The tray holds at most what the Worker allows in one message.
      expect(
        constant('MAX_IMAGES_PER_MESSAGE'),
        greaterThanOrEqualTo(MessagingImagePolicy.maxPerTray),
      );
    });
  });

  group('Message wire shape', () {
    const base = {
      'id': 'm1',
      'conversation_id': 'c1',
      'seq': 1,
      'kind': 'text',
      'body': '',
      'created_at': '2026-10-01T10:00:00Z',
    };

    test('a text message has no attachments', () {
      expect(Message.fromJson(base).attachments, isEmpty);
      expect(Message.fromJson(base).toJson().containsKey('attachments'), false);
    });

    test('an image message carries its attachments, id only', () {
      final m = Message.fromJson({
        ...base,
        'attachments': [_attachment],
      });
      expect(m.attachments.single.id, 'att-1');
      expect(m.attachments.single.mimeType, 'image/png');
      expect(m.attachments.single.width, 1);
      expect(m.toJson()['attachments'], isNotEmpty);
    });

    test('a malformed attachment is a malformed message', () {
      expect(
        () => Message.fromJson({
          ...base,
          'attachments': [
            {'id': 1},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('uploadImage (AC1, AC2)', () {
    test(
      'streams the raw bytes with the bearer, type, key and length',
      () async {
        final seen = Seen();
        final progress = <int>[];
        final r =
            await repo(
              seen,
              status: 201,
              body: {'attachment': _attachment},
            ).uploadImage(
              conversationId: 'c1',
              image: pickedPng(),
              idempotencyKey: 'up-1',
              onProgress: (sent, total) => progress.add(sent),
            );
        expect(seen.method, 'POST');
        expect(seen.url!.path, '/v1/conversations/c1/attachments');
        expect(seen.headers['Authorization'], 'Bearer tok-1');
        expect(seen.headers['Idempotency-Key'], 'up-1');
        expect(seen.headers['Content-Type'], 'image/png');
        expect(seen.received, png.length);
        expect(progress.last, png.length);
        expect(r.requireValue.id, 'att-1');
      },
    );

    test('progress is reported chunk by chunk and ends at the total', () async {
      final seen = Seen();
      final big = pickedPng(messagingUploadChunkBytes * 3 + 10);
      final steps = <double>[];
      await repo(
        seen,
        status: 201,
        body: {'attachment': _attachment},
      ).uploadImage(
        conversationId: 'c1',
        image: big,
        idempotencyKey: 'up-2',
        onProgress: (sent, total) => steps.add(sent / total),
      );
      expect(steps.length, 4);
      expect(steps.last, 1.0);
      expect(steps, orderedEquals([...steps]..sort()));
    });

    test('a retry answered 200 returns the same attachment', () async {
      final r =
          await repo(
            Seen(),
            status: 200,
            body: {'attachment': _attachment},
          ).uploadImage(
            conversationId: 'c1',
            image: pickedPng(),
            idempotencyKey: 'up-1',
          );
      expect(r.requireValue.id, 'att-1');
    });

    final refusals = <(int, String, MessagingReason)>[
      (413, 'payload_too_large', MessagingReason.payloadTooLarge),
      (415, 'unsupported_media_type', MessagingReason.unsupportedMediaType),
      (403, 'not_a_member', MessagingReason.notAMember),
      (403, 'removed', MessagingReason.removed),
      (409, 'game_ended', MessagingReason.gameEnded),
      (429, 'rate_limited', MessagingReason.rateLimited),
    ];
    for (final (status, wire, reason) in refusals) {
      test('$status $wire maps to its typed reason', () async {
        final r =
            await repo(
              Seen(),
              status: status,
              body: {
                'error': {'reason': wire},
              },
            ).uploadImage(
              conversationId: 'c1',
              image: pickedPng(),
              idempotencyKey: 'up-3',
            );
        expect((r.requireError as MessagingFailure).reason, reason);
      });
    }

    test('no connection is the offline reason, not an exception', () async {
      final r =
          await repo(
            Seen(),
            status: 200,
            throws: http.ClientException('socket'),
          ).uploadImage(
            conversationId: 'c1',
            image: pickedPng(),
            idempotencyKey: 'up-4',
          );
      expect(
        (r.requireError as MessagingFailure).reason,
        MessagingReason.offline,
      );
    });

    test('cancel stops the upload part way and reports a failure', () async {
      final seen = Seen();
      final cancel = UploadCancel();
      final big = pickedPng(messagingUploadChunkBytes * 5);
      final r = await repo(seen, status: 201, body: {'attachment': _attachment})
          .uploadImage(
            conversationId: 'c1',
            image: big,
            idempotencyKey: 'up-5',
            cancel: cancel,
            onProgress: (sent, total) {
              if (sent >= messagingUploadChunkBytes) cancel.cancel();
            },
          );
      expect(r, isA<Err>());
      expect(seen.received, lessThan(big.bytes.length));
    });
  });

  group('sendImageMessage and the read address (AC2)', () {
    test(
      'binds the attachment ids, caption optional, same key rules',
      () async {
        final seen = Seen();
        final r =
            await repo(
              seen,
              status: 201,
              body: {
                'id': 'm9',
                'conversation_id': 'c1',
                'seq': 9,
                'kind': 'text',
                'body': 'look',
                'created_at': '2026-10-01T10:00:00Z',
                'attachments': [_attachment],
              },
            ).sendImageMessage(
              conversationId: 'c1',
              idempotencyKey: 'k-1',
              attachmentIds: const ['att-1'],
              caption: 'look',
            );
        expect(seen.url!.path, '/v1/conversations/c1/messages');
        expect(seen.headers['Idempotency-Key'], 'k-1');
        expect(r.requireValue.attachments.single.id, 'att-1');
      },
    );

    test('the read address is the Worker route by id, never a bucket URL', () {
      final url = repo(Seen(), status: 200).attachmentUrl('att-1');
      expect(url, '$_base/v1/attachments/att-1');
      expect(url, isNot(contains('r2')));
      expect(url, isNot(contains('supabase')));
    });

    test('the read headers carry the bearer, nothing else', () async {
      expect(await repo(Seen(), status: 200).authHeaders(), {
        'Authorization': 'Bearer tok-1',
      });
    });
  });
}
