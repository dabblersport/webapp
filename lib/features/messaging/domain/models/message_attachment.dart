import 'package:equatable/equatable.dart';

/// An image attached to a message (KAN-581): its stable id and what the
/// server recorded about it. The app never holds a URL or a bucket key; it
/// asks the Messaging API for the bytes by [id], and the Worker re-checks
/// membership on every read.
class MessageAttachment extends Equatable {
  const MessageAttachment({
    required this.id,
    required this.mimeType,
    required this.byteSize,
    this.width,
    this.height,
  });

  final String id;
  final String mimeType;
  final int byteSize;
  final int? width;
  final int? height;

  /// Throws [FormatException] on a malformed payload (the repository turns it
  /// into a failure).
  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final mime = json['mime_type'];
    final size = json['byte_size'];
    if (id is! String || mime is! String || size is! int) {
      throw const FormatException('Malformed attachment payload');
    }
    return MessageAttachment(
      id: id,
      mimeType: mime,
      byteSize: size,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mime_type': mimeType,
    'byte_size': byteSize,
    'width': width,
    'height': height,
  };

  @override
  List<Object?> get props => [id, mimeType, byteSize, width, height];
}
