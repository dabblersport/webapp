import 'package:flutter/material.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/features/social/providers/post_providers.dart'
    show myReactionsProvider, postActionsProvider;

const _newsReactions = [
  _NewsReaction(id: 'bbcccbeb-e506-4906-8a58-018659d0a43d', emoji: '❤️', label: 'Loving'),
  _NewsReaction(id: '477472a9-7535-42b6-b08d-d6054eee9856', emoji: '💪', label: 'Determined'),
  _NewsReaction(id: '350a7cca-b044-4b22-8c96-add0dd39c059', emoji: '🔥', label: 'Motivated'),
  _NewsReaction(id: '177211d5-73a4-4835-a7f2-48fd238c778d', emoji: '🏅', label: 'Proud'),
  _NewsReaction(id: 'f4a9f402-2dbd-40a9-8a6c-61cbea065145', emoji: '🥲', label: 'Disappointed'),
  _NewsReaction(id: '4af43b42-a0f3-4008-812b-0b40548e32f6', emoji: '😡', label: 'Angry'),
];

class _NewsReaction {
  const _NewsReaction({required this.id, required this.emoji, required this.label});
  final String id;
  final String emoji;
  final String label;
}

final newsReactionCountsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, newsId) async {
  final db = Supabase.instance.client;
  final allowedIds = _newsReactions.map((r) => r.id).toList();
  final rows = await db
      .from(SupabaseConfig.reactionsTable)
      .select('vibe_id')
      .eq('parent_activity_id', newsId)
      .inFilter('vibe_id', allowedIds) as List;
  final counts = <String, int>{};
  for (final row in rows) {
    final id = row['vibe_id'] as String;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
});

/// Facebook-style collapsed reaction button.
/// - Tap: toggle the active reaction (or default ❤️ Loving).
/// - Long-press: show floating emoji picker above the button.
class NewsLikeBar extends ConsumerStatefulWidget {
  const NewsLikeBar({
    super.key,
    required this.newsId,
    this.onCommentTap,
  });

  final String newsId;
  final VoidCallback? onCommentTap;

  @override
  ConsumerState<NewsLikeBar> createState() => _NewsLikeBarState();
}

class _NewsLikeBarState extends ConsumerState<NewsLikeBar> {
  OverlayEntry? _overlayEntry;
  final _buttonKey = GlobalKey();

  void _showPicker(Set<String> myReactions, Map<String, int> counts) {
    if (_overlayEntry != null) return;
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlayEntry = OverlayEntry(
      builder: (_) => _ReactionPickerOverlay(
        anchorOffset: offset,
        anchorSize: size,
        myReactions: myReactions,
        onSelect: (reaction) {
          _hidePicker();
          _toggleReaction(reaction, myReactions);
        },
        onDismiss: _hidePicker,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hidePicker() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _toggleReaction(_NewsReaction reaction, Set<String> myReactions) async {
    if (myReactions.contains(reaction.id)) {
      await ref.read(postActionsProvider.notifier).removeReaction(widget.newsId, reaction.id);
    } else {
      for (final id in myReactions) {
        await ref.read(postActionsProvider.notifier).removeReaction(widget.newsId, id);
      }
      await ref.read(postActionsProvider.notifier).reactToPost(widget.newsId, reaction.id);
    }
    ref.invalidate(newsReactionCountsProvider(widget.newsId));
    ref.invalidate(myReactionsProvider(widget.newsId));
  }

  @override
  void dispose() {
    _hidePicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final myReactions =
        ref.watch(myReactionsProvider(widget.newsId)).valueOrNull ?? const <String>{};
    final counts =
        ref.watch(newsReactionCountsProvider(widget.newsId)).valueOrNull ?? {};

    final activeReaction = _newsReactions.firstWhere(
      (r) => myReactions.contains(r.id),
      orElse: () => _newsReactions.first,
    );
    final hasReacted = myReactions.isNotEmpty;
    final totalCount = counts.values.fold(0, (a, b) => a + b);

    return GestureDetector(
      key: _buttonKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleReaction(activeReaction, myReactions),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showPicker(myReactions, counts);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasReacted ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(activeReaction.emoji, style: const TextStyle(fontSize: 17)),
            // const SizedBox(width: 5),
            // Text(
            //   hasReacted ? activeReaction.label : 'Like',
            //   style: tt.bodySmall?.copyWith(
            //     color: hasReacted ? cs.primary : cs.onSurfaceVariant,
            //     fontWeight: hasReacted ? FontWeight.w600 : FontWeight.w500,
            //   ),
            // ),
            if (totalCount > 0) ...[
              const SizedBox(width: 5),
              Text(
                _fmtCount(totalCount),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _fmtCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// ---------------------------------------------------------------------------

class _ReactionPickerOverlay extends StatefulWidget {
  const _ReactionPickerOverlay({
    required this.anchorOffset,
    required this.anchorSize,
    required this.myReactions,
    required this.onSelect,
    required this.onDismiss,
  });

  final Offset anchorOffset;
  final Size anchorSize;
  final Set<String> myReactions;
  final void Function(_NewsReaction) onSelect;
  final VoidCallback onDismiss;

  @override
  State<_ReactionPickerOverlay> createState() => _ReactionPickerOverlayState();
}

class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const itemSize = 44.0;
    const pickerPadH = 10.0;
    const pickerPadV = 8.0;
    const pickerHeight = itemSize + pickerPadV * 2;
    final pickerWidth = _newsReactions.length * itemSize + pickerPadH * 2;

    final screenWidth = MediaQuery.of(context).size.width;
    double left = widget.anchorOffset.dx + widget.anchorSize.width / 2 - pickerWidth / 2;
    left = left.clamp(8.0, screenWidth - pickerWidth - 8.0);
    final top = widget.anchorOffset.dy - pickerHeight - 10;

    return Stack(
      children: [
        // Dismiss backdrop
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: ScaleTransition(
            scale: _scale,
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: pickerHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: pickerPadH,
                  vertical: pickerPadV,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_newsReactions.length, (i) {
                    final reaction = _newsReactions[i];
                    final selected = widget.myReactions.contains(reaction.id);
                    final hovered = _hoveredIndex == i;
                    final enlarged = hovered || selected;
                    return MouseRegion(
                      onEnter: (_) => setState(() => _hoveredIndex = i),
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: GestureDetector(
                        onTap: () => widget.onSelect(reaction),
                        child: SizedBox(
                          width: itemSize,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..translateByDouble(0.0, enlarged ? -6.0 : 0.0, 0.0, 1.0),
                            child: Tooltip(
                              message: reaction.label,
                              preferBelow: false,
                              child: Text(
                                reaction.emoji,
                                style: TextStyle(fontSize: enlarged ? 28 : 22),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
