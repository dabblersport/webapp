import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/sports/data/sport_follow_repository.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_city_bar.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_header.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_section_states.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_tab_content.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// KAN-622: the public page of one sport (not any user's Sport Profile): its
/// identity with Follow, tabs for Overview, Games, Meetups, Venues and Posts,
/// and a page-local City. Reached by sport id from a sport tile or a deep
/// route, behind `FeatureFlags.sportOverview`.
///
/// The identity block scrolls away into the top bar's pinned title and the
/// tabs stay pinned. An unknown sport id shows the page error state with
/// Retry, never a crash. Browsing a sport the viewer does not follow is
/// allowed.
class SportOverviewScreen extends ConsumerStatefulWidget {
  const SportOverviewScreen({super.key, required this.sportId});

  final String sportId;

  @override
  ConsumerState<SportOverviewScreen> createState() =>
      _SportOverviewScreenState();
}

class _SportOverviewScreenState extends ConsumerState<SportOverviewScreen> {
  final ScrollController _scroll = ScrollController();
  SportTab _tab = SportTab.overview;
  SportVenuesMode _venuesMode = SportVenuesMode.venues;

  /// The header and tab strip are a fixed height; the tab strip is pinned.
  static const double _tabsExtent = 60;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openTab(SportTab tab, {SportVenuesMode? venuesMode}) {
    setState(() {
      _tab = tab;
      if (venuesMode != null) _venuesMode = venuesMode;
    });
    // Land on the section, with the tabs still pinned.
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.jumpTo(0);
    }
  }

  void _noticeFollow(SportFollowState? previous, SportFollowState next) {
    if (!mounted) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final SportFollowController controller = ref.read(
      sportFollowControllerProvider.notifier,
    );
    final DabblerToastSpec? spec = switch (next.blocked) {
      SportFollowOutcome.blockedLast => DabblerToastSpec(
        message: l.sport_overview_unfollow_last,
        tone: DabblerToastTone.error,
      ),
      SportFollowOutcome.blockedPracticing => DabblerToastSpec(
        message: l.sport_overview_unfollow_practicing,
        tone: DabblerToastTone.error,
      ),
      SportFollowOutcome.blockedPrimary => DabblerToastSpec(
        message: l.sport_overview_unfollow_primary,
        tone: DabblerToastTone.error,
      ),
      _ when next.error != null => DabblerToastSpec(
        message: l.sport_overview_follow_failed,
        tone: DabblerToastTone.error,
        action: DabblerToastAction(
          label: l.sport_overview_retry,
          onPressed: () {
            final SportInfo? sport = ref
                .read(sportInfoProvider(widget.sportId))
                .valueOrNull;
            if (sport != null) controller.toggle(sport);
          },
        ),
      ),
      _ => null,
    };
    if (spec == null) return;
    DabblerToastProvider.of(context).show(spec);
    controller.clearNotice();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final AsyncValue<SportInfo> info = ref.watch(
      sportInfoProvider(widget.sportId),
    );
    ref.listen<SportFollowState>(sportFollowControllerProvider, _noticeFollow);

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: info.valueOrNull?.name(lang) ?? l.sport_overview_title,
        scrollController: _scroll,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            Navigator.of(context).maybePop();
          }
        },
      ),
      body: info.when(
        loading: () => const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: kSportGutter,
          child: SportSectionSkeleton(rows: 3),
        ),
        error: (Object e, _) => _PageError(
          notFound: e is Failure && e.isNotFound,
          onRetry: () => ref.invalidate(sportInfoProvider(widget.sportId)),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(SportInfo sport) {
    final AppLocalizations l = AppLocalizations.of(context);
    final SportPageCity? city = ref
        .watch(sportPageCityProvider(sport.id))
        .valueOrNull;
    // The city is still being worked out: the sections wait with a skeleton
    // rather than asking for every city and then again for one.
    final bool cityPending = city == null;
    final SportScope scope = (sportId: sport.id, cityCode: city?.code);
    final SportOverviewCounts? counts = cityPending
        ? null
        : ref.watch(sportOverviewCountsProvider(scope)).valueOrNull;

    return CustomScrollView(
      controller: _scroll,
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: SportHeader(sport: sport, counts: counts),
        ),
        const SliverToBoxAdapter(child: DabblerGap.v(DabblerSpacing.space4)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabsDelegate(
            extent: _tabsExtent,
            child: _TabStrip(
              tab: _tab,
              onChanged: (SportTab t) => _openTab(t),
              labels: <SportTab, String>{
                for (final SportTab t in SportTab.values)
                  t: sportTabLabel(l, t),
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              top: DabblerSpacing.space4,
              bottom: DabblerSpacing.space11,
            ),
            child: cityPending
                ? const Padding(
                    padding: kSportGutter,
                    child: SportSectionSkeleton(rows: 3),
                  )
                : _content(sport, scope),
          ),
        ),
      ],
    );
  }

  Widget _content(SportInfo sport, SportScope scope) {
    final bool cityScoped = _tab != SportTab.posts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (cityScoped) ...<Widget>[
          SportCityBar(sportId: sport.id),
          const DabblerGap.v(DabblerSpacing.space4),
        ],
        switch (_tab) {
          SportTab.overview => SportOverviewTab(
            sport: sport,
            scope: scope,
            onOpenTab: _openTab,
          ),
          SportTab.games => SportGamesTab(sport: sport, scope: scope),
          SportTab.meetups => SportMeetupsTab(sport: sport, scope: scope),
          SportTab.venues => SportVenuesTab(
            scope: scope,
            mode: _venuesMode,
            onModeChanged: (SportVenuesMode m) =>
                setState(() => _venuesMode = m),
          ),
          SportTab.posts => SportPostsTab(sportId: sport.id),
        },
      ],
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tab,
    required this.onChanged,
    required this.labels,
  });

  final SportTab tab;
  final ValueChanged<SportTab> onChanged;
  final Map<SportTab, String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kSportGutter.add(
        const EdgeInsetsDirectional.symmetric(vertical: DabblerSpacing.space2),
      ),
      child: DabblerTabs(
        variant: DabblerTabsVariant.segmented,
        scrollable: true,
        value: tab.name,
        onChanged: (String id) =>
            onChanged(SportTab.values.firstWhere((t) => t.name == id)),
        items: <DabblerTabItem>[
          for (final SportTab t in SportTab.values)
            DabblerTabItem(id: t.name, label: labels[t]!),
        ],
      ),
    );
  }
}

/// Pins the tab strip under the top bar while the content scrolls.
class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DabblerSurface.sunken(
      fill: DabblerColors.of(context).bgPrimary,
      borderWidth: 0,
      center: true,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _TabsDelegate old) =>
      old.child != child || old.extent != extent;
}

class _PageError extends StatelessWidget {
  const _PageError({required this.notFound, required this.onRetry});

  final bool notFound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: kSportGutter,
      child: Center(
        child: DabblerEmptyState.error(
          title: notFound
              ? l.sport_overview_page_error_title
              : l.sport_overview_error_title,
          text: notFound
              ? l.sport_overview_page_error_text
              : l.sport_overview_error_text,
          retryLabel: l.sport_overview_retry,
          onRetry: onRetry,
        ),
      ),
    );
  }
}
