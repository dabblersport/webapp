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
