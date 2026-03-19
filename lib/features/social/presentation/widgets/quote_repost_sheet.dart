import 'package:dabbler/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// Bottom sheet for composing a quote repost.
///
/// Shows a text field for quote text plus a preview of the original post,
/// and calls [PostActionsNotifier.repostPost] on submit.
class QuoteRepostSheet extends ConsumerStatefulWidget {
  const QuoteRepostSheet({super.key, required this.originalPost});

  final Post originalPost;

  @override
  ConsumerState<QuoteRepostSheet> createState() => _QuoteRepostSheetState();
}

class _QuoteRepostSheetState extends ConsumerState<QuoteRepostSheet> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final quote = _controller.text.trim();
    if (quote.isEmpty) return;

    setState(() => _isSending = true);
    await ref
        .read(postActionsProvider.notifier)
        .repostPost(widget.originalPost.id, commentary: quote);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final original = widget.originalPost;
    final authorLabel = (original.authorDisplayName ?? '').trim().isEmpty
        ? 'Anonymous'
        : original.authorDisplayName!.trim();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quote Repost',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _isSending ? null : _submit,
                      child: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Post'),
                    ),
                  ],
                ),
              ),

              // ── Quote text field ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Add your thoughts…',
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),

              // ── Original post preview ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  AppSpacing.sm,
                  16,
                  AppSpacing.lg,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.4),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        authorLabel,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (original.body != null &&
                          original.body!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          original.body!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
