import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:dabbler/features/messaging/presentation/widgets/messages_list_dm_row.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The one-to-one parts of the shared chat screen (KAN-556): the header, the
/// overflow menu and the read-only line. Built from DS parts only
/// ([DabblerConversationHeader], [showDabblerSheet], [DabblerSheetBody],
/// [DabblerButton]).
abstract final class DmThreadKeys {
  static const header = ValueKey<String>('messaging-dm-header');
  static const options = ValueKey<String>('messaging-dm-options');
  static const mute = ValueKey<String>('messaging-dm-mute');
  static const block = ValueKey<String>('messaging-dm-block');
  static const report = ValueKey<String>('messaging-dm-report');
  static const readOnly = ValueKey<String>('messaging-dm-read-only');
  static const muteFailed = ValueKey<String>('messaging-dm-mute-failed');
}

/// The counterpart's display name, or the existing fallback.
String dmCounterpartName(AppLocalizations l10n, DmThreadInfo dm) {
  final name = dm.counterpartName?.trim();
  return (name == null || name.isEmpty)
      ? l10n.messaging_dm_fallback_name
      : name;
}

/// The DM header: back, the counterpart's avatar and name (tapping opens
/// their profile when [onOpenProfile] is set) and the overflow menu. No
/// presence or typing subtitle.
Widget dmThreadHeader({
  required AppLocalizations l10n,
  required DmThreadInfo dm,
  required VoidCallback? onBack,
  required VoidCallback? onOverflow,
  VoidCallback? onOpenProfile,
}) {
  final seed = dm.counterpartUserId == null
      ? null
      : messagesListDmAvatar(dm.counterpartAvatar, dm.counterpartUserId!).seed;
  // The DS header's identity column is a fixed 45 high and overflows by
  // 1 px with the Arabic face at 200% text: its text scale is capped at
  // [dmHeaderMaxTextScale] (reported as a DS gap, KAN-556).
  return SafeArea(
    bottom: false,
    child: MediaQuery.withClampedTextScaling(
      maxScaleFactor: dmHeaderMaxTextScale,
      child: Semantics(
        hint: onOpenProfile == null ? null : l10n.messaging_dm_header_hint,
        child: DabblerConversationHeader(
          key: DmThreadKeys.header,
          kind: DabblerConversationKind.player,
          title: dmCounterpartName(l10n, dm),
          seed: seed,
          backLabel: l10n.auth_back,
          overflowLabel: l10n.messaging_dm_options_title,
          onBack: onBack,
          onTitlePress: onOpenProfile,
          onOverflow: onOverflow,
        ),
      ),
    ),
  );
}

/// The header's text-scale cap (see [dmThreadHeader]).
const double dmHeaderMaxTextScale = 1.8;

/// What the DM overflow menu chose.
enum DmThreadAction { toggleMute, block, report }

/// Opens the DM overflow menu: Mute/Unmute, Block user, Report user. Block
/// is hidden once the DM is read-only; Report is disabled while there is no
/// message of theirs to report.
Future<DmThreadAction?> showDmThreadOptions(
  BuildContext context, {
  required bool muted,
  required bool canBlock,
  required bool canReport,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppSheet<DmThreadAction>(
    context: context,
    detent: DabblerSheetDetent.content,
    title: l10n.messaging_dm_options_title,
    builder: (sheet) => SingleChildScrollView(
      child: DabblerSheetBody(
        key: DmThreadKeys.options,
        actions: DabblerSheetActions(
          children: [
            DabblerButton(
              key: DmThreadKeys.mute,
              label: muted
                  ? l10n.messaging_dm_menu_unmute
                  : l10n.messaging_dm_menu_mute,
              icon: muted ? 'volume-high' : 'volume-slash',
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              onPressed: () =>
                  Navigator.of(sheet).pop(DmThreadAction.toggleMute),
            ),
            if (canBlock)
              DabblerButton(
                key: DmThreadKeys.block,
                label: l10n.messaging_dm_menu_block,
                icon: 'slash',
                tone: DabblerButtonTone.neutral,
                fullWidth: true,
                onPressed: () => Navigator.of(sheet).pop(DmThreadAction.block),
              ),
            DabblerButton(
              key: DmThreadKeys.report,
              label: l10n.messaging_dm_menu_report,
              icon: 'flag',
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              disabled: !canReport,
              onPressed: () => Navigator.of(sheet).pop(DmThreadAction.report),
            ),
          ],
        ),
        children: const [],
      ),
    ),
  );
}

/// The quiet line that replaces the composer of a read-only DM.
String dmReadOnlyText(AppLocalizations l10n, DmReadOnlyKind kind) =>
    switch (kind) {
      DmReadOnlyKind.youBlocked => l10n.messaging_dm_read_only_you_blocked,
      DmReadOnlyKind.blockedYou => l10n.messaging_dm_read_only_blocked_you,
      DmReadOnlyKind.counterpartGone => l10n.messaging_dm_read_only_gone,
    };

/// The composer notice of a read-only DM.
Widget dmReadOnlyNotice(AppLocalizations l10n, DmReadOnlyKind kind) =>
    DabblerChatComposer(
      key: DmThreadKeys.readOnly,
      value: '',
      notice: DabblerComposerNotice(
        icon: 'lock',
        text: dmReadOnlyText(l10n, kind),
      ),
    );
