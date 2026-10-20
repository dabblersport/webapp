import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart';
import 'package:dabbler/features/messaging/domain/typing.dart';
import 'package:dabbler/features/messaging/presentation/providers/typing_providers.dart';
import 'package:dabbler/features/messaging/presentation/widgets/typing_thread_item.dart';
import 'package:dabbler/l10n/app_localizations.dart';

abstract final class TypingRowKeys {
  static const row = ValueKey<String>('messaging-typing-row');
  static const label = ValueKey<String>('messaging-typing-label');
  static const bubble = ValueKey<String>('messaging-typing-bubble');
  static const avatar = ValueKey<String>('messaging-typing-avatar');
}

/// The "is typing" row under the thread (KAN-579), built on a message's own
/// geometry (`MESSAGING_DS_ADDITIONS.md` section 10, frames 25-26, 44, 47-48):
/// a single-line bubble of the incoming shape holding the three dots.
///
/// * Group: the FIRST typer's avatar in the 28 px gutter, a 6 px gap, and the
///   label on the sender line ABOVE the bubble.
/// * Direct: the bubble only, no gutter and no label (the header says
///   "typing…").
///
/// Draws nothing while nobody is typing. The fade-in is skipped under reduced
/// motion; the dots are the design system's [DabblerTypingIndicator], which
/// holds still then.
///
/// DS GAP: the design system has no `TypingRow` (the design section 10 says it
/// adds one), only [DabblerThreadTyping], whose geometry differs (always
/// gutter-inset, label beside the bubble, no avatar). This row is built from
/// DS tokens, [DabblerAvatar], [DabblerText] and [DabblerTypingIndicator]; its
/// bubble is the one hand-built surface and has a reasoned entry in the design
/// gate's fidelity allow-list. Delete this file when the DS ships `TypingRow`.
class ChatTypingRow extends ConsumerWidget {
  const ChatTypingRow({
    super.key,
    required this.conversationId,
    required this.isDm,
    this.dmName,
  });

  final String conversationId;
  final bool isDm;

  /// The counterpart's name, for the screen-reader sentence of a direct chat.
  final String? dmName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (conversationId.isEmpty) return const SizedBox.shrink();
    final typers = ref.watch(typingPresenceProvider(conversationId));
    if (typers.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    String? label;
    if (!isDm) {
      final names = <String>[
        for (final id in typers.take(typingNamedPeople)) _nameOf(ref, id) ?? '',
      ];
      label = groupTypingLabel(l10n, names: names, total: typers.length);
    }
    final spoken =
        label ??
        ((dmName ?? '').trim().isEmpty
            ? l10n.messaging_typing_dm
            : l10n.messaging_typing_one(isolateName(dmName!.trim())));
    return _TypingRowBody(
      key: TypingRowKeys.row,
      label: label,
      spoken: spoken,
      avatarSeed: typers.first,
    );
  }

  String? _nameOf(WidgetRef ref, String userId) {
    final profile = ref.watch(profileByUserIdProvider(userId)).valueOrNull;
    return profile?.fold((_) => null, (p) => p.displayName);
  }
}

class _TypingRowBody extends StatelessWidget {
  const _TypingRowBody({
    super.key,
    required this.label,
    required this.spoken,
    required this.avatarSeed,
  });

  /// Non-null in a group.
  final String? label;
  final String spoken;
  final String avatarSeed;

  bool get _group => label != null;

  /// A single-line message bubble is 40 high: the arriving message takes
  /// exactly this box.
  static const double _bubbleMinHeight = 40;

  /// The message's width cap (`maxWidth: 76%`).
  static const double _maxWidthFraction = 0.76;

  static const double _gutterAndGap =
      DabblerMessagingSpacing.avatarGutter + DabblerMessagingSpacing.avatarGap;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final bubble = DecoratedBox(
      key: TypingRowKeys.bubble,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        border: Border.all(
          color: colors.borderDefault,
          width: DabblerSizing.borderDefault,
        ),
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(DabblerRadius.xl),
          topEnd: Radius.circular(DabblerRadius.xl),
          bottomEnd: Radius.circular(DabblerRadius.xl),
          bottomStart: Radius.circular(DabblerRadius.sm),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _bubbleMinHeight),
        child: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: DabblerMessagingSpacing.bubbleBlock,
            horizontal: DabblerMessagingSpacing.bubbleInline,
          ),
          child: Center(
            widthFactor: 1,
            child: DabblerTypingIndicator(dotsOnly: true),
          ),
        ),
      ),
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_group) ...<Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: DabblerSpacing.space1,
            ),
            child: DabblerText(
              label!,
              key: TypingRowKeys.label,
              style: DabblerType.caption1,
              weight: DabblerTextWeight.semibold,
              tone: DabblerTextTone.secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: DabblerMessagingSpacing.metaGap),
        ],
        bubble,
      ],
    );

    Widget row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerMessagingSpacing.timelineInline,
        vertical: DabblerMessagingSpacing.messageGap,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final cap =
              (box.maxWidth - (_group ? _gutterAndGap : 0)) * _maxWidthFraction;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (_group) ...<Widget>[
                SizedBox(
                  width: DabblerMessagingSpacing.avatarGutter,
                  child: DabblerAvatar(
                    key: TypingRowKeys.avatar,
                    seed: avatarSeed,
                    size: DabblerAvatarSize.xs,
                  ),
                ),
                const SizedBox(width: DabblerMessagingSpacing.avatarGap),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cap),
                  child: column,
                ),
              ),
            ],
          );
        },
      ),
    );

    row = Semantics(
      liveRegion: true,
      label: spoken,
      child: ExcludeSemantics(child: row),
    );
    return DabblerMotion.reduceMotion(context)
        ? row
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: DabblerMotion.slow,
            curve: DabblerMotion.easeOut,
            builder: (context, t, child) => FadeTransition(
              opacity: AlwaysStoppedAnimation<double>(t),
              child: child,
            ),
            child: row,
          );
  }
}
