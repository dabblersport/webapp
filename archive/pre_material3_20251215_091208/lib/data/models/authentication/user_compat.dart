/// Backwards-compatible extensions for legacy getters expected by older UI widgets.
library;

import 'user.dart';

extension UserCompat on User {
  String get displayName =>
      fullName ?? username ?? email?.split('@').first ?? '';
  String? get profileImageUrl => avatarUrl;
}
