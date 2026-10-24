import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_formatters.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_cards.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_header.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_section_states.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

// KAN-591: the content under the Sport Overview v2 identity block. The design
// has no tab bar: the Overview is a bento of counters plus rails, and each
// "See all" or counter tile opens one sub-view with an "Overview" back link.

/// The views of the page. Overview is the default; the others are opened from
/// a counter tile or a "See all" and left with the back link.
enum SportView { overview, games, venues, posts }

/// Whether the Venues view shows venues or spaces: never mixed in one list.
enum SportVenuesMode { venues, spaces }

/// How many rows an Overview rail or preview shows.
const int kSportOverviewPreviewCount = 3;

extension on SportPageCity {
  /// The city's name for a sentence; only drawn when a city is chosen.
  String get label => name ?? '';
}

Widget _padded(Widget child) => Padding(padding: kSportGutter, child: child);

Widget _text(
  String data, {
  DabblerTypeStyle style = DabblerType.subheadline,
  DabblerTextWeight? weight,
  DabblerTextTone tone = DabblerTextTone.primary,
  int? maxLines,
  TextAlign? textAlign,
}) => DabblerText(
  data,
  style: style,
  weight: weight,
  tone: tone,
  maxLines: maxLines,
  textAlign: textAlign,
  overflow: maxLines == null ? null : TextOverflow.ellipsis,
);

// ---------------------------------------------------------------------------
// Shared pieces.
// ---------------------------------------------------------------------------

