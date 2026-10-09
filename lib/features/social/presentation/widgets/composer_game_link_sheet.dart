import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Opens "Link a game" (`Home Feed.dc.html:876-925`): a search field, the
/// viewer's joined games until something is typed, then the matching games as [DabblerGameLinkRow]s, a Clear action and a `Confirm`
/// footer that links the pending game.
Future<void> showComposerGameLinkSheet(BuildContext context, WidgetRef ref) {
  final state = ref.read(postComposerProvider);
  final notifier = ref.read(postComposerProvider.notifier);
  final pending = ValueNotifier<({String id, String name})?>(
    state.gameId == null
        ? null
        : (id: state.gameId!, name: state.gameName ?? ''),
  );
  final l = AppLocalizations.of(context);
  return showComposerSheet<void>(
    context,
    title: l.composer_link_a_game,
    subtitle: l.composer_games_joined_hint,
    onClear: notifier.clearGame,
    confirm: ComposerSheetConfirm(
      label: l.composer_confirm,
      onTap: () {
        final pick = pending.value;
        if (pick != null) notifier.setGame(id: pick.id, name: pick.name);
        Navigator.of(context).maybePop();
      },
    ),
    builder: (_) => ComposerGameLinkSheet(pending: pending),
  );
}

/// The search field and game rows of [showComposerGameLinkSheet].
class ComposerGameLinkSheet extends ConsumerStatefulWidget {
  const ComposerGameLinkSheet({super.key, required this.pending});

  final ValueNotifier<({String id, String name})?> pending;

  @override
  ConsumerState<ComposerGameLinkSheet> createState() =>
      _ComposerGameLinkSheetState();
}

class _ComposerGameLinkSheetState extends ConsumerState<ComposerGameLinkSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final typed = _query.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComposerSearchField(
          controller: _search,
          placeholder: l.composer_games_search,
          onChanged: (v) => setState(() => _query = v),
        ),
        // Joined games before anything is typed (no minimum length); search
        // results from two characters on, as before.
        if (typed.isEmpty || typed.length >= 2)
          ValueListenableBuilder<({String id, String name})?>(
            valueListenable: widget.pending,
            builder: (context, current, _) => Consumer(
              builder: (context, ref, _) => ref
                  .watch(
                    typed.isEmpty
                        ? composerJoinedGamesProvider
                        : gameSearchProvider(typed),
                  )
                  .when(
                    loading: () => const ComposerCenteredState.loading(),
                    error: (_, __) =>
                        ComposerCenteredState.message(l.composer_search_failed),
                    data: (games) {
                      if (games.isEmpty) {
                        return ComposerCenteredState.message(
                          l.composer_no_games,
                        );
                      }
                      return Column(
                        children: [
                          for (final game in games)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                bottom: DabblerSpacing.space3,
                              ),
                              child: _row(game, current, l, locale),
                            ),
                        ],
                      );
                    },
                  ),
            ),
          ),
      ],
    );
  }

  Widget _row(
    Map<String, dynamic> game,
    ({String id, String name})? current,
    AppLocalizations l,
    String locale,
  ) {
    final id = game['id'] as String;
    final title = game['title'] as String? ?? l.composer_untitled_game;
    final start = DateTime.tryParse(game['start_at'] as String? ?? '');
    final sport = (game['sport'] as String? ?? '').replaceAll('_', '-');
    return DabblerGameLinkRow(
      month: start == null ? '' : DateFormat.MMM(locale).format(start),
      day: start == null ? '' : '${start.day}',
      title: title,
      sportKey: sport.isEmpty ? null : sport,
      place: [
        if (sport.isNotEmpty) game['sport'] as String,
        if ((game['game_type'] as String? ?? '').isNotEmpty)
          game['game_type'] as String,
      ].join(' · '),
      time: start == null ? null : DateFormat.jm(locale).format(start),
      selected: current?.id == id,
      onTap: () => widget.pending.value = (id: id, name: title),
    );
  }
}
