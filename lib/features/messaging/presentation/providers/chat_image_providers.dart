import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/image_policy.dart';
import 'package:dabbler/features/messaging/domain/messaging_image_repository.dart';
import 'package:dabbler/features/messaging/domain/picked_image.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';

/// Where a chat image comes from (frame 31): the OS photo library, the OS
/// camera, or the OS file picker restricted to image extensions.
enum ChatImageSource { gallery, camera, file }

/// Why a pick produced less than the user asked for.
enum ChatPickProblem {
  cameraDenied,
  libraryDenied,
  unsupportedType,
  tooLarge,
  failed,
}

/// The result of one pick. Cancelling the picker is no images and no problem.
/// When some files are valid and some are not, [images] holds the valid ones
/// and [problem] the first refusal.
class ChatPickOutcome {
  const ChatPickOutcome({this.images = const [], this.problem});
  final List<PickedImage> images;
  final ChatPickProblem? problem;
}

/// Opens a picker for [source] and returns at most [remaining] checked
/// images. Overridable by tests; the real one is [pickChatImages].
typedef ChatImagePicker =
    Future<ChatPickOutcome> Function(
      ChatImageSource source, {
      required int remaining,
    });

final chatImagePickerProvider = Provider<ChatImagePicker>(
  (ref) => pickChatImages,
);

/// The image operations of the active messaging backend. A backend without
/// them (a test mock) is the unavailable one, which fails every call.
final chatImageRepositoryProvider = Provider<MessagingImageRepository>((ref) {
  final repo = ref.watch(messagingRepositoryProvider);
  if (repo is MessagingImageRepository) return repo as MessagingImageRepository;
  return const UnavailableMessagingRepository();
});

/// The bearer an image read needs, fetched fresh each time a thread opens so
/// an hour-old token is never reused. Null means the backend needs none.
final chatImageHeadersProvider =
    FutureProvider.autoDispose<Map<String, String>?>(
      (ref) => ref.watch(chatImageRepositoryProvider).authHeaders(),
    );

/// The real picker. Photos are downscaled and re-encoded by the OS picker
/// (which also turns an iOS HEIC photo into JPEG); every file is read into
/// memory and checked against the policy by its real bytes, so a renamed file
/// is refused here and, again, by the server.
Future<ChatPickOutcome> pickChatImages(
  ChatImageSource source, {
  required int remaining,
}) async {
  try {
    final raw = <({String name, Uint8List bytes})>[];
    switch (source) {
      case ChatImageSource.gallery:
        final files = await ImagePicker().pickMultiImage(
          maxWidth: MessagingImagePolicy.pickerMaxDimension.toDouble(),
          maxHeight: MessagingImagePolicy.pickerMaxDimension.toDouble(),
          imageQuality: MessagingImagePolicy.pickerQuality,
        );
        for (final f in files.take(remaining)) {
          raw.add((name: f.name, bytes: await f.readAsBytes()));
        }
      case ChatImageSource.camera:
        final f = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: MessagingImagePolicy.pickerMaxDimension.toDouble(),
          maxHeight: MessagingImagePolicy.pickerMaxDimension.toDouble(),
          imageQuality: MessagingImagePolicy.pickerQuality,
        );
        if (f != null) raw.add((name: f.name, bytes: await f.readAsBytes()));
      case ChatImageSource.file:
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: MessagingImagePolicy.extensions,
          allowMultiple: true,
          withData: true,
        );
        for (final f in (picked?.files ?? const <PlatformFile>[]).take(
          remaining,
        )) {
          final bytes = f.bytes;
          if (bytes != null) raw.add((name: f.name, bytes: bytes));
        }
    }
    return classifyPicked(raw);
  } on PlatformException catch (e) {
    final code = e.code.toLowerCase();
    if (code.contains('camera_access')) {
      return const ChatPickOutcome(problem: ChatPickProblem.cameraDenied);
    }
    if (code.contains('photo_access') || code.contains('permission')) {
      return const ChatPickOutcome(problem: ChatPickProblem.libraryDenied);
    }
    return const ChatPickOutcome(problem: ChatPickProblem.failed);
  } catch (_) {
    return const ChatPickOutcome(problem: ChatPickProblem.failed);
  }
}

/// Checks each picked file by its bytes: valid ones become [PickedImage]s,
/// the first refusal becomes the problem.
ChatPickOutcome classifyPicked(List<({String name, Uint8List bytes})> raw) {
  final images = <PickedImage>[];
  ChatPickProblem? problem;
  for (final f in raw) {
    final issue = MessagingImagePolicy.check(f.bytes);
    if (issue == null) {
      images.add(
        PickedImage(
          name: f.name,
          bytes: f.bytes,
          mimeType: MessagingImagePolicy.sniff(f.bytes)!,
        ),
      );
    } else {
      problem ??= issue == ImageProblem.tooLarge
          ? ChatPickProblem.tooLarge
          : ChatPickProblem.unsupportedType;
    }
  }
  return ChatPickOutcome(images: images, problem: problem);
}
