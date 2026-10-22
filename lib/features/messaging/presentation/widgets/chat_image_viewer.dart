import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/messaging/presentation/widgets/chat_image_widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The viewer's share of the screen height.
const double _heightFraction = 0.5;

/// Opens an image full screen (frame 33) from a tap on a settled image. The
/// whole photo shows (contain), over the design system's dark ink, with a close
/// target. The overflow menu (save, forward, report) is an unresolved product
/// decision (Q7) and is not drawn.
Future<void> showChatImageViewer(
  BuildContext context, {
  required String url,
  required Map<String, String>? headers,
  String? caption,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppSheet<void>(
    context: context,
    detent: DabblerSheetDetent.content,
    title: l10n.messaging_image_viewer_title,
    builder: (sheet) => SizedBox(
      key: ChatImageKeys.viewer,
      height: MediaQuery.sizeOf(sheet).height * _heightFraction,
      child: Column(
        children: [
          Expanded(
            child: DabblerImage(
              url: url,
              headers: headers,
              fit: BoxFit.contain,
              radius: DabblerRadius.lgAll,
              semanticLabel: l10n.messaging_image_open,
              placeholderGlyph: true,
            ),
          ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: DabblerSpacing.space2),
            DabblerText(caption, style: DabblerType.body),
          ],
          const SizedBox(height: DabblerSpacing.space2),
          DabblerButton(
            key: ChatImageKeys.viewerClose,
            label: l10n.messaging_image_close,
            tone: DabblerButtonTone.neutral,
            fullWidth: true,
            onPressed: () => Navigator.of(sheet).pop(),
          ),
        ],
      ),
    ),
  );
}
