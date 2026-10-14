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
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showDabblerSheet<_Choice>(
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
      await showDabblerSheet<void>(
        context: context,
        detent: DabblerSheetDetent.content,
        title: l10n.messaging_report_title,
        builder: (_) => GameChatReportSheet(onSubmit: onReport),
      );
    case _Choice.block:
      await showDabblerSheet<void>(
        context: context,
        detent: DabblerSheetDetent.content,
        title: l10n.messaging_block_title,
        builder: (_) => GameChatBlockSheet(targetUserId: senderUserId),
      );
  }
}

enum _Phase { choosing, submitting, submitted, failed }

/// Chooses one of the ten report reasons and submits it. Shows submitted and
/// failed states; a failure keeps the choice so it can be retried.
class GameChatReportSheet extends StatefulWidget {
  const GameChatReportSheet({super.key, required this.onSubmit});

  final Future<bool> Function(ReportCategory reason) onSubmit;

  @override
  State<GameChatReportSheet> createState() => _GameChatReportSheetState();
}

class _GameChatReportSheetState extends State<GameChatReportSheet> {
  ReportCategory? _reason;
  _Phase _phase = _Phase.choosing;

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _phase = _Phase.submitting);
    final ok = await widget.onSubmit(reason);
    if (!mounted) return;
    setState(() => _phase = ok ? _Phase.submitted : _Phase.failed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_phase == _Phase.submitted) {
      return SingleChildScrollView(
        child: DabblerSheetBody(
          key: GameChatSafetyKeys.reportSheet,
          actions: DabblerSheetActions(
            children: [
              DabblerButton(
                label: l10n.messaging_report_done,
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          children: [
            DabblerInlineMessage(
              l10n.messaging_report_submitted,
              key: GameChatSafetyKeys.reportSubmitted,
              tone: DabblerInlineMessageTone.success,
            ),
          ],
        ),
      );
    }
    final busy = _phase == _Phase.submitting;
    final failed = _phase == _Phase.failed;
    return SingleChildScrollView(
      child: DabblerSheetBody(
        key: GameChatSafetyKeys.reportSheet,
        actions: DabblerSheetActions(
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
              disabled: _reason == null || busy,
              onPressed: _submit,
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
        ),
        children: [
          DabblerText(l10n.messaging_report_prompt),
          for (final c in ReportCategory.values)
            DabblerRadio(
              key: GameChatSafetyKeys.reason(c),
              selected: _reason == c,
              disabled: busy,
              label: reportCategoryLabel(l10n, c),
              onChanged: (_) => setState(() => _reason = c),
            ),
          if (failed)
            DabblerInlineMessage(
              l10n.messaging_report_failed,
              key: GameChatSafetyKeys.reportFailed,
            ),
        ],
      ),
    );
  }
}

/// Confirms a block and calls the existing [blockRepositoryProvider].
class GameChatBlockSheet extends ConsumerStatefulWidget {
  const GameChatBlockSheet({super.key, required this.targetUserId});

  final String targetUserId;

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
    if (ok) ref.invalidate(blockedUserIdsProvider);
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
