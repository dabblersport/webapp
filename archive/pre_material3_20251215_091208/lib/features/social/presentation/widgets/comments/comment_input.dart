import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'dart:async';

class CommentInput extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final Function(String)? onSubmit;
  final Function(String)? onChanged;
  final bool isSubmitting;

  const CommentInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = 'Add a comment...',
    this.onSubmit,
    this.onChanged,
    this.isSubmitting = false,
  });

  @override
  ConsumerState<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<CommentInput> {
  bool _hasText = false;
  int _blocklistHits = 0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }

    // Debounce blocklist check
    _debounceTimer?.cancel();
    if (hasText) {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _checkBlocklist(widget.controller.text);
      });
    } else {
      setState(() => _blocklistHits = 0);
    }
  }

  Future<void> _checkBlocklist(String text) async {
    try {
      final moderationService = ref.read(moderationServiceProvider);
      final hits = await moderationService.contentHitsBlocklist(text);
      if (mounted) {
        setState(() => _blocklistHits = hits);
      }
    } catch (e) {
      // Silently fail - don't block user input
    }
  }

  void _submitComment() {
    final content = widget.controller.text.trim();
    if (content.isNotEmpty && widget.onSubmit != null) {
      widget.onSubmit!(content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_blocklistHits > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: theme.colorScheme.errorContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      size: 16,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your comment contains inappropriate content ($_blocklistHits violation${_blocklistHits > 1 ? 's' : ''}). Please revise.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Text input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        onChanged: widget.onChanged,
                        onSubmitted: (_) => _submitComment(),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: _hasText
                              ? IconButton(
                                  onPressed: _submitComment,
                                  icon: widget.isSubmitting
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  theme.colorScheme.primary,
                                                ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.send,
                                          color: theme.colorScheme.primary,
                                        ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // Emoji button
                  if (!_hasText) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
