import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// An image the user chose, already read into memory and checked against
/// `MessagingImagePolicy` (KAN-581). [mimeType] is the real type from the
/// bytes, never the file name's.
class PickedImage extends Equatable {
  const PickedImage({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;

  @override
  List<Object?> get props => [name, bytes.length, mimeType];
}
