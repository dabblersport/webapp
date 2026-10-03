import 'package:flutter/painting.dart' show NetworkImage;

/// Evicts a network image from Flutter's in-memory image cache so the next
/// load fetches the new bytes (used after an avatar changes).
class ImageCacheService {
  static Future<void> invalidateUrl(String url) async {
    try {
      await NetworkImage(url).evict();
    } catch (_) {}
  }
}
