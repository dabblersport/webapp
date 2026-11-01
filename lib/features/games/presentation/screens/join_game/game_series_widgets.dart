// KAN-698: the series badge of the game detail and the sheets that edit or
// cancel a recurring series (KAN-694 RPCs). Host-only entry points are decided
// by the screen; the server enforces the same rule.
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/games/data/repositories/game_series_repository.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the host chose in the edit scope sheet.
enum SeriesEditScope { thisOnly, allFuture }

/// The "Series" row of the game detail; absent for a one-off game (TC1).
Widget? gameSeriesBadge(BuildContext context, GameView game) {
  if (!game.isSeries) return null;
  final l = AppLocalizations.of(context);
  final frequency = game.seriesFrequency == 'biweekly'
      ? l.recurring_badge_biweekly
      : l.recurring_badge_weekly;
  final ends = game.seriesEndsOn;
  return Semantics(
    label: l.recurring_badge_semantics,
    child: DabblerListGroup(
      children: [
        DabblerListRow(
          key: const ValueKey<String>('game-series-badge'),
          leading: const DabblerIcon('calendar'),
          overline: l.recurring_badge_label,
          title: frequency,
          subtitle: ends == null
              ? l.recurring_badge_open_ended
              : l.recurring_badge_ends(ends),
        ),
      ],
    ),
  );
}

/// Asks whether an edit applies to this game or to all future games.
Future<SeriesEditScope?> showSeriesEditScopeSheet(
  BuildContext context, {
  required DateTime gameStart,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<SeriesEditScope>(
    context: context,
    title: l.recurring_edit_title,
    closeLabel: l.recurring_edit_close,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(DabblerSpacing.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DabblerText(
            l.recurring_edit_subtitle,
            style: DabblerType.subheadline,
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          DabblerListGroup(
            children: [
              DabblerListRow(
                key: const ValueKey<String>('series-scope-this'),
                title: l.recurring_edit_this_only,
                subtitle: l.recurring_edit_this_only_desc(gameStart),
                onTap: () => Navigator.pop(ctx, SeriesEditScope.thisOnly),
              ),
              DabblerListRow(
                key: const ValueKey<String>('series-scope-future'),
                title: l.recurring_edit_all_future,
                subtitle: l.recurring_edit_all_future_desc,
                onTap: () => Navigator.pop(ctx, SeriesEditScope.allFuture),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Edits title and capacity of every future game of the series. Returns true
/// when the series changed.
Future<bool?> showSeriesFutureEditSheet(
  BuildContext context, {
  required GameView game,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<bool>(
    context: context,
    title: l.recurring_edit_all_future,
    closeLabel: l.recurring_edit_close,
    builder: (_) => _FutureEditBody(game: game),
  );
}

class _FutureEditBody extends ConsumerStatefulWidget {
  const _FutureEditBody({required this.game});
  final GameView game;

  @override
  ConsumerState<_FutureEditBody> createState() => _FutureEditBodyState();
}

class _FutureEditBodyState extends ConsumerState<_FutureEditBody> {
  late final TextEditingController _title = TextEditingController(
    text: widget.game.title,
  );
  late final TextEditingController _capacity = TextEditingController(
    text: widget.game.capacity.toString(),
  );
  bool _saving = false;
  String? _error;
  int _kept = 0;

  @override
  void dispose() {
    _title.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final seriesId = widget.game.seriesId;
    if (seriesId == null) return;
    final title = _title.text.trim();
    final capacity = int.tryParse(_capacity.text.trim());
    setState(() {
      _saving = true;
      _error = null;
    });
    final res = await ref
        .read(gameSeriesRepositoryProvider)
        .editFuture(
          seriesId: seriesId,
          title: title.isEmpty || title == widget.game.title ? null : title,
          capacity: capacity == widget.game.capacity ? null : capacity,
        );
    if (!mounted) return;
    res.fold(
      (Failure _) => setState(() {
        _saving = false;
        _error = l.recurring_future_failed;
      }),
      (outcome) {
        if (outcome.keptWithPlayers > 0) {
          // Show the notice, then let the host close the sheet.
          setState(() {
            _saving = false;
            _kept = outcome.keptWithPlayers;
          });
        } else {
          Navigator.pop(context, true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(DabblerSpacing.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DabblerText(
            l.recurring_edit_all_future_desc,
            style: DabblerType.subheadline,
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          DabblerTextField(
            key: const ValueKey<String>('series-future-title'),
            controller: _title,
            placeholder: l.recurring_future_title_label,
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          DabblerTextField(
            key: const ValueKey<String>('series-future-capacity'),
            controller: _capacity,
            placeholder: l.recurring_future_capacity_label,
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const DabblerGap.v(DabblerSpacing.space3),
            DabblerText(_error!, style: DabblerType.subheadline),
          ],
          if (_kept > 0) ...[
            const DabblerGap.v(DabblerSpacing.space3),
            DabblerText(
              l.recurring_kept_with_players_notice(_kept),
              key: const ValueKey<String>('series-kept-notice'),
              style: DabblerType.subheadline,
            ),
          ],
          const DabblerGap.v(DabblerSpacing.space4),
          if (_kept > 0)
            DabblerButton(
              label: l.recurring_edit_close,
              size: DabblerButtonSize.full,
              fullWidth: true,
              onPressed: () => Navigator.pop(context, true),
            )
          else
            DabblerButton(
              key: const ValueKey<String>('series-future-save'),
              label: l.recurring_future_save,
              size: DabblerButtonSize.full,
              fullWidth: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
        ],
      ),
    );
  }
}

/// Confirms and runs the series cancellation. Returns true when cancelled.
Future<bool?> showSeriesCancelSheet(
  BuildContext context, {
  required String seriesId,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<bool>(
    context: context,
    title: l.recurring_cancel_title,
    closeLabel: l.recurring_edit_close,
    builder: (_) => _CancelBody(seriesId: seriesId),
  );
}

class _CancelBody extends ConsumerStatefulWidget {
  const _CancelBody({required this.seriesId});
  final String seriesId;

  @override
  ConsumerState<_CancelBody> createState() => _CancelBodyState();
}

class _CancelBodyState extends ConsumerState<_CancelBody> {
  bool _busy = false;
  String? _error;

  Future<void> _cancel() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref
        .read(gameSeriesRepositoryProvider)
        .cancelSeries(seriesId: widget.seriesId);
    if (!mounted) return;
    res.fold(
      (Failure _) => setState(() {
        _busy = false;
        _error = l.recurring_cancel_failed;
      }),
      (_) => Navigator.pop(context, true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(DabblerSpacing.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DabblerText(
            l.recurring_cancel_past_line,
            style: DabblerType.subheadline,
          ),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerText(
            l.recurring_cancel_no_carry_over,
            style: DabblerType.subheadline,
          ),
          if (_error != null) ...[
            const DabblerGap.v(DabblerSpacing.space3),
            DabblerText(_error!, style: DabblerType.subheadline),
          ],
          const DabblerGap.v(DabblerSpacing.space4),
          DabblerButton(
            key: const ValueKey<String>('series-cancel-confirm'),
            label: l.recurring_cancel_confirm,
            tone: DabblerButtonTone.destructive,
            size: DabblerButtonSize.full,
            fullWidth: true,
            loading: _busy,
            onPressed: _busy ? null : _cancel,
          ),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerButton(
            label: l.recurring_cancel_keep,
            tone: DabblerButtonTone.outlined,
            size: DabblerButtonSize.full,
            fullWidth: true,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}
