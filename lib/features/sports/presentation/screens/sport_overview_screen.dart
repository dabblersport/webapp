import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/sports/data/sport_follow_repository.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_city_sheet.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_header.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_tab_content.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// KAN-591: the public page of one sport (not any user's Sport Profile), drawn
/// as Sport Overview v2: its identity with Follow, then an Overview of the
/// next seven days in the page's city (a bento of counters and rails), and a
/// sub-view each for Games & meetups, Venues and Spaces, and Posts, opened
/// from a counter tile or a "See all". The city is page-local. Reached by sport
/// id from a sport tile or a deep route, behind `FeatureFlags.sportOverview`.
///
/// The identity block scrolls away into the top bar's pinned title. An unknown
/// sport id shows the page error state with Retry, never a crash. Browsing a
/// sport the viewer does not follow is allowed.
class SportOverviewScreen extends ConsumerStatefulWidget {
  const SportOverviewScreen({super.key, required this.sportId});

  final String sportId;

  @override
  ConsumerState<SportOverviewScreen> createState() =>
      _SportOverviewScreenState();
}

class _SportOverviewScreenState extends ConsumerState<SportOverviewScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _anchor = GlobalKey();
  SportView _view = SportView.overview;
  SportVenuesMode _venuesMode = SportVenuesMode.venues;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(SportView view, {SportVenuesMode? venuesMode}) {
    setState(() {
      _view = view;
      if (venuesMode != null) _venuesMode = venuesMode;
    });
    // Keep the start of the new view on screen when the header has scrolled
    // away; a view opened from the top leaves the identity block in place.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _anchor.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  void _back() => _open(SportView.overview);

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
          child: SportPendingContent(),
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
    final SportPageCity? city = ref
        .watch(sportPageCityProvider(sport.id))
        .valueOrNull;
    final SportScope scope = (sportId: sport.id, cityCode: city?.code);
    // The city is still being worked out: the sections wait with a skeleton
    // rather than asking for every city and then again for one.
    final SportOverviewCounts? counts = city == null
        ? null
        : ref.watch(sportOverviewCountsProvider(scope)).valueOrNull;

    return SingleChildScrollView(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SportHeader(
            sport: sport,
            counts: counts,
            city: city,
            onPickCity: () => pickSportCity(context, ref, sport.id),
            onOpenPosts: () => _open(SportView.posts),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          SizedBox.shrink(key: _anchor),
          _content(sport, scope, city, counts),
          const DabblerGap.v(DabblerSpacing.space10),
        ],
      ),
    );
  }

  Widget _content(
    SportInfo sport,
    SportScope scope,
    SportPageCity? city,
    SportOverviewCounts? counts,
  ) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    void changeCity() => pickSportCity(context, ref, sport.id);

    // Posts are tagged to the sport, not to a city: they never wait on one.
    if (_view == SportView.posts) {
      return SportPostsView(sport: sport, counts: counts, onBack: _back);
    }
    if (city == null) return const SportPendingContent();
    if (city.isNone) {
      return SportEmptyCard(
        brand: true,
        icon: 'location',
        title: l.sport_overview_nocity_title(sport.name(lang)),
        text: l.sport_overview_nocity_text,
        actionLabel: l.listing_select_city,
        onAction: changeCity,
      );
    }
    return switch (_view) {
      SportView.overview => SportOverviewContent(
        sport: sport,
        scope: scope,
        city: city,
        onOpen: _open,
        onChangeCity: changeCity,
      ),
      SportView.games => SportGamesView(
        sport: sport,
        scope: scope,
        city: city,
        onBack: _back,
        onChangeCity: changeCity,
      ),
      SportView.venues => SportVenuesView(
        sport: sport,
        scope: scope,
        city: city,
        mode: _venuesMode,
        onModeChanged: (SportVenuesMode m) => setState(() => _venuesMode = m),
        onBack: _back,
        onChangeCity: changeCity,
      ),
      SportView.posts => SportPostsView(
        sport: sport,
        counts: counts,
        onBack: _back,
      ),
    };
  }
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