/// The design's empty card: a tile with an icon over a title, a text and an
/// optional "Change city" button.
class SportEmptyCard extends StatelessWidget {
  const SportEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.brand = false,
  });

  final String icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The no-city variant: a brand tile and a display title.
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final double tile = brand ? 48 : DabblerSizing.touchTargetMin;
    return Padding(
      padding: kSportGutter,
      child: DabblerSurface.card(
        radius: DabblerRadius.xl,
        padding: const EdgeInsets.symmetric(
          vertical: DabblerSpacing.space9,
          horizontal: DabblerSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            DabblerSurface(
              fill: brand ? colors.brandPrimary : colors.bgPrimary,
              borderColor: brand ? null : colors.surfaceSunken,
              borderWidth: brand ? 0 : 1,
              radius: DabblerRadius.md,
              width: tile,
              height: tile,
              center: true,
              child: DabblerIcon(
                icon,
                weight: brand
                    ? DabblerIconWeight.bold
                    : DabblerIconWeight.linear,
                size: brand
                    ? DabblerSizing.iconMd
                    : DabblerSizing.iconSm + DabblerSpacing.space1,
                color: brand ? colors.onBrand : colors.textSecondary,
              ),
            ),
            const DabblerGap.v(DabblerSpacing.space4),
            _text(
              title,
              style: brand ? DabblerType.title3 : DabblerType.subheadline,
              weight: brand ? null : DabblerTextWeight.semibold,
              textAlign: TextAlign.center,
            ),
            const DabblerGap.v(DabblerSpacing.space2),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DabblerSpacing.space6,
              ),
              child: _text(
                text,
                style: DabblerType.smallTight,
                tone: DabblerTextTone.secondary,
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const DabblerGap.v(DabblerSpacing.space4),
              DabblerButton(
                label: actionLabel!,
                tone: brand
                    ? DabblerButtonTone.primary
                    : DabblerButtonTone.outlined,
                size: DabblerButtonSize.medium,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A rail or preview header: a title and a brand "See all".
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final TextDirection dir = Directionality.of(context);
    return _padded(
      Row(
        children: <Widget>[
          Expanded(
            child: _text(
              title,
              weight: DabblerTextWeight.semibold,
              maxLines: 1,
            ),
          ),
          DabblerTextLink(
            label: l.sport_overview_see_all,
            underline: false,
            style: DabblerType.footnote
                .resolveForDirection(dir)
                .copyWith(fontWeight: DabblerType.semibold),
            onPressed: onSeeAll,
          ),
        ],
      ),
    );
  }
}

/// A sub-view's top: the "Overview" back link, then a summary and subtitle.
class _SubHeader extends StatelessWidget {
  const _SubHeader({
    required this.onBack,
    required this.title,
    required this.subtitle,
  });

  final VoidCallback onBack;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final DabblerColors colors = DabblerColors.of(context);
    return _padded(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            label: l.sport_overview_tab_overview,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: DabblerSizing.touchTargetMin,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DabblerIcon(
                      'arrow-left',
                      size: DabblerSizing.iconSm,
                      color: colors.brandPrimary,
                      mirrorInRtl: true,
                    ),
                    const DabblerGap.h(DabblerSpacing.space2),
                    _text(
                      l.sport_overview_tab_overview,
                      weight: DabblerTextWeight.semibold,
                      tone: DabblerTextTone.brand,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _text(title, weight: DabblerTextWeight.semibold),
          _text(
            subtitle,
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
        ],
      ),
    );
  }
}

/// A pill of the Venues / Spaces switch.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final Color fg = selected ? colors.onBrand : colors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: DabblerSizing.touchTargetMin,
          ),
          child: DabblerSurface(
            fill: selected ? colors.brandPrimary : colors.surfaceCard,
            borderColor: selected ? null : colors.borderDefault,
            borderWidth: selected ? 0 : 1,
            radius: DabblerRadius.pill,
            padding: const EdgeInsets.symmetric(
              horizontal: DabblerSpacing.space5,
            ),
            center: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DabblerIcon(
                  icon,
                  weight: selected
                      ? DabblerIconWeight.bold
                      : DabblerIconWeight.linear,
                  size: DabblerSizing.iconSm,
                  color: fg,
                ),
                const DabblerGap.h(DabblerSpacing.space2),
                _text(
                  label,
                  weight: DabblerTextWeight.semibold,
                  tone: selected
                      ? DabblerTextTone.onBrand
                      : DabblerTextTone.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview.
// ---------------------------------------------------------------------------

/// The bento's loading shape (`Sport Overview v2`, loading state).
class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    const double row = 78;
    const double gap = DabblerSpacing.space3;
    Widget tile(double h) =>
        DabblerSkeleton.rect(height: h, radius: DabblerRadius.card);
    return _padded(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(flex: 2, child: tile(row * 2 + gap)),
              const DabblerGap.h(gap),
              Expanded(
                child: Column(
                  children: <Widget>[
                    tile(row),
                    const DabblerGap.v(gap),
                    tile(row),
                  ],
                ),
              ),
            ],
          ),
          const DabblerGap.v(gap),
          Row(
            children: <Widget>[
              Expanded(child: tile(row)),
              const DabblerGap.h(gap),
              Expanded(child: tile(row)),
              const DabblerGap.h(gap),
              Expanded(child: tile(row)),
            ],
          ),
          const DabblerGap.v(gap),
          for (int i = 0; i < 3; i++) ...<Widget>[
            if (i > 0) const DabblerGap.v(DabblerSpacing.space2),
            DabblerSkeleton.rect(
              height: DabblerSpacing.space10 + DabblerSpacing.space10,
              radius: DabblerRadius.lg,
            ),
          ],
        ],
      ),
    );
  }
}

/// The page's loading shape while the city is still being worked out.
class SportPendingContent extends StatelessWidget {
  const SportPendingContent({super.key});

  @override
  Widget build(BuildContext context) => const _OverviewSkeleton();
}

class SportOverviewContent extends ConsumerWidget {
  const SportOverviewContent({
    super.key,
    required this.sport,
    required this.scope,
    required this.city,
    required this.onOpen,
    required this.onChangeCity,
  });

  final SportInfo sport;
  final SportScope scope;
  final SportPageCity city;

  /// Opens a sub-view (a counter tile or a "See all"). The Spaces tile also
  /// asks for the Spaces side of the Venues view.
  final void Function(SportView view, {SportVenuesMode? venuesMode}) onOpen;
  final VoidCallback onChangeCity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final String name = sport.name(lang);
    final AsyncValue<SportOverviewCounts> counts = ref.watch(
      sportOverviewCountsProvider(scope),
    );

