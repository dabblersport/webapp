import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Opens the quote-repost composer as a design-system sheet; resolves true
/// when the repost was sent.
Future<bool?> showQuoteRepostSheet(BuildContext context, Post originalPost) =>
    showDabblerSheet<bool>(
      context: context,
      title: AppLocalizations.of(context).post_card_menu_quote_repost,
      detent: DabblerSheetDetent.content,
      builder: (_) => QuoteRepostSheet(originalPost: originalPost),
    );

/// Sheet content for composing a quote repost.
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
    final original = widget.originalPost;
    final authorLabel = (original.authorDisplayName ?? '').trim().isEmpty
        ? 'Anonymous'
        : original.authorDisplayName!.trim();

    // Widgets only: the sheet owns the surface and the content padding.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerTextField(
          variant: DabblerTextFieldVariant.multiline,
          controller: _controller,
          placeholder: 'Add your thoughts…',
          rows: 3,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: DabblerSpacing.space4),
        DabblerSurface.card(
          padding: const EdgeInsets.all(DabblerSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DabblerText(
                authorLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DabblerType.subheadline,
                weight: DabblerTextWeight.semibold,
              ),
              if (original.body != null &&
                  original.body!.trim().isNotEmpty) ...[
                const SizedBox(height: DabblerSpacing.space1),
                DabblerText(
                  original.body!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DabblerSpacing.space6),
        DabblerButton(
          label: AppLocalizations.of(context).composer_post_cta,
          fullWidth: true,
          loading: _isSending,
          onPressed: _controller.text.trim().isEmpty || _isSending
              ? null
              : _submit,
        ),
      ],
    );
  }
}
