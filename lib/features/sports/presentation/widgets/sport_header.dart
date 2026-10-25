import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_artwork.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show Theme, ThemeData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const EdgeInsetsDirectional kSportGutter = EdgeInsetsDirectional.symmetric(
  horizontal: DabblerSpacing.space6,
);

/// `short()` of `Sport Overview v2.dc.html`: 12,400 stays whole, 12,500 and
/// above reads "12.5k" (a trailing ".0" is dropped).
String sportShortCount(int n, String locale) {
  if (n < 10000) return NumberFormat.decimalPattern(locale).format(n);
  final String k = (n / 1000)
      .toStringAsFixed(1)
      .replaceAll(RegExp(r'\.0$'), '');
  return '${k}k';
}

/// The page's identity block (the Profiles header): sport-tinted ground, the
/// supplied artwork, name and formats, the public-page and city chips, the
/// counters, Follow and Create game or meetup, the follow note and the mutuals.
///
/// The follower counter is not tappable and there is no Share or More control:
/// neither has a specified destination (recorded on KAN-591 and KAN-622), so
/// neither is drawn as a dead control.
class SportHeader extends ConsumerWidget {
  const SportHeader({
    super.key,
    required this.sport,
    required this.counts,
    required this.city,
    required this.onPickCity,
    required this.onOpenPosts,
  });

  final SportInfo sport;

  /// Null while the aggregates load or when they failed: no count is drawn.
  final SportOverviewCounts? counts;

