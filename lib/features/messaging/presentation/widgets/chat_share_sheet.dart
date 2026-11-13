import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/messaging/presentation/providers/chat_image_providers.dart';
import 'package:dabbler/features/messaging/presentation/widgets/chat_image_widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// What the Share drawer can hand back: an image source, or the GIF search.
enum ChatShareChoice { gallery, camera, file, gif }

/// The Share drawer of the chat composer (frame 31), images only: Photo
/// library, Camera, Image file ("Images only") and Search GIFs ("Powered by
/// GIPHY"). Game, venue and player sharing are other tickets and are not
/// drawn. The library and camera are the OS pickers (no in-app gallery).
Future<ChatShareChoice?> showChatShareSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  Widget row(
    Key key,
    String icon,
    String title,
    ChatShareChoice choice,
    BuildContext sheet, {
    String? subtitle,
  }) => DabblerListRow(
    key: key,
    title: title,
    subtitle: subtitle,
    leading: DabblerIcon(icon),
    onTap: () => Navigator.of(sheet).pop(choice),
  );
  return showAppSheet<ChatShareChoice>(
    context: context,
    detent: DabblerSheetDetent.content,
    title: l10n.messaging_share_title,
    builder: (sheet) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(
            ChatImageKeys.shareGallery,
            'gallery',
            l10n.messaging_share_gallery,
            ChatShareChoice.gallery,
            sheet,
          ),
          row(
            ChatImageKeys.shareCamera,
            'camera',
            l10n.messaging_share_camera,
            ChatShareChoice.camera,
            sheet,
          ),
          row(
            ChatImageKeys.shareFile,
            'document-upload',
            l10n.messaging_share_file,
            ChatShareChoice.file,
            sheet,
            subtitle: l10n.messaging_share_file_hint,
          ),
          row(
            ChatImageKeys.shareGif,
            'search-normal',
            l10n.messaging_share_gif,
            ChatShareChoice.gif,
            sheet,
            subtitle: l10n.messaging_share_gif_hint,
          ),
        ],
      ),
    ),
  );
}

/// The one line shown when a pick was refused or failed (frame-less: the
/// design draws no error for it, so the existing notice style is reused).
String chatPickProblemText(AppLocalizations l10n, ChatPickProblem problem) =>
    switch (problem) {
      ChatPickProblem.cameraDenied => l10n.messaging_image_camera_denied,
      ChatPickProblem.libraryDenied => l10n.messaging_image_library_denied,
      ChatPickProblem.unsupportedType => l10n.messaging_image_unsupported,
      ChatPickProblem.tooLarge => l10n.messaging_image_too_large,
      ChatPickProblem.failed => l10n.messaging_image_pick_failed,
    };
