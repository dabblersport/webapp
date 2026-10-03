import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// Opens the vibe picker for [postId] as a design-system sheet.
///
/// Same behaviour as the shared `ReactionPickerSheet`: tapping a vibe adds the
/// reaction, or removes it when [myReactions] already holds it, and the sheet
/// closes after a single tap.
Future<void> showHomeReactionSheet(
  BuildContext context, {
  required String postId,
  required Set<String> myReactions,
  String title = 'React with a Vibe',
}) {
  return showDabblerSheet<void>(
    context: context,
    title: title,
    detents: const <double>[0.5],
    builder: (_) => HomeReactionSheet(postId: postId, myReactions: myReactions),
  );
}

/// The sheet's content: every vibe as a [DabblerChip].
class HomeReactionSheet extends ConsumerWidget {
  const HomeReactionSheet({
    super.key,
    required this.postId,
    required this.myReactions,
  });

  final String postId;

  /// Vibe IDs the current user has already reacted with.
  final Set<String> myReactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibesAsync = ref.watch(vibesProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space2,
        DabblerSpacing.space6,
        DabblerSpacing.space8,
      ),
      child: vibesAsync.when(
        data: (vibes) {
          if (vibes.isEmpty) {
            return DabblerText(
              'No vibes available',
              style: DabblerType.body,
              tone: DabblerTextTone.secondary,
            );
          }
          return Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: [
              for (final vibe in vibes)
                DabblerChip(
                  label: _label(vibe),
                  selected: myReactions.contains(vibe.id),
                  onTap: () => _toggle(
                    context,
                    ref,
                    vibe,
                    myReactions.contains(vibe.id),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: DabblerSpinner()),
        error: (e, _) => DabblerText(
          'Failed to load vibes: $e',
          style: DabblerType.body,
          tone: DabblerTextTone.secondary,
        ),
      ),
    );
  }

  static String _label(Vibe vibe) {
    final emoji = vibe.emoji ?? '';
    final name = vibe.labelEn.isNotEmpty
        ? vibe.labelEn
        : vibe.key[0].toUpperCase() + vibe.key.substring(1);
    return emoji.isEmpty ? name : '$emoji $name';
  }

  void _toggle(BuildContext context, WidgetRef ref, Vibe vibe, bool selected) {
    final actions = ref.read(postActionsProvider.notifier);
    if (selected) {
      actions.removeReaction(postId, vibe.id);
    } else {
      actions.reactToPost(postId, vibe.id);
    }
    Navigator.of(context).pop();
  }
}
