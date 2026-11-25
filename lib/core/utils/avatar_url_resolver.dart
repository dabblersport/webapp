import 'package:dabbler/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const dsAvatarPrefix = 'ds:';

bool isDsAvatarReference(String? avatarUrlOrPath) {
  final value = avatarUrlOrPath?.trim();
  return value != null && value.startsWith(dsAvatarPrefix);
}

String? extractDsAvatarSeed(String? avatarUrlOrPath) {
  final value = avatarUrlOrPath?.trim();
  if (value == null || !value.startsWith(dsAvatarPrefix)) {
    return null;
  }

  final seed = value.substring(dsAvatarPrefix.length).trim();
  return seed.isEmpty ? null : seed;
}

String buildDsAvatarReference(String seed) {
  return '$dsAvatarPrefix${seed.trim()}';
}

String? resolveAvatarUrl(String? avatarUrlOrPath) {
  final value = avatarUrlOrPath?.trim();
  if (value == null || value.isEmpty) return null;

  if (isDsAvatarReference(value)) return null;

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  return Supabase.instance.client.storage
      .from(SupabaseConfig.avatarsBucket)
      .getPublicUrl(value);
}

/// The value a network image loader may fetch for an avatar, or null.
///
/// A `ds:` reference is a design-system portrait seed, not a URL: handing it to
/// `Image.network` makes the browser issue a request for `ds:profile:...`, which
/// fails (CORS, ERR_FAILED) and is blocked by the CSP (KAN-1043). Every avatar
/// value passed to a design-system `imageUrl`/`imageUrls` goes through this, so
/// a `ds:` value draws the seed portrait instead.
String? avatarImageUrl(String? avatarUrlOrPath) {
  final value = avatarUrlOrPath?.trim();
  if (value == null || value.isEmpty) return null;
  if (isDsAvatarReference(value)) return null;
  return value;
}
