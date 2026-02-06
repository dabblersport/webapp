import 'package:cached_network_image/cached_network_image.dart';

class ImageCacheService {
  static Future<void> invalidateUrl(String url) async {
    try {
      await CachedNetworkImage.evictFromCache(url);
    } catch (_) {}
  }
}
