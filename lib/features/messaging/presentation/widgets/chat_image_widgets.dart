import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/messaging/domain/picked_image.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Keys of the image parts of a chat, for tests.
abstract final class ChatImageKeys {
  static const pendingTile = ValueKey<String>('messaging-image-pending');
  static const cancel = ValueKey<String>('messaging-image-cancel');
  static const retry = ValueKey<String>('messaging-image-retry');
  static const progress = ValueKey<String>('messaging-image-progress');
  static const tray = ValueKey<String>('messaging-image-tray');
  static const traySend = ValueKey<String>('messaging-image-tray-send');
  static const viewer = ValueKey<String>('messaging-image-viewer');
  static const viewerClose = ValueKey<String>('messaging-image-viewer-close');
  static const shareGallery = ValueKey<String>('messaging-share-gallery');
  static const shareCamera = ValueKey<String>('messaging-share-camera');
  static const shareFile = ValueKey<String>('messaging-share-file');
  static const shareGif = ValueKey<String>('messaging-share-gif');

  static ValueKey<String> remove(int index) =>
      ValueKey<String>('messaging-image-tray-remove-$index');
}

/// A settled image in the thread (KAN-581): the design system's image frame
/// at the message-image size, loaded through the Messaging API with the
/// caller's bearer. There is no public address: a signed-out or non-member
/// request is refused by the Worker and the frame shows its error state.
class ChatRemoteImage extends StatelessWidget {
  const ChatRemoteImage({
    super.key,
    required this.url,
    required this.headers,
    required this.semanticLabel,
    this.onOpen,
  });

  final String url;
  final Map<String, String>? headers;
  final String semanticLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => DabblerImage(
    url: url,
    headers: headers,
    width: DabblerMessage.imageSize.width,
    height: DabblerMessage.imageSize.height,
    radius: DabblerRadius.lgAll,
    semanticLabel: semanticLabel,
    onTap: onOpen,
    placeholderGlyph: true,
  );
}

/// The caller's own image while it uploads or after the upload failed
/// (frame 32): the picked bytes under the scrim, with a progress bar and a
/// cancel target, or a retry target and the failure line. The bytes are drawn
/// from memory because the image is not on the server yet.
///
/// Design deviation, recorded: the design draws a circular progress dial. The
/// design system has a linear progress bar and a spinner but no circular
/// determinate dial, so the bar stands in (filed as a DS gap).
class ChatPendingImage extends StatelessWidget {
  const ChatPendingImage({
    super.key,
    required this.image,
    required this.progress,
    required this.failed,
    this.onCancel,
    this.onRetry,
  });

  final PickedImage image;

  /// 0 to 1.
  final double progress;
  final bool failed;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  /// Progress bar width: three steps of the 36px spacing token.
  static const double _barWidth = DabblerSpacing.space10 * 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DabblerColors.of(context);
    final size = DabblerMessage.imageSize;
    final shown = progress.clamp(0.0, 1.0);
    final percent = (shown * 100).round();
    return SizedBox(
      key: ChatImageKeys.pendingTile,
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: DabblerRadius.lgAll,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.surfaceSunken),
            Image.memory(
              image.bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (c, e, s) => const SizedBox.shrink(),
            ),
            ColoredBox(color: colors.scrim),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  failed
                      ? DabblerButton.icon(
                          key: ChatImageKeys.retry,
                          icon: 'refresh-circle',
                          semanticLabel: l10n.messaging_image_retry,
                          tone: DabblerButtonTone.filled,
                          onPressed: onRetry,
                        )
                      : DabblerButton.icon(
                          key: ChatImageKeys.cancel,
                          icon: 'close-circle',
                          semanticLabel: l10n.messaging_image_cancel,
                          tone: DabblerButtonTone.filled,
                          onPressed: onCancel,
                        ),
                  const SizedBox(height: DabblerSpacing.space2),
                  DabblerText(
                    failed
                        ? l10n.messaging_image_failed
                        : l10n.messaging_image_uploading(percent),
                    style: DabblerType.caption1,
                    tone: DabblerTextTone.onBrand,
                  ),
                  if (!failed) ...[
                    const SizedBox(height: DabblerSpacing.space2),
                    SizedBox(
                      width: _barWidth,
                      child: DabblerProgressBar(
                        key: ChatImageKeys.progress,
                        value: shown,
                        size: DabblerProgressBarSize.sm,
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
