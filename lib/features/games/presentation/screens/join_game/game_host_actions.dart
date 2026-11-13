import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/repositories/game_host_repository.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// KAN-939: the share link of [game]. A link-policy game's link carries a
/// join token (`lt`): the token the viewer arrived with, or — for the host —
/// a fresh one from `rpc_mint_join_link`. Any other policy shares the plain
/// link. A failed mint is an error, never a link nobody can join from.
Future<Result<String, Failure>> buildGameShareLink({
  required GameView game,
  required bool isHost,
  required GameHostRepository repo,
  String? arrivedToken,
  String? sharerProfileId,
}) async {
  String link(String? token) => RoutePaths.gameLink(
    game.id,
    sharerProfileId: sharerProfileId,
    linkToken: token,
  );
  if (game.joinPolicy != 'link') return Ok(link(null));
  if (isHost) {
    final minted = await repo.mintJoinLink(game.id);
    return minted.map(link);
  }
  return Ok(link(arrivedToken));
}

/// KAN-937: the host's confirm dialog for cancelling one game. Returns the
/// reason the host typed (empty when none), or null when the host keeps it.
Future<String?> showCancelGameDialog(BuildContext context) {
  return showDabblerDialog<String>(
    context: context,
    builder: (ctx) => const _CancelGameDialog(),
  );
}

class _CancelGameDialog extends StatefulWidget {
  const _CancelGameDialog();

  @override
  State<_CancelGameDialog> createState() => _CancelGameDialogState();
}

class _CancelGameDialogState extends State<_CancelGameDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DabblerDialog(
      title: l.game_cancel_title,
      description: l.game_cancel_body,
      destructive: true,
      onClose: () => Navigator.pop(context),
      secondaryAction: DabblerDialogAction(
        label: l.game_cancel_keep,
        onPressed: () => Navigator.pop(context),
      ),
      primaryAction: DabblerDialogAction(
        label: l.game_cancel_confirm,
        onPressed: () => Navigator.pop(context, _reason.text.trim()),
      ),
      child: DabblerTextField(
        key: const ValueKey<String>('game-cancel-reason'),
        controller: _reason,
        label: l.game_cancel_reason_label,
        placeholder: l.game_cancel_reason_placeholder,
      ),
    );
  }
}

/// KAN-937: confirm, cancel with the optional reason, then [onDone] (the
/// screen's reload) so the game shows as cancelled without a manual refresh.
Future<void> runCancelGame(
  BuildContext context, {
  required GameHostRepository repo,
  required String gameId,
  required Future<void> Function() onDone,
  required void Function(String message, bool isError) toast,
}) async {
  final l = AppLocalizations.of(context);
  final reason = await showCancelGameDialog(context);
  if (reason == null || !context.mounted) return;
  final res = await repo.cancelGame(gameId, reason: reason);
  if (!context.mounted) return;
  if (res.isSuccess) {
    toast(l.game_cancelled_toast, false);
    await onDone();
  } else {
    toast(l.game_cancel_failed, true);
  }
}

/// KAN-937: the host's "Cancel game" button on game detail — one game (a
/// one-off, or one occurrence of a series). Null unless the viewer hosts a
/// game that is neither cancelled nor over.
Widget? gameCancelEntry(
  BuildContext context, {
  required GameView game,
  required bool isHost,
  required GameHostRepository repo,
  required Future<void> Function() onDone,
  required void Function(String message, bool isError) toast,
}) {
  if (!isHost || game.isCancelled || game.endAt.isBefore(DateTime.now())) {
    return null;
  }
  return DabblerButton(
    key: const ValueKey<String>('game-cancel'),
    label: AppLocalizations.of(context).game_cancel_action,
    tone: DabblerButtonTone.destructive,
    size: DabblerButtonSize.full,
    fullWidth: true,
    onPressed: () => runCancelGame(
      context,
      repo: repo,
      gameId: game.id,
      onDone: onDone,
      toast: toast,
    ),
  );
}