    return counts.when(
      skipLoadingOnRefresh: false,
      loading: () => const _OverviewSkeleton(),
      error: (Object _, StackTrace _) => _padded(
        DabblerBanner(
          tone: DabblerBannerTone.error,
          title: l.sport_overview_banner_title(name, city.label),
          message: l.sport_overview_banner_text,
          action: DabblerBannerAction(
            label: l.sport_overview_banner_action,
            onPressed: () => ref.invalidate(sportOverviewCountsProvider(scope)),
          ),
        ),
      ),
      data: (SportOverviewCounts c) {
        if (c.gamesNext7 == 0 &&
            c.meetupsNext7 == 0 &&
            c.venues == 0 &&
            c.posts == 0) {
          return SportEmptyCard(
            icon: 'calendar',
            title: l.sport_overview_empty_all_title(name, city.label),
            text: l.sport_overview_empty_all_text,
            actionLabel: l.sport_overview_change_city,
            onAction: onChangeCity,
          );
        }
        return _Loaded(
          sport: sport,
          scope: scope,
          city: city,
          counts: c,
          onOpen: onOpen,
        );
      },
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.sport,
    required this.scope,
    required this.city,
    required this.counts,
    required this.onOpen,
  });

  final SportInfo sport;
  final SportScope scope;
  final SportPageCity city;
  final SportOverviewCounts counts;
  final void Function(SportView view, {SportVenuesMode? venuesMode}) onOpen;

  /// "Next: {day} {time}" of the soonest game or meetup, when both lists have
  /// loaded and one is not empty.
  String? _next(
    AppLocalizations l,
    String locale,
    List<NearbyGameModel>? games,
    List<MeetupListItem>? meetups,
  ) {
    final DateTime now = DateTime.now();
    DateTime? soonest;
    for (final NearbyGameModel g in games ?? const <NearbyGameModel>[]) {
      final DateTime? at = g.scheduledAt;
      if (at != null && (soonest == null || at.isBefore(soonest))) soonest = at;
    }
    for (final MeetupListItem m in meetups ?? const <MeetupListItem>[]) {
      if (soonest == null || m.startAt.isBefore(soonest)) soonest = m.startAt;
    }
    if (soonest == null) return null;
    return l.sport_overview_hero_next(
      '${meetupDayLabel(l, soonest, now, locale)} '
      '${DateFormat.jm(locale).format(soonest)}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final String locale = Localizations.localeOf(context).toString();
    final String name = sport.name(lang);
    final DabblerColors colors = DabblerColors.of(context);
    final List<NearbyGameModel>? games = ref
        .watch(sportGamesProvider(scope))
        .valueOrNull;
    final List<MeetupListItem>? meetups = ref
        .watch(sportMeetupsProvider(scope))
        .valueOrNull;
    final List<SportVenue>? venues = ref
        .watch(sportVenuesProvider(scope))
        .valueOrNull;
    String num(int n) => NumberFormat.decimalPattern(locale).format(n);
    final String next = _next(l, locale, games, meetups) ?? '';
    final String heroSub = <String>[
      l.sport_overview_count_games(counts.gamesNext7),
      l.sport_overview_count_meetups(counts.meetupsNext7),
      if (next.isNotEmpty) next,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _padded(
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: _text(
                  l.sport_overview_play_in(name, city.label),
                  weight: DabblerTextWeight.semibold,
                  maxLines: 1,
                ),
              ),
              const DabblerGap.h(DabblerSpacing.space3),
              _text(
                l.sport_overview_next_7_days,
                style: DabblerType.footnote,
                tone: DabblerTextTone.secondary,
              ),
            ],
          ),
        ),
        // A city nothing is grouped under queries every city; say so rather
        // than let the heading imply a city scope the numbers do not have.
        if (!city.isMapped) ...<Widget>[
          const DabblerGap.v(DabblerSpacing.space2),
          _padded(
            _text(
              l.sport_overview_city_unmapped(city.label),
              style: DabblerType.footnote,
              tone: DabblerTextTone.secondary,
            ),
          ),
          const DabblerGap.v(DabblerSpacing.space2),
        ],
        _padded(
          DabblerStatGrid(
            children: <DabblerStatTile>[
              DabblerStatTile(
                value: num(counts.gamesNext7 + counts.meetupsNext7),
                label: l.sport_overview_tile_games_meetups,
                sub: heroSub,
                size: DabblerStatTileSize.hero,
                tone: DabblerStatTileTone.brand,
                trailing: DabblerIcon(
                  'arrow-right',
                  size: DabblerSizing.iconSm,
                  color: colors.onBrand,
                  mirrorInRtl: true,
                ),
                onTap: () => onOpen(SportView.games),
              ),
              DabblerStatTile(
                value: num(counts.posts),
                label: l.sport_overview_stat_posts,
                tone: DabblerStatTileTone.ink,
                onTap: () => onOpen(SportView.posts),
              ),
              DabblerStatTile(
                value: num(counts.venues),
                label: l.sport_overview_stat_venues,
                sub: l.sport_overview_tile_venues_sub,
                tone: DabblerStatTileTone.amber,
                onTap: () => onOpen(
                  SportView.venues,
                  venuesMode: SportVenuesMode.venues,
                ),
              ),
            ],
          ),
        ),
        if (games != null && games.isNotEmpty) ...<Widget>[
          const DabblerGap.v(DabblerSpacing.space3),
          _SectionHeader(
            title: l.sport_overview_section_games,
            onSeeAll: () => onOpen(SportView.games),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          _Rail(
            children: <Widget>[
              for (final NearbyGameModel g in games.take(
                kSportOverviewPreviewCount,
              ))
                SportRailGameCard(
                  key: ValueKey<String>('rail-game-${g.id}'),
                  game: g,
                  sport: sport,
                  onJoined: () => ref.invalidate(sportGamesProvider(scope)),
                ),
            ],
          ),
        ],
        if (venues != null && venues.isNotEmpty) ...<Widget>[
          const DabblerGap.v(DabblerSpacing.space3),
          _SectionHeader(
            title: l.sport_overview_section_top_venues,
            onSeeAll: () =>
                onOpen(SportView.venues, venuesMode: SportVenuesMode.venues),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          _Rail(
            children: <Widget>[
              for (final SportVenue v in venues.take(
                kSportOverviewPreviewCount,
              ))
                SportRailVenueCard(
                  key: ValueKey<String>('rail-venue-${v.id}'),
                  venue: v,
                ),
            ],
          ),
        ],
        const DabblerGap.v(DabblerSpacing.space3),
        _SectionHeader(
          title: l.sport_overview_posts_label,
          onSeeAll: () => onOpen(SportView.posts),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        _PostsBody(sportId: sport.id, limit: kSportOverviewPreviewCount),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: kSportGutter,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const DabblerGap.h(DabblerSpacing.space4),
            children[i],
          ],
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Games & meetups.
// ---------------------------------------------------------------------------

class SportGamesView extends ConsumerWidget {
  const SportGamesView({
    super.key,
    required this.sport,
    required this.scope,
    required this.city,
    required this.onBack,
    required this.onChangeCity,
  });

  final SportInfo sport;
  final SportScope scope;
  final SportPageCity city;
  final VoidCallback onBack;
  final VoidCallback onChangeCity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final String name = sport.name(lang);
    final AsyncValue<List<NearbyGameModel>> games = ref.watch(
      sportGamesProvider(scope),
    );
    final AsyncValue<List<MeetupListItem>> meetups = ref.watch(
      sportMeetupsProvider(scope),
    );
    final int gameCount = games.valueOrNull?.length ?? 0;
    final int meetupCount = meetups.valueOrNull?.length ?? 0;
    final bool loaded = games.hasValue && meetups.hasValue;
    final String summary = loaded
        ? <String>[
            l.sport_overview_count_games(gameCount),
            l.sport_overview_count_meetups(meetupCount),
          ].join(' · ')
        : l.sport_overview_tile_games_meetups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SubHeader(
          onBack: onBack,
          title: summary,
          subtitle: l.sport_overview_sub_next7(city.label),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        if (loaded && gameCount == 0 && meetupCount == 0)
          SportEmptyCard(
            icon: 'calendar',
            title: l.sport_overview_empty_games_city_title(name, city.label),
            text: l.sport_overview_empty_next7_text,
            actionLabel: l.sport_overview_change_city,
            onAction: onChangeCity,
          )
        else ...<Widget>[
          _padded(
            sportAsyncSection<List<NearbyGameModel>>(
              value: games,
              isEmpty: (List<NearbyGameModel> g) => g.isEmpty,
              empty: const SizedBox.shrink(),
              onRetry: () => ref.invalidate(sportGamesProvider(scope)),
              data: (List<NearbyGameModel> list) => _rows(<Widget>[
                for (final NearbyGameModel g in list)
                  SportGameRow(
                    key: ValueKey<String>('game-${g.id}'),
                    game: g,
                    sport: sport,
                    onJoined: () => ref.invalidate(sportGamesProvider(scope)),
                  ),
              ]),
            ),
          ),
          if (meetupCount > 0 || meetups.isLoading || meetups.hasError)
            const DabblerGap.v(DabblerSpacing.space2),
          _padded(
            sportAsyncSection<List<MeetupListItem>>(
              value: meetups,
              isEmpty: (List<MeetupListItem> m) => m.isEmpty,
              empty: const SizedBox.shrink(),
              onRetry: () => ref.invalidate(sportMeetupsProvider(scope)),
              data: (List<MeetupListItem> list) => _rows(<Widget>[
                for (final MeetupListItem m in list)
                  SportMeetupRow(
                    key: ValueKey<String>('meetup-${m.id}'),
                    meetup: m,
                    sport: sport,
                    onChanged: () =>
                        ref.invalidate(sportMeetupsProvider(scope)),
                  ),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

Widget _rows(List<Widget> rows) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: <Widget>[
    for (int i = 0; i < rows.length; i++) ...<Widget>[
      if (i > 0) const DabblerGap.v(DabblerSpacing.space2),
      rows[i],
    ],
  ],
);

// ---------------------------------------------------------------------------
// Venues / Spaces.
// ---------------------------------------------------------------------------

class SportVenuesView extends ConsumerWidget {
  const SportVenuesView({
    super.key,
    required this.sport,
    required this.scope,
    required this.city,
    required this.mode,
    required this.onModeChanged,
    required this.onBack,
    required this.onChangeCity,
  });

  final SportInfo sport;
  final SportScope scope;
  final SportPageCity city;
  final SportVenuesMode mode;
  final ValueChanged<SportVenuesMode> onModeChanged;
  final VoidCallback onBack;
  final VoidCallback onChangeCity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final String name = sport.name(lang);
    final bool venuesMode = mode == SportVenuesMode.venues;
    final AsyncValue<List<SportVenue>> venues = ref.watch(
      sportVenuesProvider(scope),
    );
    final AsyncValue<List<SportSpace>> spaces = ref.watch(
      sportSpacesProvider(scope),
    );
    final int? count = venuesMode
        ? venues.valueOrNull?.length
        : spaces.valueOrNull?.length;
    final String title = count == null
        ? (venuesMode
              ? l.sport_overview_stat_venues
              : l.sport_overview_stat_spaces)
        : (venuesMode
              ? l.sport_overview_count_venues(count)
              : l.sport_overview_count_spaces(count));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SubHeader(
          onBack: onBack,
          title: title,
          subtitle: venuesMode
              ? l.sport_overview_sub_venues(name, city.label)
              : l.sport_overview_sub_spaces(city.label),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        _padded(
          Row(
            children: <Widget>[
              _Pill(
                icon: 'building',
                label: l.sport_overview_switch_venues,
                selected: venuesMode,
                onTap: () => onModeChanged(SportVenuesMode.venues),
              ),
              const DabblerGap.h(DabblerSpacing.space2),
              _Pill(
                icon: 'grid-5',
                label: l.sport_overview_switch_spaces,
                selected: !venuesMode,
                onTap: () => onModeChanged(SportVenuesMode.spaces),
              ),
            ],
          ),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        if (venuesMode)
          _padded(
            sportAsyncSection<List<SportVenue>>(
              value: venues,
              isEmpty: (List<SportVenue> v) => v.isEmpty,
              empty: const SizedBox.shrink(),
              onRetry: () => ref.invalidate(sportVenuesProvider(scope)),
              data: (List<SportVenue> list) => _rows(<Widget>[
                for (final SportVenue v in list)
                  SportVenueCard(
                    key: ValueKey<String>('venue-${v.id}'),
                    venue: v,
                  ),
              ]),
            ),
          )
        else
          _padded(
            sportAsyncSection<List<SportSpace>>(
              value: spaces,
              isEmpty: (List<SportSpace> s) => s.isEmpty,
              empty: const SizedBox.shrink(),
              onRetry: () => ref.invalidate(sportSpacesProvider(scope)),
              data: (List<SportSpace> list) => _rows(<Widget>[
                for (final SportSpace s in list)
                  SportSpaceRow(
                    key: ValueKey<String>('space-${s.id}'),
                    space: s,
                  ),
              ]),
            ),
          ),
        if (venuesMode &&
            venues.hasValue &&
            (venues.valueOrNull?.isEmpty ?? false))
          SportEmptyCard(
            icon: 'building',
            title: l.sport_overview_empty_venues_city_title(name, city.label),
            text: l.sport_overview_empty_venues_city_text(name),
            actionLabel: l.sport_overview_change_city,
            onAction: onChangeCity,
          ),
        if (!venuesMode &&
            spaces.hasValue &&
            (spaces.valueOrNull?.isEmpty ?? false))
          SportEmptyCard(
            icon: 'grid-5',
            title: l.sport_overview_empty_spaces_city_title(name, city.label),
            text: l.sport_overview_empty_spaces_city_text,
            actionLabel: l.sport_overview_change_city,
            onAction: onChangeCity,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Posts.
// ---------------------------------------------------------------------------

class SportPostsView extends ConsumerWidget {
  const SportPostsView({
    super.key,
    required this.sport,
    required this.counts,
    required this.onBack,
  });

  final SportInfo sport;
  final SportOverviewCounts? counts;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final SportPostsState state = ref.watch(sportPostsProvider(sport.id));
    final int total = counts?.posts ?? state.posts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SubHeader(
          onBack: onBack,
          title: l.sport_overview_count_posts(total),
          subtitle: l.sport_overview_sub_posts(sport.name(lang)),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        _PostsBody(sportId: sport.id, paged: true),
      ],
    );
  }
}

/// The sport-tagged posts, newest first. Rows are the Home feed's post row, so
/// the existing post actions work; the Following filter is not applied.
class _PostsBody extends ConsumerWidget {
  const _PostsBody({required this.sportId, this.limit, this.paged = false});

  final String sportId;
  final int? limit;
  final bool paged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final SportPostsState state = ref.watch(sportPostsProvider(sportId));
    final SportPostsNotifier notifier = ref.read(
      sportPostsProvider(sportId).notifier,
    );
    if (state.loading) {
      return _padded(const SportSectionSkeleton());
    }
    if (state.error != null) {
      return _padded(SportSectionError(onRetry: notifier.load));
    }
    if (state.posts.isEmpty) {
      return _padded(
        SportSectionEmpty(
          icon: 'message-text',
          title: l.sport_overview_empty_posts_title,
          text: l.sport_overview_empty_posts_text,
        ),
      );
    }
    final List<Post> posts = limit == null
        ? state.posts
        : state.posts.take(limit!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Post p in posts) ...<Widget>[
          Padding(
            padding: DabblerInsets.feedScreen,
            child: HomePostRow.resolve(
              p,
              metrics: DabblerFeedMetrics.drawn,
              currentSportId: sportId,
            ),
          ),
          const DabblerDivider(),
        ],
        if (paged && state.loadMoreFailed)
          _padded(SportSectionError(onRetry: notifier.loadMore)),
        if (paged && state.hasMore && !state.loadMoreFailed)
          _padded(
            DabblerButton(
              label: l.sport_overview_load_more,
              tone: DabblerButtonTone.neutral,
              fullWidth: true,
              loading: state.loadingMore,
              onPressed: notifier.loadMore,
            ),
          ),
      ],
    );
  }
}
