import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The email the user is typing in the sign-in flow, carried between
/// `/email_input` and `/enter-password` so neither screen asks for it twice.
/// Kept in memory only (not in the URL), so it is gone after a full reload.
class PendingAuthEmail extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value.trim();
}

final pendingAuthEmailProvider = NotifierProvider<PendingAuthEmail, String>(
  PendingAuthEmail.new,
);
