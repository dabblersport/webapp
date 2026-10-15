import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/core/utils/avatar_url_resolver.dart';

/// The avatar of a DM row: the seed portrait and, when the reference names a
/// photo, its URL. A `ds:` reference is a seed portrait; an http(s) URL is
/// used as is; a storage path is resolved through [resolve] (the avatars
/// bucket). Anything missing, or a resolve that fails, keeps the portrait for
/// [fallbackSeed], the counterpart's user id.
({String seed, String? imageUrl}) messagesListDmAvatar(
  String? reference,
  String fallbackSeed, {
  String? Function(String?) resolve = resolveAvatarUrl,
}) {
  final dsSeed = extractDsAvatarSeed(reference);
  if (dsSeed != null) return (seed: dsSeed, imageUrl: null);
  String? url;
  try {
    url = resolve(reference);
  } catch (_) {
    url = null;
  }
  return (
    seed: fallbackSeed,
    imageUrl: (url == null || url.isEmpty) ? null : url,
  );
}

/// One direct-message row of the Messages list (KAN-562): a
/// [DabblerConversationRow] of kind `player` (one person, no kind tile).
///
/// It shows the name, a quiet sport-free label ([kindLabel]), the relative
/// time, the row's own muted glyph and, for a read-only DM, a neutral
/// [DabblerConversationState] badge — never a preview, sender or unread mark.
/// The avatar is the DS seed portrait for [avatarSeed]: the pinned alpha-ds
/// row has no photo slot (its `DabblerConversationAvatar` takes a seed only),
/// so a photo reference cannot be drawn here yet — reported as a design gap.
class MessagesListDmRow extends StatelessWidget {
  const MessagesListDmRow({
    super.key,
    required this.name,
    required this.avatarSeed,
    required this.timestamp,
    required this.kindLabel,
    required this.mutedLabel,
    this.muted = false,
    this.readOnlyLabel,
    this.divider = true,
    this.onTap,
  });

  final String name;
  final String avatarSeed;
  final String timestamp;

  /// The quiet label under the name (e.g. "Direct message").
  final String kindLabel;

  /// Accessible text for the muted mark (the row's glyph is decoration).
  final String mutedLabel;
  final bool muted;

  /// Shown as a neutral state badge when the DM is read-only; null otherwise.
  final String? readOnlyLabel;
  final bool divider;
  final VoidCallback? onTap;

  /// The accessible name: name, time, muted, read-only, kind label.
  String composedLabel() => [
    name,
    if (timestamp.isNotEmpty) timestamp,
    if (muted) mutedLabel,
    if (readOnlyLabel != null) readOnlyLabel!,
    kindLabel,
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final label = readOnlyLabel;
    return DabblerConversationRow(
      kind: DabblerConversationKind.player,
      seed: avatarSeed,
      title: name,
      timestamp: timestamp,
      muted: muted,
      state: label == null ? null : DabblerConversationState(label: label),
      kindLabel: kindLabel,
      divider: divider,
      onTap: onTap,
      semanticLabel: composedLabel(),
    );
  }
}
