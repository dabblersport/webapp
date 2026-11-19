// CEO 2026-11-19: Home's games in the design-system stack
// ([DabblerUpcomingReminder]: card, stack, list, strip), with no block title.
// The viewer's next games ([userUpcomingGamesProvider]) are merged with their
// ongoing activities (KAN-1008, [ongoingControllerProvider]) by event id, so a
// game that starts keeps its item and switches to the running state. Closed
// and cancelled activities leave. Running first, then the nearest upcoming.

import 'dart:async';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/constants/timing/notification_timing.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/features/games/providers/games_providers.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:dabbler/features/home/presentation/widgets/home_game_card.dart';
import 'package:dabbler/features/ongoing/domain/ongoing_models.dart';
import 'package:dabbler/features/ongoing/presentation/ongoing_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeUpcoming extends ConsumerStatefulWidget {
  const HomeUpcoming({super.key});

  @override
  ConsumerState<HomeUpcoming> createState() => _HomeUpcomingState();
}

class _HomeUpcomingState extends ConsumerState<HomeUpcoming> {
  /// Redraws a minute countdown at the next minute. One-shot, display only;
  /// the server is read by the ongoing controller's boundary timer.
  Timer? _tick;
  bool _collapsed = false;
  bool _expanded = false;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _armTick(List<HomeGameEntry> shown, DateTime now) {
    _tick?.cancel();
    _tick = null;
    const tick = NotificationTiming.ongoingCountdownTick;
    Duration? soonest;
    for (final g in shown) {
      final left = g.start.difference(now);
      if (left.isNegative || left.inHours > 0) continue;
      if (soonest == null || left < soonest) soonest = left;
    }
    final left = soonest;
    if (left == null) return;
    final toMinute = left - tick * left.inMinutes;
    _tick = Timer(toMinute <= Duration.zero ? tick : toMinute, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final games =
        ref.watch(userUpcomingGamesProvider).valueOrNull ?? const <Game>[];
    final live = FeatureFlags.ongoingCard
        ? ref.watch(ongoingControllerProvider).events
        : const <OngoingEvent>[];
    final now = ref.watch(homeNowProvider)();
    final byId = <String, Game>{for (final g in games) g.id: g};
    final entries = <HomeGameEntry>[
      for (final e in live)
        if (!e.isClosed)
          HomeGameEntry(
            id: e.eventId,
            title: e.title.isEmpty ? (byId[e.eventId]?.title ?? '') : e.title,
            start: e.startAt,
            venue: byId[e.eventId]?.venueName,
            // rpc_my_ongoing_events carries no sport: the games list does.
            sport: byId[e.eventId]?.sport,
            live: e,
            isMeetup: e.kind == OngoingKind.meetup,
          ),
    ];
    // A started game has left the games list: read its sport from the game.
    for (var i = 0; i < entries.length; i++) {
      final g = entries[i];
      if (g.isMeetup || (g.sport?.isNotEmpty ?? false)) continue;
      final s = ref.watch(homeEventSportProvider(g.id)).valueOrNull;
      if (s != null) entries[i] = g.withSport(s);
    }
    final liveIds = <String>{for (final e in live) e.eventId};
    for (final g in games) {
      if (liveIds.contains(g.id)) continue;
      entries.add(
        HomeGameEntry(
          id: g.id,
          title: g.title,
          start: g.getScheduledStartDateTime(),
          venue: g.venueName,
          end: _scheduledEnd(g),
          sport: g.sport,
        ),
      );
    }
    if (entries.isEmpty) {
      _tick?.cancel();
      return const SizedBox.shrink();
    }
    final ordered = orderHomeGames(entries, now);
    _armTick(ordered, now);
    final l = AppLocalizations.of(context);
    final count = ordered.length;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: DabblerSpacing.space6,
        end: DabblerSpacing.space6,
        bottom: _collapsed ? DabblerSpacing.space3 : DabblerSpacing.space4,
      ),
      // Cards press (scale 0.98, design system) — the tap micro-interaction.
      child: DabblerPressScale.gesture(
        child: DabblerUpcomingReminder(
          key: const ValueKey<String>('home-games'),
          metrics: DabblerFeedMetrics.drawn,
          items: <DabblerUpcomingItem>[
            for (final g in ordered) homeUpcomingItem(context, g, now),
          ],
          // CEO: no "Upcoming" title on Home.
          title: '',
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
      ),
    );
  }
}

/// The game's scheduled end, or null when its end time is missing or not
/// after the start.
DateTime? _scheduledEnd(Game g) {
  try {
    final end = g.getScheduledEndDateTime();
    return end.isAfter(g.getScheduledStartDateTime()) ? end : null;
  } catch (_) {
    return null;
  }
}
