import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/messaging/domain/picked_image.dart';
import 'package:dabbler/features/messaging/presentation/widgets/chat_image_widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The picked images waiting above the composer (frame 31): 72px thumbnails
/// in a horizontal scroll, each with a remove target, and one Send target.
///
/// Design deviation, recorded: the design enables the composer's own send
/// control when only photos are queued. The pinned `DabblerChatComposer`
/// enables Send only for a non-empty draft and has no attachment strip (filed
/// as a DS gap), so this tray carries its own Send target, which sends the
/// queued photos with the draft as the first one's caption.
class ChatAttachmentTray extends StatelessWidget {
  const ChatAttachmentTray({
    super.key,
    required this.images,
    required this.onRemove,
    required this.onSend,
    this.sending = false,
  });

  final List<PickedImage> images;
  final ValueChanged<int> onRemove;
  final VoidCallback onSend;
  final bool sending;

  /// Thumbnail side (frame 31): two steps of the 36px spacing token.
  static const double thumbSize = DabblerSpacing.space10 * 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    return Padding(
      key: ChatImageKeys.tray,
      padding: const EdgeInsets.only(bottom: DabblerSpacing.space2),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: thumbSize,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (c, i) =>
                    const SizedBox(width: DabblerSpacing.space2),
                itemBuilder: (c, i) => SizedBox(
                  width: thumbSize,
                  height: thumbSize,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: DabblerRadius.mdAll,
                        child: Image.memory(
                          images[i].bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                          errorBuilder: (c, e, s) =>
                              ColoredBox(color: colors.surfaceSunken),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.topEnd,
                        child: DabblerButton.icon(
                          key: ChatImageKeys.remove(i),
                          icon: 'close-circle',
                          semanticLabel: l10n.messaging_image_remove,
                          tone: DabblerButtonTone.filled,
                          size: DabblerButtonSize.small,
                          onPressed: sending ? null : () => onRemove(i),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: DabblerSpacing.space2),
          DabblerButton.icon(
            key: ChatImageKeys.traySend,
            icon: 'send-2',
            semanticLabel: l10n.messaging_chat_send,
            tone: DabblerButtonTone.primary,
            disabled: sending || images.isEmpty,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
