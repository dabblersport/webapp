import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/social/block_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Report and block sheets of the game chat (KAN-517, T16b).
///
/// D13: the report promises no response time. D29: no price, settlement,
/// refund or retention copy; the block sheet does not claim the blocked
/// player can no longer "see the games you organise".
abstract final class GameChatSafetyKeys {
  static const options = ValueKey<String>('messaging-chat-message-options');
  static const reportAction = ValueKey<String>('messaging-chat-report-action');
  static const blockAction = ValueKey<String>('messaging-chat-block-action');
  static const reportSheet = ValueKey<String>('messaging-report-sheet');
  static const reportSubmit = ValueKey<String>('messaging-report-submit');
  static const reportSubmitted = ValueKey<String>('messaging-report-submitted');
  static const reportFailed = ValueKey<String>('messaging-report-failed');
  static const reportRetry = ValueKey<String>('messaging-report-retry');
  static const reportCancel = ValueKey<String>('messaging-report-cancel');
  static const reasonList = ValueKey<String>('messaging-report-reason-list');
  static const blockSheet = ValueKey<String>('messaging-block-sheet');
  static const blockConfirm = ValueKey<String>('messaging-block-confirm');
  static const blockDone = ValueKey<String>('messaging-block-done');
  static const blockFailed = ValueKey<String>('messaging-block-failed');

  static ValueKey<String> reason(ReportCategory c) =>
      ValueKey<String>('messaging-report-reason-${c.wireName}');
}

/// The localized label of a report reason.
String reportCategoryLabel(AppLocalizations l10n, ReportCategory c) =>
    switch (c) {
      ReportCategory.spam => l10n.messaging_report_reason_spam,
      ReportCategory.abuse => l10n.messaging_report_reason_abuse,
      ReportCategory.hate => l10n.messaging_report_reason_hate,
      ReportCategory.harassment => l10n.messaging_report_reason_harassment,
      ReportCategory.nudity => l10n.messaging_report_reason_nudity,
      ReportCategory.illegal => l10n.messaging_report_reason_illegal,
      ReportCategory.danger => l10n.messaging_report_reason_danger,
      ReportCategory.scam => l10n.messaging_report_reason_scam,
      ReportCategory.impersonation =>
        l10n.messaging_report_reason_impersonation,
      ReportCategory.other => l10n.messaging_report_reason_other,
    };

enum _Choice { report, block }

