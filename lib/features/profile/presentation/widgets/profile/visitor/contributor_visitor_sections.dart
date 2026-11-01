import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/presentation/models/contributor_profile_data.dart';
import 'package:dabbler/features/profile/presentation/providers/contributor_profile_provider.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_sport_picker.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show sportsProvider;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'contributor_visitor_bento.dart';
import 'contributor_visitor_upcoming.dart';

/// The body of a Contributor's profile as another user sees it, between the
/// identity header and the feed (`Profiles.dc.html` `contributorVisitor`):
/// the practicing-sport selector, the bento it scopes, and the public
/// Upcoming list. Owner surfaces (Manage, Needs attention, Games I organise,
/// drafts) are not part of this widget at all.
///
/// Reads only the KAN-686 typed read model for this profile id. Loading is a
/// spinner, a failed read is a retry, and neither is drawn as a number.
///
/// The `on*` callbacks are the correction D seams: each defaults to the
/// existing route and is replaceable by a caller or a test.
class ContributorVisitorSections extends ConsumerStatefulWidget {
  const ContributorVisitorSections({
    super.key,
    required this.userId,
    required this.profileId,
    this.primarySportId,
    this.onOpenSport,
    this.onOpenAllSports,
    this.onOpenEntity,
    this.now,
  });

  /// The genuine auth user id of the viewed profile.
  final String userId;

  /// The viewed `profiles.id`.
  final String profileId;

  /// The profile's Primary sport; dotted only when it is also practiced.
  final String? primarySportId;

  /// Opens the chosen sport's profile from the hero; null leaves it inert.
  final ValueChanged<Sport>? onOpenSport;

  /// The All-sports hero link (KAN-688 ruling: opens /activities).
  final VoidCallback? onOpenAllSports;

  /// Opens an Upcoming row; defaults to the game or meetup detail route.
  final ValueChanged<ContributorEntity>? onOpenEntity;

  /// The clock the scope is cut at; tests pin it.
  final DateTime? now;

  static const ValueKey<String> loadingKey = ValueKey<String>(
    'visitor-sections-loading',
  );

  @override
  ConsumerState<ContributorVisitorSections> createState() =>
      _ContributorVisitorSectionsState();
}

class _ContributorVisitorSectionsState
    extends ConsumerState<ContributorVisitorSections> {
  String? _selectedSportId;

  ContributorProfileArgs get _args =>
      (userId: widget.userId, profileId: widget.profileId);

  void _retry() => ref.invalidate(contributorProfileProvider(_args));

  void _open(ContributorEntity e) {
    final ValueChanged<ContributorEntity>? open = widget.onOpenEntity;
    if (open != null) return open(e);
    context.push(
      e.kind == ContributorEntityKind.game
          ? RoutePaths.gameDetail(e.id)
          : RoutePaths.meetupDetail(e.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ContributorProfileData> async = ref.watch(
      contributorProfileProvider(_args),
    );
    return async.when(
      loading: () => const Padding(
        key: ContributorVisitorSections.loadingKey,
        padding: EdgeInsets.all(DabblerSpacing.space11),
        child: Center(child: DabblerSpinner()),
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ContributorVisitorBento(
            games: SourceFailed<List<ContributorEntity>>(
              StateError('contributor profile unavailable'),
            ),
            scope: null,
            selected: null,
            sportsCount: null,
            onRetry: _retry,
          ),
          const DabblerGap.v(DabblerSpacing.space8),
        ],
      ),
      data: _body,
    );
  }

  Widget _body(ContributorProfileData data) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Sport> all = ref.watch(sportsProvider).valueOrNull ?? <Sport>[];
    final Map<String, Sport> byId = <String, Sport>{
      for (final Sport s in all) s.id: s,
    };
    final List<ContributorSport>? practicing = data.sports.valueOrNull;
    final List<Sport> sports = <Sport>[
      for (final ContributorSport p in practicing ?? <ContributorSport>[])
        if (byId[p.sportId] != null) byId[p.sportId]!,
    ];
    final Sport? selected = sports
        .where((Sport s) => s.id == _selectedSportId)
        .firstOrNull;
    final String? primary = sports.any((s) => s.id == widget.primarySportId)
        ? widget.primarySportId
        : null;
    final ContributorScope? scope = data.scope(
      sportId: selected?.id,
      now: widget.now,
    );
    final bool eventsKnown =
        data.games is SourceData && data.meetups is SourceData;
    final List<ContributorEntity> upcoming =
        scope?.upcoming ?? const <ContributorEntity>[];
    final ValueChanged<Sport>? openSport = widget.onOpenSport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (sports.isNotEmpty) ...<Widget>[
          OwnProfileSportPicker(
            title: l10n.profile_visitor_sports_title,
            sports: sports,
            selectedId: selected?.id,
            primaryId: primary,
            onSelect: (String? id) => setState(() => _selectedSportId = id),
          ),
          const DabblerGap.v(DabblerSpacing.space6),
        ],
        ContributorVisitorBento(
          games: data.games,
          scope: scope,
          selected: selected,
          sportsCount: practicing?.length,
          onRetry: _retry,
          onOpenSport: selected == null
              ? widget.onOpenAllSports
              : openSport != null
              ? () => openSport(selected)
              : null,
        ),
        const DabblerGap.v(DabblerSpacing.space8),
        if (!eventsKnown) ...<Widget>[
          ContributorVisitorUpcomingFailed(onRetry: _retry),
          const DabblerGap.v(DabblerSpacing.space8),
        ] else if (upcoming.isNotEmpty) ...<Widget>[
          ContributorVisitorUpcoming(rows: upcoming, onOpen: _open),
          const DabblerGap.v(DabblerSpacing.space8),
        ],
      ],
    );
  }
}
