/// A GIF in a chat (KAN-582).
///
/// The messaging backend has one text kind and no media kind, and no provider
/// or secret is added for this ticket: a GIF is sent as an ordinary text
/// message whose whole body is the GIPHY media URL the existing picker
/// (`showGifPickerSheet`) returns. The recipient's thread draws such a body as
/// an image instead of as text. Nothing is stored beyond the message row that
/// already exists, and every existing rule (membership, mute, block, rate
/// limits, reporting) applies to it unchanged.
///
/// Only a body that is exactly one `https` URL on a GIPHY host, ending in an
/// image extension, is a GIF; anything else stays text, so typing a link or any
/// other host never loads a remote image.
String? gifUrlOfBody(String body) {
  final text = body.trim();
  if (text.isEmpty || text.length > _maxUrlLength) return null;
  if (RegExp(r'\s').hasMatch(text)) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return null;
  }
  if (uri.hasPort && uri.port != 443) return null;
  final host = uri.host.toLowerCase();
  if (host != 'giphy.com' && !host.endsWith('.giphy.com')) return null;
  final path = uri.path.toLowerCase();
  if (!path.endsWith('.gif') && !path.endsWith('.webp')) return null;
  return text;
}

/// A message body longer than this is never read as a GIF URL.
const int _maxUrlLength = 600;
