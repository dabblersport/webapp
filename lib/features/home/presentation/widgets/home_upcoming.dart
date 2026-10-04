import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The design's copy for the block, in both languages. English and Arabic are
/// the design file's own strings (`Home Feed.dc.html:3503-3534`).
class _UpcomingLabels {
  const _UpcomingLabels(this.ar);
  final bool ar;

  String title(int n) => ar
      ? (n > 1 ? 'القادمة · $n' : 'القادمة')
      : (n > 1 ? 'Upcoming · $n' : 'Upcoming');
  String strip(int n) => ar
      ? (n > 1 ? '$n قادمة' : 'القادمة')
      : (n > 1 ? '$n upcoming' : 'Upcoming');
  String more(int n) => ar ? '$n أخرى هذا الأسبوع' : '$n more this week';
  String get showLess => ar ? 'عرض أقل' : 'Show less';
  String get hide => ar ? 'إخفاء' : 'Hide';
  String seeAll(int n) => ar ? 'عرض كل $n القادمة' : 'See all $n upcoming';
  String days(int n) =>
      ar ? (n == 1 ? 'يوم' : 'أيام') : (n == 1 ? 'day' : 'days');
  String hours(int n) =>
      ar ? (n == 1 ? 'ساعة' : 'ساعات') : (n == 1 ? 'hour' : 'hours');
  String get min => ar ? 'دقيقة' : 'min';
  String inDays(int d) => ar ? 'بعد $d ي' : 'in ${d}d';
  String inHours(int h, int m) => ar ? 'بعد $h س $m د' : 'in ${h}h ${m}m';
  String inMinutes(int m) => ar ? 'بعد $m د' : 'in ${m}m';
}

/// The Upcoming block above the feed tabs: the viewer's next games from
/// [userUpcomingGamesProvider], as the design's reminder (card, stack, list or
/// strip). Folding and opening are view state kept here.
///
/// The copy lives in [_UpcomingLabels] until `content-manager` moves it into the
/// localisation files: it has no key there yet, and `lib/l10n/**` is not edited
/// here.
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

  DabblerUpcomingItem _item(Game game, String locale, _UpcomingLabels l) {
    final DateTime start = game.getScheduledStartDateTime();
    final Duration left = start.difference(DateTime.now());
    final Duration safe = left.isNegative ? Duration.zero : left;
    final int days = safe.inDays;
    final int hours = safe.inHours % 24;
    final int minutes = safe.inMinutes % 60;
    final (String big, String small) = days > 0
        ? ('$days', l.days(days))
        : hours > 0
        ? ('$hours', l.hours(hours))
        : ('$minutes', l.min);
    final String short = days > 0
        ? l.inDays(days)
        : hours > 0
        ? l.inHours(hours, minutes)
        : l.inMinutes(minutes);
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
    final _UpcomingLabels l = _UpcomingLabels(
      Localizations.localeOf(context).languageCode == 'ar',
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
      ),
      child: DabblerUpcomingReminder(
        items: <DabblerUpcomingItem>[
          for (final g in games) _item(g, locale, l),
        ],
        title: l.title(count),
        collapsed: _collapsed,
        expanded: _expanded,
        onDismiss: () => setState(() => _collapsed = true),
        onExpandStrip: () => setState(() => _collapsed = false),
        onToggleExpanded: () => setState(() => _expanded = !_expanded),
        stripLabel: l.strip(count),
        moreLabel: l.more(count - 1),
        showLessLabel: l.showLess,
        dismissLabel: l.hide,
        seeAllLabel: l.seeAll(count),
        onSeeAll: () => context.go(RoutePaths.gamesTab),
      ),
    );
  }
}
