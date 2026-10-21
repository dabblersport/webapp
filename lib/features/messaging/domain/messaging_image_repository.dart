import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_attachment.dart';
import 'package:dabbler/features/messaging/domain/picked_image.dart';

/// Reports how many of [total] bytes of an upload have been handed to the
/// network.
typedef UploadProgress = void Function(int sent, int total);

/// A flag the caller sets to stop an upload that is in flight.
class UploadCancel {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// The image operations of the Messaging API (KAN-581), kept apart from
/// `MessagingRepository` (the six contract operations) the way `DmRepository`
/// is. Flow: [uploadImage] stores the bytes in the private object store behind
/// the Worker and returns an attachment id; [sendImageMessage] binds ids to a
/// new message; [attachmentUrl] + [authHeaders] read the bytes back through
/// the same authorisation. Every method returns a `Result` and never throws.
abstract class MessagingImageRepository {
  /// Uploads [image] to [conversationId]. [idempotencyKey] is created once per
  /// image and reused on a retry: a repeat returns the SAME attachment.
  /// Reasons: not_a_member, removed, left_read_only, game_ended,
  /// game_cancelled, blocked, suspended, rate_limited, payload_too_large,
  /// unsupported_media_type, invalid_request (+ offline).
  Future<Result<MessageAttachment, Failure>> uploadImage({
    required String conversationId,
    required PickedImage image,
    required String idempotencyKey,
    UploadProgress? onProgress,
    UploadCancel? cancel,
  });

  /// Sends a message that carries [attachmentIds] (the caller's own uploads to
  /// this conversation) and an optional [caption]. Idempotent on
  /// [idempotencyKey] like a text send.
  Future<Result<Message, Failure>> sendImageMessage({
    required String conversationId,
    required String idempotencyKey,
    required List<String> attachmentIds,
    String caption = '',
  });

  /// The authorised read address of an attachment. It is not a public URL: it
  /// answers only with the caller's [authHeaders].
  String attachmentUrl(String attachmentId);

  /// The request headers an image read needs (the bearer), or null when the
  /// backend needs none (the in-memory fake).
  Future<Map<String, String>?> authHeaders();
}
