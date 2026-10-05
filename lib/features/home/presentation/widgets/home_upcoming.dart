import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The Upcoming block above the feed tabs: the viewer's next games from
/// [userUpcomingGamesProvider], as the design's reminder (card, stack, list or
/// strip). Folding and opening are view state kept here.
///
class HomeUpcoming extends ConsumerStatefulWidget {
  const HomeUpcoming({super.key});

  @override
  ConsumerState<HomeUpcoming> createState() => _HomeUpcomingState();
}

class _HomeUpcomingState extends ConsumerState<HomeUpcoming> {
  bool _collapsed = false;
  bool _expanded = false;

  /// The countdown window the ring fills over — three days (`gauge()`).
  static const int _windowSeconds = 3 * 24 * 60 * 60;

  DabblerUpcomingItem _item(Game game, String locale, AppLocalizations l) {
    final DateTime start = game.getScheduledStartDateTime();
    final Duration left = start.difference(DateTime.now());
    final Duration safe = left.isNegative ? Duration.zero : left;
    final int days = safe.inDays;
    final int hours = safe.inHours % 24;
    final int minutes = safe.inMinutes % 60;
    final (String big, String small) = days > 0
        ? ('$days', days == 1 ? l.home_upcoming_day : l.home_upcoming_days)
        : hours > 0
        ? ('$hours', hours == 1 ? l.home_upcoming_hour : l.home_upcoming_hours)
        : ('$minutes', l.home_upcoming_min);
    final String short = days > 0
        ? l.home_upcoming_in_days(days)
        : hours > 0
        ? l.home_upcoming_in_hours(hours, minutes)
        : l.home_upcoming_in_minutes(minutes);
    final String time = DateFormat('h:mm a', locale).format(start);
    final String? venue = game.venueName;
    return DabblerUpcomingItem(
      month: DateFormat('MMM', 'en').format(start).toUpperCase(),
      day: '${start.day}',
      title: game.title,
      detail: venue == null || venue.isEmpty ? time : '$venue · $time',
      ringFraction: 1 - (safe.inSeconds / _windowSeconds).clamp(0.0, 1.0),
      ringBig: big,
      ringSmall: small,
      short: short,
      onTap: () => context.push(RoutePaths.gameDetail(game.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Game> games =
        ref.watch(userUpcomingGamesProvider).valueOrNull ?? const <Game>[];
    if (games.isEmpty) return const SizedBox.shrink();
    final String locale = Localizations.localeOf(context).toString();
    final int count = games.length;
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      // The frame's block: `padding: 0 18px 12px`.
      padding: EdgeInsetsDirectional.only(
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
        // Folded, the strip has `margin:0 18px 9px` instead.
        bottom: _collapsed ? DabblerSpacing.space3 : DabblerSpacing.space4,
      ),
      child: DabblerUpcomingReminder(
        metrics: DabblerFeedMetrics.drawn,
        items: <DabblerUpcomingItem>[
          for (final g in games) _item(g, locale, l),
        ],
        title: count > 1
            ? l.home_upcoming_title_count(count)
            : l.home_upcoming_title,
        collapsed: _collapsed,
        expanded: _expanded,
        onDismiss: () => setState(() => _collapsed = true),
        onExpandStrip: () => setState(() => _collapsed = false),
        onToggleExpanded: () => setState(() => _expanded = !_expanded),
        stripLabel: count > 1
            ? l.home_upcoming_strip_count(count)
            : l.home_upcoming_title,
        moreLabel: l.home_upcoming_more(count - 1),
        showLessLabel: l.home_upcoming_show_less,
        dismissLabel: l.home_upcoming_hide,
        seeAllLabel: l.home_upcoming_see_all(count),
        onSeeAll: () => context.go(RoutePaths.gamesTab),
      ),
    );
  }
}