/// Opens the options of another member's message: Report and Block. There is
/// no Leave (D6).
Future<void> showGameChatMessageOptions(
  BuildContext context, {
  required Future<bool> Function(ReportCategory reason) onReport,
  required String senderUserId,
  VoidCallback? onBlocked,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showAppSheet<_Choice>(
    context: context,
    detent: DabblerSheetDetent.content,
    title: l10n.messaging_chat_message_options,
    builder: (sheet) => SingleChildScrollView(
      child: DabblerSheetBody(
        key: GameChatSafetyKeys.options,
        actions: DabblerSheetActions(
          children: [
            DabblerButton(
              key: GameChatSafetyKeys.reportAction,
              label: l10n.messaging_report_action,
              icon: 'flag',
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              onPressed: () => Navigator.of(sheet).pop(_Choice.report),
            ),
            DabblerButton(
              key: GameChatSafetyKeys.blockAction,
              label: l10n.messaging_block_action,
              icon: 'slash',
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              onPressed: () => Navigator.of(sheet).pop(_Choice.block),
            ),
          ],
        ),
        children: const [],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case _Choice.report:
      await showGameChatReportSheet(context, onSubmit: onReport);
    case _Choice.block:
      await showAppSheet<void>(
        context: context,
        detent: DabblerSheetDetent.content,
        title: l10n.messaging_block_title,
        builder: (_) => GameChatBlockSheet(
          targetUserId: senderUserId,
          onBlocked: onBlocked,
        ),
      );
  }
}

enum _Phase { choosing, submitting, submitted, failed }

/// Opens the report sheet (KAN-503 `01-report-reason-sheet`): the ten reasons
/// sit in a [DabblerSheetList] capped at half the viewport and scrolling
/// inside itself, while Send and Cancel live in the sheet's PINNED footer so
/// they stay on screen at any text scale.
Future<void> showGameChatReportSheet(
  BuildContext context, {
  required Future<bool> Function(ReportCategory reason) onSubmit,
}) async {
  final l10n = AppLocalizations.of(context);
  final controller = GameChatReportController(onSubmit: onSubmit);
  try {
    await showAppSheet<void>(
      context: context,
      detent: DabblerSheetDetent.content,
      title: l10n.messaging_report_title,
      builder: (_) => GameChatReportSheet(controller: controller),
      footerBuilder: (_) => GameChatReportActions(controller: controller),
    );
  } finally {
    controller.dispose();
  }
}

/// Shared state of the report sheet's body and its pinned footer.
class GameChatReportController extends ChangeNotifier {
  GameChatReportController({required this.onSubmit});

  final Future<bool> Function(ReportCategory reason) onSubmit;

  ReportCategory? _reason;
  _Phase _phase = _Phase.choosing;
  bool _disposed = false;

  ReportCategory? get reason => _reason;
  bool get busy => _phase == _Phase.submitting;
  bool get failed => _phase == _Phase.failed;
  bool get submitted => _phase == _Phase.submitted;

  void choose(ReportCategory c) {
    _reason = c;
    notifyListeners();
  }

  Future<void> submit() async {
    final reason = _reason;
    if (reason == null || busy) return;
    _set(_Phase.submitting);
    final ok = await onSubmit(reason);
    _set(ok ? _Phase.submitted : _Phase.failed);
  }

  void _set(_Phase p) {
    if (_disposed) return;
    _phase = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The report sheet's body: prompt, bounded reason list, failure message; or
/// the submitted confirmation.
class GameChatReportSheet extends StatelessWidget {
  const GameChatReportSheet({super.key, required this.controller});

  final GameChatReportController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.submitted) {
          return DabblerSheetBody(
            key: GameChatSafetyKeys.reportSheet,
            children: [
              DabblerInlineMessage(
                l10n.messaging_report_submitted,
                key: GameChatSafetyKeys.reportSubmitted,
                tone: DabblerInlineMessageTone.success,
              ),
            ],
          );
        }
        const reasons = ReportCategory.values;
        return DabblerSheetBody(
          key: GameChatSafetyKeys.reportSheet,
          children: [
            DabblerText(l10n.messaging_report_prompt),
            DabblerSheetList(
              key: GameChatSafetyKeys.reasonList,
              itemCount: reasons.length,
              itemBuilder: (_, i) => DabblerRadio(
                key: GameChatSafetyKeys.reason(reasons[i]),
                selected: controller.reason == reasons[i],
                disabled: controller.busy,
                label: reportCategoryLabel(l10n, reasons[i]),
                onChanged: (_) => controller.choose(reasons[i]),
              ),
            ),
            if (controller.failed)
              DabblerInlineMessage(
                l10n.messaging_report_failed,
                key: GameChatSafetyKeys.reportFailed,
              ),
          ],
        );
      },
    );
  }
}

/// The report sheet's pinned footer: Send (or Retry) and Cancel; Done once
/// submitted.
class GameChatReportActions extends StatelessWidget {
  const GameChatReportActions({super.key, required this.controller});

  final GameChatReportController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.submitted) {
          return DabblerButton(
            label: l10n.messaging_report_done,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          );
        }
        final busy = controller.busy;
        final failed = controller.failed;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DabblerSpacing.space3,
          children: [
            DabblerButton(
              key: failed
                  ? GameChatSafetyKeys.reportRetry
                  : GameChatSafetyKeys.reportSubmit,
              label: failed
                  ? l10n.messaging_report_retry
                  : l10n.messaging_report_submit,
              fullWidth: true,
              loading: busy,
              disabled: controller.reason == null || busy,
              onPressed: controller.submit,
            ),
            DabblerButton(
              key: GameChatSafetyKeys.reportCancel,
              label: l10n.messaging_report_cancel,
              tone: DabblerButtonTone.text,
              fullWidth: true,
              disabled: busy,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

/// Confirms a block and calls the existing [blockRepositoryProvider].
class GameChatBlockSheet extends ConsumerStatefulWidget {
  const GameChatBlockSheet({
    super.key,
    required this.targetUserId,
    this.onBlocked,
  });

  final String targetUserId;

  /// Called once the block succeeded (the DM thread turns read-only).
  final VoidCallback? onBlocked;

  @override
  ConsumerState<GameChatBlockSheet> createState() => _GameChatBlockSheetState();
}

class _GameChatBlockSheetState extends ConsumerState<GameChatBlockSheet> {
  _Phase _phase = _Phase.choosing;

  Future<void> _block() async {
    setState(() => _phase = _Phase.submitting);
    final result = await ref
        .read(blockRepositoryProvider)
        .blockUser(widget.targetUserId);
    if (!mounted) return;
    final ok = result.fold((_) => false, (_) => true);
    if (ok) {
      ref.invalidate(blockedUserIdsProvider);
      widget.onBlocked?.call();
    }
    setState(() => _phase = ok ? _Phase.submitted : _Phase.failed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _phase == _Phase.submitting;
    final done = _phase == _Phase.submitted;
    return SingleChildScrollView(
      child: DabblerSheetBody(
        key: GameChatSafetyKeys.blockSheet,
        actions: DabblerSheetActions(
          children: done
              ? [
                  DabblerButton(
                    label: l10n.messaging_report_done,
                    fullWidth: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]
              : [
                  DabblerButton(
                    key: GameChatSafetyKeys.blockConfirm,
                    label: l10n.messaging_block_confirm,
                    fullWidth: true,
                    loading: busy,
                    disabled: busy,
                    onPressed: _block,
                  ),
                  DabblerButton(
                    label: l10n.messaging_block_cancel,
                    tone: DabblerButtonTone.outlined,
                    fullWidth: true,
                    disabled: busy,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
        ),
        children: [
          if (done)
            DabblerInlineMessage(
              l10n.messaging_block_done,
              key: GameChatSafetyKeys.blockDone,
              tone: DabblerInlineMessageTone.success,
            )
          else
            DabblerText(l10n.messaging_block_body),
          if (_phase == _Phase.failed)
            DabblerInlineMessage(
              l10n.messaging_block_failed,
              key: GameChatSafetyKeys.blockFailed,
            ),
        ],
      ),
    );
  }
}