  /// Null while the city is being worked out.
  final SportPageCity? city;
  final VoidCallback onPickCity;
  final VoidCallback onOpenPosts;

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool following,
  ) async {
    final SportFollowController controller = ref.read(
      sportFollowControllerProvider.notifier,
    );
    if (!following) {
      await controller.toggle(sport);
      return;
    }
    final AppLocalizations l = AppLocalizations.of(context);
    final String name = sport.name(
      Localizations.localeOf(context).languageCode,
    );
    final bool? confirmed = await showAppSheet<bool>(
      context: context,
      title: l.sport_overview_unfollow_title(name),
      detent: DabblerSheetDetent.content,
      builder: (BuildContext sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DabblerText(
            l.sport_overview_unfollow_text(name),
            style: DabblerType.smallTight,
            tone: DabblerTextTone.secondary,
          ),
          const DabblerGap.v(DabblerSpacing.space5),
          DabblerButton(
            label: l.sport_overview_unfollow_confirm,
            tone: DabblerButtonTone.destructive,
            size: DabblerButtonSize.block,
            fullWidth: true,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          DabblerButton(
            label: l.sport_overview_unfollow_cancel,
            tone: DabblerButtonTone.neutral,
            size: DabblerButtonSize.block,
            fullWidth: true,
            onPressed: () => Navigator.of(sheet).pop(false),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.toggle(sport);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final String lang = Localizations.localeOf(context).languageCode;
    final DabblerColors colors = DabblerColors.of(context);
    final String name = sport.name(lang);
    final bool following = ref.watch(
      profileControllerProvider.select(
        (s) => s.profile?.interests?.contains(sport.id) ?? false,
      ),
    );
    final SportFollowState follow = ref.watch(sportFollowControllerProvider);
    final bool canCreate = canCreateGameOrMeetup(
      ref.watch(activePersonaProvider),
    );
    final List<String> formats = sport
        .formats(lang)
        .where((String f) => f.trim().isNotEmpty)
        .toList();
    final List<String> mutual = <String>[
      for (final MutualFollower m in counts?.mutualFollowers ?? const [])
        if (m.label != null) m.label!,
    ];
    final String? cityName = city?.name;
    // The design tints the band `color-mix(var(--sport-p-600) 14%, white)` in
    // every theme: the DS full-bleed band resolved under the sport theme, with
    // the content put back under the app's own theme (purple Follow).
    final ThemeData appTheme = Theme.of(context);
    return Theme(
      data: DabblerDesignSystemTheme.withTokens(
        appTheme,
        theme: DabblerTheme.sport,
      ),
      child: DabblerSurface.brandTintBleed(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space7,
        ),
        child: Theme(
          data: appTheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: DabblerSizing.iconLg + DabblerSizing.iconLg,
                    child: SportArtwork(
                      sportKey: sport.sportKey,
                      size: DabblerSizing.iconLg + DabblerSizing.iconLg,
                      semanticLabel: name,
                    ),
                  ),
                  const DabblerGap.h(DabblerSpacing.space5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DabblerText(
                          name,
                          style: DabblerType.displayScreen,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const DabblerGap.v(DabblerSpacing.space1),
                        DabblerText(
                          formats.isEmpty
                              ? l.sport_overview_kind_plain
                              : l.sport_overview_kind_formats(
                                  formats.join(', '),
                                ),
                          style: DabblerType.smallTight,
                          tone: DabblerTextTone.secondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const DabblerGap.v(DabblerSpacing.space4),
              Wrap(
                spacing: DabblerSpacing.space2,
                runSpacing: DabblerSpacing.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _PublicChip(sportKey: sport.sportKey),
                  if (city != null)
                    _CityChip(
                      label: cityName ?? l.listing_select_city,
                      unset: cityName == null,
                      onTap: onPickCity,
                    ),
                ],
              ),
              if (counts != null) ...<Widget>[
                const DabblerGap.v(DabblerSpacing.space4),
                Row(
                  children: <Widget>[
                    _Counter(
                      value: sportShortCount(counts!.followers, locale),
                      label: l.sport_overview_followers_label(
                        counts!.followers,
                      ),
                    ),
                    const DabblerGap.h(DabblerSpacing.space6),
                    _Counter(
                      value: sportShortCount(counts!.posts, locale),
                      label: l.sport_overview_posts_label,
                      onTap: onOpenPosts,
                    ),
                  ],
                ),
              ],
              const DabblerGap.v(DabblerSpacing.space4),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DabblerButton(
                      label: following
                          ? l.sport_overview_following
                          : l.sport_overview_follow,
                      tone: following
                          ? DabblerButtonTone.outlined
                          : DabblerButtonTone.primary,
                      fullWidth: true,
                      loading: follow.busy,
                      leadingWidget: DabblerIcon(
                        following ? 'tick-circle' : 'add',
                        weight: DabblerIconWeight.bold,
                        size: DabblerSizing.iconSm,
                      ),
                      onPressed: () => _toggle(context, ref, following),
                    ),
                  ),
                  if (canCreate) ...<Widget>[
                    const DabblerGap.h(DabblerSpacing.space3),
                    DabblerButton(
                      label: l.sport_overview_create_game_or_meetup,
                      tone: DabblerButtonTone.outlined,
                      leadingWidget: const DabblerIcon(
                        'calendar-add',
                        size: DabblerSizing.iconSm,
                      ),
                      onPressed: () => context.push(
                        '${RoutePaths.createGame}?sport=${Uri.encodeQueryComponent(sport.id)}',
                      ),
                    ),
                  ],
                ],
              ),
              if (following) ...<Widget>[
                const DabblerGap.v(DabblerSpacing.space4),
                DabblerSurface(
                  radius: DabblerRadius.md,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: DabblerSpacing.space4,
                    vertical: DabblerSpacing.space3,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DabblerIcon(
                        'info-circle',
                        weight: DabblerIconWeight.bold,
                        size: DabblerSizing.iconInline,
                        color: colors.brandPrimary,
                      ),
                      const DabblerGap.h(DabblerSpacing.space3),
                      Expanded(
                        child: DabblerText(
                          l.sport_overview_follow_note(name),
                          style: DabblerType.caption1,
                          tone: DabblerTextTone.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (mutual.isNotEmpty) ...<Widget>[
                const DabblerGap.v(DabblerSpacing.space4),
                Row(
                  children: <Widget>[
                    DabblerAvatarGroup(
                      people: mutual,
                      imageUrls: <String?>[
                        for (final MutualFollower m
                            in counts?.mutualFollowers ??
                                const <MutualFollower>[])
                          if (m.label != null) m.avatarUrl,
                      ],
                    ),
                    const DabblerGap.h(DabblerSpacing.space4),
                    Expanded(
                      child: DabblerText(
                        switch (mutual.length) {
                          1 => l.sport_overview_mutual_one(mutual[0]),
                          2 => l.sport_overview_mutual_two(
                            mutual[0],
                            mutual[1],
                          ),
                          _ => l.sport_overview_mutual_three(
                            mutual[0],
                            mutual[1],
                            mutual[2],
                          ),
                        },
                        style: DabblerType.footnote,
                        tone: DabblerTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The brand pill "Public sport page" with the sport's bold glyph.
class _PublicChip extends StatelessWidget {
  const _PublicChip({required this.sportKey});

  final String? sportKey;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    return DabblerSurface.selected(
      radius: DabblerRadius.pill,
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space3,
        DabblerSpacing.space2,
        DabblerSpacing.space4,
        DabblerSpacing.space2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DabblerSportIcon.fromKey(
            (sportKey ?? 'unknown').replaceAll('_', '-'),
            size: DabblerSizing.iconInline,
            weight: DabblerIconWeight.bold,
            color: colors.onBrand,
          ),
          const DabblerGap.h(DabblerSpacing.space2),
          DabblerText(
            AppLocalizations.of(context).sport_overview_public_chip,
            style: DabblerType.caption1,
            weight: DabblerTextWeight.bold,
            tone: DabblerTextTone.onBrand,
          ),
        ],
      ),
    );
  }
}

/// The page's city chip. With no city it reads "Select city" in the brand
/// colour and border, as drawn.
class _CityChip extends StatelessWidget {
  const _CityChip({
    required this.label,
    required this.unset,
    required this.onTap,
  });

  final String label;
  final bool unset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    final Color fg = unset ? colors.brandPrimary : colors.textSecondary;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: DabblerSurface(
            radius: DabblerRadius.pill,
            borderColor: unset ? colors.brandPrimary : null,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: DabblerSpacing.space3,
              vertical: DabblerSpacing.space2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DabblerIcon(
                  'location',
                  size: DabblerSizing.iconInline,
                  color: fg,
                ),
                const DabblerGap.h(DabblerSpacing.space2),
                Flexible(
                  child: DabblerText(
                    label,
                    style: DabblerType.caption1,
                    weight: DabblerTextWeight.semibold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    tone: unset
                        ? DabblerTextTone.brand
                        : DabblerTextTone.secondary,
                  ),
                ),
                const DabblerGap.h(DabblerSpacing.space2),
                DabblerIcon(
                  'arrow-circle-down',
                  size: DabblerSizing.iconXs,
                  color: fg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        DabblerText(
          value,
          style: DabblerType.body,
          weight: DabblerTextWeight.bold,
        ),
        const DabblerGap.h(DabblerSpacing.space2),
        DabblerText(
          label,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
      ],
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$value $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}
