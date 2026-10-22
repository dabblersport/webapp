import 'dart:typed_data';

/// Why a picked file cannot be sent as a message image (KAN-581).
enum ImageProblem { unsupportedType, tooLarge }

/// The image rules of a chat (KAN-581), in one place.
///
/// Every number is a PROVISIONAL recommendation: the CEO has not approved a
/// format list, a size, a count or a compression rule yet (ticket checks 7 and
/// 8), so changing one is a change to this file and to
/// `workers/messaging/src/media_policy.ts`, which enforces the same values on
/// the server. A test pins the two together. The server is the authority: this
/// check only saves a round trip, it never replaces the server's real-type and
/// size check.
abstract final class MessagingImagePolicy {
  /// Largest image the app will upload (after the picker's own downscale).
  static const int maxBytes = 10 * 1024 * 1024;

  /// Images that can wait in the tray at once. The thread draws one image per
  /// message (the design system's Message has one attachment slot), so a tray
  /// of N is sent as N messages.
  static const int maxPerTray = 4;

  /// Longest side, in pixels, the picker downscales a photo to before upload.
  static const int pickerMaxDimension = 2048;

  /// JPEG quality the picker re-encodes with (also turns an iOS HEIC photo
  /// into JPEG, which the server accepts).
  static const int pickerQuality = 85;

  /// The only extensions the file picker offers.
  static const List<String> extensions = ['jpg', 'jpeg', 'png', 'webp'];

  /// Smallest byte count that can hold an image header.
  static const int minBytes = 24;

  /// The real type of [b] from its signature, or null when it is not a JPEG,
  /// PNG or WebP. Mirrors the server's `sniffImage`.
  static String? sniff(Uint8List b) {
    if (b.length < minBytes) return null;
    if (b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) return 'image/jpeg';
    const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    var isPng = true;
    for (var i = 0; i < png.length; i++) {
      if (b[i] != png[i]) isPng = false;
    }
    if (isPng) return 'image/png';
    bool at(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        if (b[offset + i] != s.codeUnitAt(i)) return false;
      }
      return true;
    }

    if (at(0, 'RIFF') && at(8, 'WEBP')) return 'image/webp';
    return null;
  }

  /// The problem with [bytes], or null when they can be uploaded.
  static ImageProblem? check(Uint8List bytes) {
    if (bytes.length > maxBytes) return ImageProblem.tooLarge;
    if (sniff(bytes) == null) return ImageProblem.unsupportedType;
    return null;
  }
}
