import 'package:dabbler/features/location/presentation/widgets/home_location_picker_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
// Material is imported for the transparent [Material] ancestor only. The
// location widgets hosted in sheets below (`HomeLocationPickerSheet`,
// `NearbyFilterBar`) are not migrated yet and need one; it paints nothing.
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared, design-system-only pieces for the Games and Venues listings
/// (KAN-416, Listings frames L01 and L03). Nothing here is Material apart
/// from the transparent ancestor noted above.

/// A design-system type step resolved for the ambient text direction.
TextStyle listingText(
  BuildContext context,
  DabblerTypeStyle step, {
  Color? color,
  FontWeight? weight,
}) {
  final TextStyle base = step.resolveForDirection(Directionality.of(context));
  return base.copyWith(color: color, fontWeight: weight);
}

/// Maps a sport's display name (as the games and venues rows carry it) to the
/// DS sport, or null when the system has no artwork for it.
DabblerSport? listingSportFor(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final String key = name.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
  const Map<String, DabblerSport> aliases = <String, DabblerSport>{
    'soccer': DabblerSport.football,
    'futsal': DabblerSport.football,
    'ping-pong': DabblerSport.tableTennis,
    'tabletennis': DabblerSport.tableTennis,
    'fitness': DabblerSport.gym,
    'field-hockey': DabblerSport.hockey,
    'ice-hockey': DabblerSport.hockey,
  };
  return DabblerSport.fromKey(key) ?? aliases[key];
}

/// The listing header of the Listings frames: a display title with the
/// app-level location row beneath it, then the screen's own icon actions and
/// the filter button (with its active-filter count).
///
/// The location row reflects [activeLocationProvider] — the single app-level
/// selection — and opens the same picker the old top bar opened.
class ListingHeader extends ConsumerWidget {
  const ListingHeader({
    super.key,
    required this.title,
    required this.onFilter,
    this.filterCount = 0,
    this.actions = const <Widget>[],
  });

  final String title;
  final VoidCallback onFilter;

  /// Number of narrowing filters on; zero hides the count.
  final int filterCount;

  /// Icon actions placed before the filter button.
  final List<Widget> actions;

