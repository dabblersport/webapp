import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart';
import 'package:dabbler/features/messaging/domain/typing.dart';
import 'package:dabbler/features/messaging/presentation/providers/typing_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// First-strong isolate (U+2068 .. U+2069) around a person's name, so a Latin
/// name inside an Arabic sentence (or the reverse) keeps its own direction and
/// the sentence keeps its word order.
String isolateName(String name) => '\u2068$name\u2069';

/// The typing label of a group (design section 10): one name, two names, or
/// the first name and a count of the others. [names] holds the typers' names
/// in the order they started (only the first two are read; an empty entry
/// reads as "Someone"); [total] is how many are typing.
String groupTypingLabel(
  AppLocalizations l10n, {
  required List<String> names,
  required int total,
}) {
  String at(int i) => i < names.length && names[i].trim().isNotEmpty
      ? isolateName(names[i].trim())
      : l10n.messaging_typing_someone;
  if (total <= 1) return l10n.messaging_typing_one(at(0));
  if (total == 2) return l10n.messaging_typing_two(at(0), at(1));
  return l10n.messaging_typing_many(at(0), total - 1);
}

/// The "is typing" row at the end of the thread (KAN-579), or null while
/// nobody is typing. It is the design system's own [DabblerThreadTyping] item,
/// so it sits IN the thread (the arriving message takes its place) and the
/// dots, bubble and reduced-motion behaviour are the system's.
///
/// A direct chat shows the dots bubble only (the header says "typing…"); a
/// group adds the label ([groupTypingLabel]) of the typers, whose names come
/// from their public profiles and fall back to "Someone".
///
/// DS GAP (reported on KAN-579): the design's `TypingRow` puts the first
/// typer's avatar in the 28 px gutter, the label on the sender line above the
/// bubble, and has no gutter in a direct chat. [DabblerThreadTyping] always
/// insets the bubble by the gutter and puts the label beside it, with no avatar.
DabblerThreadTyping? typingThreadItem(
  WidgetRef ref,
  AppLocalizations l10n, {
  required String conversationId,
  required bool isDm,
}) {
  if (conversationId.isEmpty) return null;
  final typers = ref.watch(typingPresenceProvider(conversationId));
  if (typers.isEmpty) return null;
  if (isDm) return const DabblerThreadTyping();
  final names = <String>[
    for (final id in typers.take(typingNamedPeople)) _nameOf(ref, id) ?? '',
  ];
  return DabblerThreadTyping(
    names: names,
    label: groupTypingLabel(l10n, names: names, total: typers.length),
  );
}

String? _nameOf(WidgetRef ref, String userId) {
  final profile = ref.watch(profileByUserIdProvider(userId)).valueOrNull;
  return profile?.fold((_) => null, (p) => p.displayName);
}
