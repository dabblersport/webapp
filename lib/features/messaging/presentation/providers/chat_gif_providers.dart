import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/social/presentation/widgets/gif_picker_sheet.dart';

/// Opens a GIF picker and hands back the chosen GIF's URL (KAN-582).
typedef ChatGifPicker =
    Future<void> Function(
      BuildContext context, {
      required ValueChanged<String> onSelected,
    });

/// The picker the chat composer opens: the app's one GIPHY integration, the
/// same sheet the post and comment composers use. Overridable by tests.
final chatGifPickerProvider = Provider<ChatGifPicker>(
  (ref) => showGifPickerSheet,
);