  void _openLocationPicker(BuildContext context) {
    showDabblerSheet<void>(
      context: context,
      detents: const <double>[0.85],
      builder: (_) => const _LocationPickerHost(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DabblerColors colors = DabblerColors.of(context);
    final locState = ref.watch(activeLocationProvider).valueOrNull;
    final String locationName = locState is ActiveLocationReady
        ? locState.location.area.name
        : 'Set location';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space2,
          DabblerSpacing.space6,
          DabblerSpacing.space3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listingText(
                      context,
                      DabblerType.title1,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: DabblerSpacing.space1),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openLocationPicker(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        DabblerIcon(
                          'location',
                          weight: DabblerIconWeight.bold,
                          size: 13,
                          color: colors.brandPrimary,
                        ),
                        const SizedBox(width: DabblerSpacing.space1),
                        Flexible(
                          child: Text(
                            locationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: listingText(
                              context,
                              DabblerType.caption2,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: DabblerSpacing.space1),
                        DabblerIcon(
                          'arrow-circle-down',
                          size: 12,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final Widget action in actions) ...<Widget>[
              action,
              const SizedBox(width: DabblerSpacing.space2),
            ],
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                DabblerButton.icon(
                  icon: 'filter',
                  semanticLabel: 'Filters',
                  tone: DabblerButtonTone.outlined,
                  onPressed: onFilter,
                ),
                if (filterCount > 0)
                  PositionedDirectional(
                    top: -DabblerSpacing.space1,
                    end: -DabblerSpacing.space1,
                    child: IgnorePointer(
                      child: DabblerBadge(
                        label: '$filterCount',
                        tone: DabblerBadgeTone.pill,
                        minWidth: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns the scroll controller [HomeLocationPickerSheet] expects from its host.
class _LocationPickerHost extends StatefulWidget {
  const _LocationPickerHost();

  @override
  State<_LocationPickerHost> createState() => _LocationPickerHostState();
}

class _LocationPickerHostState extends State<_LocationPickerHost> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: HomeLocationPickerSheet(scrollController: _controller),
  );
}

/// Hosts a not-yet-migrated widget inside a design-system sheet: a transparent
/// [Material] ancestor, nothing painted.
class ListingMaterialHost extends StatelessWidget {
  const ListingMaterialHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}

/// One applied filter, shown as a removable chip.
class ListingActiveFilter {
  const ListingActiveFilter({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;
}

/// The applied-filters rail under the tabs: a selected chip per filter (tap
/// clears it) and a trailing "Clear all". Renders nothing when empty.
class ListingActiveFilters extends StatelessWidget {
  const ListingActiveFilters({
    super.key,
    required this.filters,
    required this.onClearAll,
  });

  final List<ListingActiveFilter> filters;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: DabblerSizing.touchTargetMin,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final ListingActiveFilter f in filters) ...<Widget>[
            Center(
              child: DabblerChip(
                label: f.label,
                selected: true,
                leadingIcon: const DabblerIcon('close-circle', size: 16),
                onTap: f.onClear,
              ),
            ),
            const SizedBox(width: DabblerSpacing.space2),
          ],
          Center(
            child: DabblerButton(
              label: 'Clear all',
              tone: DabblerButtonTone.neutral,
              size: DabblerButtonSize.small,
              onPressed: onClearAll,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled group of option chips inside a filter sheet.
class ListingFilterGroup extends StatelessWidget {
  const ListingFilterGroup({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: listingText(
            context,
            DabblerType.footnote,
            color: colors.textSecondary,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DabblerSpacing.space3),
        Wrap(
          spacing: DabblerSpacing.space3,
          runSpacing: DabblerSpacing.space3,
          children: children,
        ),
      ],
    );
  }
}

/// A labelled section of a filter sheet that holds one arbitrary widget
/// (not a wrap of chips).
class ListingFilterSection extends StatelessWidget {
  const ListingFilterSection({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: listingText(
            context,
            DabblerType.footnote,
            color: colors.textSecondary,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DabblerSpacing.space1),
        child,
      ],
    );
  }
}

/// The body of a listing filter sheet: a Reset action, then the groups.
class ListingFilterBody extends StatelessWidget {
  const ListingFilterBody({
    super.key,
    required this.groups,
    required this.onReset,
  });

  final List<Widget> groups;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);
    // The sheet owns the 18dp gutter and the scrolling.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The design's header row: "Filters" with Reset at the end. Drawn here
        // rather than as the sheet's title (a text step, so the hard-coded
        // English still renders under the Arabic display face).
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Filters',
                style: listingText(
                  context,
                  DabblerType.headline,
                  color: colors.textPrimary,
                ),
              ),
            ),
            DabblerButton(
              label: 'Reset',
              tone: DabblerButtonTone.neutral,
              size: DabblerButtonSize.small,
              onPressed: onReset,
            ),
          ],
        ),
        for (final Widget g in groups) ...<Widget>[
          const SizedBox(height: DabblerSpacing.space6),
          g,
        ],
      ],
    );
  }
}

/// Opens a listing filter sheet: title "Filters", the [builder] body and a
/// full-width done button that closes it. The filters apply live as they are
/// picked, exactly as the old inline chips did.
Future<void> showListingFilterSheet(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showDabblerSheet<void>(
    context: context,
    detents: const <double>[0.8],
    builder: builder,
    // The sheet's footer bar carries its own padding.
    footerBuilder: (BuildContext ctx) => DabblerButton(
      label: 'Done',
      fullWidth: true,
      onPressed: () => Navigator.of(ctx).pop(),
    ),
  );
}

/// An empty listing (no results), in the design's empty-card shape.
class ListingEmpty extends StatelessWidget {
  const ListingEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final String icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space10),
        child: DabblerEmptyState(icon: icon, title: title, text: text),
      ),
    );
  }
}

/// A listing that failed to load, with its retry.
class ListingError extends StatelessWidget {
  const ListingError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space8),
        child: DabblerEmptyState.error(
          title: message,
          size: DabblerEmptyStateSize.inline,
          onRetry: onRetry,
          retryLabel: 'Retry',
        ),
      ),
    );
  }
}

/// The loading list: six card skeletons.
class ListingSkeleton extends StatelessWidget {
  const ListingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.only(
        top: DabblerSpacing.space4,
        bottom: DabblerSpacing.space8,
      ),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: DabblerSpacing.space4),
      itemBuilder: (_, __) => const DabblerSkeleton.card(),
    );
  }
}

/// A full-page spinner (the sport list is still loading).
class ListingPageSpinner extends StatelessWidget {
  const ListingPageSpinner({super.key});

  @override
  Widget build(BuildContext context) =>
      const DabblerPage(body: Center(child: DabblerSpinner()));
}

/// The cover of a listing card: the DS neutral well. The design system draws
/// sport artwork here when the host app ships
/// `assets/images/sports/<sport>-main-background.png`; this app does not ship
/// them yet, and an unresolved asset would leave an empty cover and an image
/// error per card, so the well is passed explicitly. The sport overlay mark
/// still identifies the sport.
class ListingCover extends StatelessWidget {
  const ListingCover({super.key});

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: DabblerColors.of(context).surfaceGrey);
}

/// The badge row a listing card carries in its footer.
class ListingBadgeRow extends StatelessWidget {
  const ListingBadgeRow({super.key, required this.badges});

  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DabblerSpacing.space2,
      runSpacing: DabblerSpacing.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: badges,
    );
  }
}
