import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
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

/// The frames of the dots: one bullet travelling across three. The glyphs are
/// Latin-1 / General Punctuation characters every design-system face carries.
const List<String> typingDotFrames = <String>['•··', '·•·', '··•'];

/// Held still (reduced motion): all three dots.
const String typingDotsStill = '•••';

/// Which frame of [typingDotFrames] to show; only ticks while it is watched,
/// so nothing runs unless someone is typing.
final typingDotsFrameProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream<int>.periodic(
    const Duration(milliseconds: typingDotsFrameMs),
    (i) => (i + 1) % typingDotFrames.length,
  ),
);

/// The "is typing" row as a MESSAGE OF THE THREAD (KAN-579), or null while
/// nobody is typing. It is an incoming [DabblerThreadMessage], so it lives in
/// the thread's own scroll content, takes the message geometry of the design
/// (section 10) from the design system and is replaced in place by the real
/// message when it arrives:
///
/// * group: the first typer's avatar in the 28 px gutter, the label on the
///   sender line above the bubble, a single-line incoming bubble;
/// * direct: the bubble only, no gutter and no label (the header says
///   "typing…").
///
/// The dots are the bubble's text ([typingDotFrames], stepped every
/// [typingDotsFrameMs] ms; static under reduced motion). The design's pulsing
/// 4 px dots are not expressible as message content, so the glyphs approximate
/// them; a screen reader reads the label in a group and the dot glyphs in a
/// direct chat (DS GAP: a DS `TypingRow` would carry its own semantics).
///
/// The row fades in once over `--motion-slow` when it mounts (design 10;
/// [DabblerThreadMessage.fresh]); the design system skips the fade under
/// reduced motion. It keeps one id, so the dots ticking never replays it.
DabblerThreadMessage? typingThreadItem(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n, {
  required String conversationId,
  required bool isDm,
}) {
  if (conversationId.isEmpty) return null;
  final typers = ref.watch(typingPresenceProvider(conversationId));
  if (typers.isEmpty) return null;
  final still = DabblerMotion.reduceMotion(context);
  final frame = still
      ? 0
      : (ref.watch(typingDotsFrameProvider).valueOrNull ?? 0);
  final dots = still ? typingDotsStill : typingDotFrames[frame];
  if (isDm) {
    return DabblerThreadMessage(
      id: _typingId,
      content: dots,
      showAvatar: false,
      showSender: false,
      fresh: true,
    );
  }
  final names = <String>[
    for (final id in typers.take(typingNamedPeople)) _nameOf(ref, id) ?? '',
  ];
  return DabblerThreadMessage(
    id: _typingId,
    sender: groupTypingLabel(l10n, names: names, total: typers.length),
    avatarSeed: typers.first,
    content: dots,
    showAvatar: true,
    showSender: true,
    fresh: true,
  );
}

const String _typingId = 'typing-row';

String? _nameOf(WidgetRef ref, String userId) {
  final profile = ref.watch(profileByUserIdProvider(userId)).valueOrNull;
  return profile?.fold((_) => null, (p) => p.displayName);
}
