import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart'
    show gamesSkillTierFor, gamesSkillTierLabel;
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_filters.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_follow.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_share.dart';
import 'package:dabbler/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart'
    show isFollowingProvider, myProfileIdProvider;
import 'package:dabbler/features/meetups/presentation/rsvp_state.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_formatters.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_rsvp_sheet.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_toasts.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Meetup details, drawn from `Details.dc.html` "Meetup details": an amber
/// [DabblerDetailHeader], who is going, the fact tiles and the host, over a
/// [DabblerActionBar] whose [DabblerRsvpCta] follows
/// `can_current_user_rsvp_meetup`.
///
/// Not drawn, with no data or feature behind them: favourite and share (not in
/// this ticket), "What to bring" and "The route" (no field on the meetup),
/// the header's activity chips (the card carries no sport).
class MeetupDetailScreen extends ConsumerStatefulWidget {
  const MeetupDetailScreen({
    super.key,
    required this.meetupId,
    this.onBack,
    this.onSwitchProfile,
  });

  final String meetupId;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  /// Opens the profile switcher; defaults to its route.
  final VoidCallback? onSwitchProfile;

  @override
  ConsumerState<MeetupDetailScreen> createState() => _MeetupDetailScreenState();
}

class _MeetupDetailScreenState extends ConsumerState<MeetupDetailScreen> {
  /// The headcount's faces — the frame's six (`Details.dc.html:84`, `crowd`).
  static const int maxFaces = 6;

  bool _busy = false;

  Future<void> _run(RsvpAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final toasts = DabblerToastProvider.maybeOf(context);
    final l = AppLocalizations.of(context);
    final result = await ref
        .read(meetupActionsProvider)
        .rsvp(widget.meetupId, action);
    result.fold((f) => showMeetupFailure(toasts, l, f), (_) {});
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _press(DabblerRsvpCtaState state, MeetupCard card) async {
    final action = rsvpActionFor(state);
    if (action != null) return _run(action);
    switch (state) {
      case DabblerRsvpCtaState.going:
      case DabblerRsvpCtaState.interested:
      case DabblerRsvpCtaState.pending:
        final l = AppLocalizations.of(context);
        final locale = Localizations.localeOf(context).toString();
        final at = card.startAt;
        final picked = await showMeetupRsvpSheet(
          context,
          title: l.meetups_sheet_title,
          subtitle: <String>[
            card.title ?? '',
            if (at != null) DateFormat.MMMd(locale).add_jm().format(at),
            ?card.locationName,
          ].where((s) => s.isNotEmpty).join(' · '),
          current: switch (state) {
            DabblerRsvpCtaState.going => RsvpAction.going,
            DabblerRsvpCtaState.interested => RsvpAction.interested,
            _ => null,
          },
        );
        if (picked != null && mounted) await _run(picked);
      case DabblerRsvpCtaState.notAllowed:
        (widget.onSwitchProfile ??
            () => context.push(RoutePaths.profileSwitcher))();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final card = ref.watch(meetupCardProvider(widget.meetupId));
    final back = widget.onBack ?? () => context.pop();
    return card.when(
      loading: () => DabblerDetailPage(
        header: DabblerDetailHeader(
          tile: DabblerDetailHeaderTile.amber,
          leading: _backButton(back),
          title: '',
        ),
        children: const <Widget>[
          DabblerSkeleton.rect(
            width: double.infinity,
            height: DabblerSizing.skeletonBlockHeight,
          ),
          DabblerSkeleton.rect(
            width: double.infinity,
            height: DabblerSizing.skeletonBlockHeight,
          ),
        ],
      ),
      error: (_, __) => DabblerPage(
        topBar: DabblerNavigationTopBar.titled(onBack: back),
        body: DabblerEmptyState.error(
          title: l.meetups_load_detail_failed,
          retryLabel: l.feed_retry,
          onRetry: () => ref.invalidate(meetupCardProvider(widget.meetupId)),
        ),
      ),
      data: (c) => _content(context, l, c, back),
    );
  }

  String? _sportName(MeetupCard c) {
    final ar = c.sportNameAr?.trim();
    if (Localizations.localeOf(context).languageCode == 'ar' &&
        ar != null &&
        ar.isNotEmpty) {
      return ar;
    }
    return c.sportNameEn;
  }

  /// The first two names, then how many others — `Lina, Yousef and 22 others`.
  String _names(AppLocalizations l, List<MeetupAvatar> going, int total) {
    String first(MeetupAvatar a) =>
        context.isolate((a.displayName ?? '').split(' ').first);
    final named = going.take(2).map(first).where((n) => n.isNotEmpty).toList();
    final others = total - named.length;
    if (others <= 0) return named.join(', ');
    return l.meetups_names_and_others(named.join(', '), others);
  }

  Future<void> _share(MeetupCard c) {
    final l = AppLocalizations.of(context);
    final headline = l.meetups_share_headline(context.isolate(c.title ?? ''));
    return ref.read(meetupShareProvider)(
      RoutePaths.meetupLink(c.id),
      // The brand token is Latin inside an Arabic sentence: isolate it so the
      // trailing '!' resolves to the RTL run. LTR output is untouched.
      context.isolateTrailing(headline, 'Dabbler'),
    );
  }

  /// The overflow menu: Report. A host does not report their own meetup.
  void _openMore(MeetupCard c) {
    final l = AppLocalizations.of(context);
    showDabblerSheet<void>(
      context: context,
      detent: DabblerSheetDetent.content,
      title: l.meetups_more,
      builder: (ctx) => DabblerActionRow(
        icon: 'danger',
        label: l.meetups_report,
        note: l.meetups_report_note,
        destructive: true,
        onTap: () {
          Navigator.of(ctx).pop();
          showReportDialog(
            context,
            targetType: ReportTargetType.meetup,
            targetId: c.id,
          );
        },
      ),
    );
  }

  Widget _backButton(VoidCallback back) => DabblerOnColorIconButton(
    onTile: true,
    icon: 'arrow-circle-left',
    mirrorInRtl: true,
    semanticLabel: AppLocalizations.of(context).meetups_back,
    onPressed: back,
  );

  Widget _content(
    BuildContext context,
    AppLocalizations l,
    MeetupCard c,
    VoidCallback back,
  ) {
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final at = c.startAt;
    final end = c.endAt;
    final elig = ref.watch(meetupRsvpEligibilityProvider(widget.meetupId));
    final attendees =
        ref.watch(meetupAttendeesProvider(widget.meetupId)).valueOrNull ??
        const <MeetupAttendee>[];
    final faces = c.attendees.isNotEmpty
        ? c.attendees
        : <MeetupAvatar>[
            for (final a in attendees)
              if (a.status == RsvpStatus.going)
                MeetupAvatar(displayName: a.displayName ?? a.username),
          ];
    final shown = faces.take(maxFaces).toList();
    final state = c.isCancelled
        ? DabblerRsvpCtaState.cancelled
        : elig.valueOrNull == null
        ? DabblerRsvpCtaState.join
        : rsvpStateFromEligibility(
            cta: elig.value!.cta,
            myStatus: c.myStatus,
            capacity: c.capacity,
            going: c.counts.going,
          );
    final loadingCta = !c.isCancelled && elig.valueOrNull == null;
    final hostName = c.host?.displayName ?? c.host?.username;
    final distance = ref.watch(meetupDistancesProvider)[c.id];
    // The vibe tag comes from the list row (`v_meetup_list.vibe_key`); a deep
    // link with no cached row simply has none.
    final vibeKey = ref
        .watch(meetupListProvider(null))
        .valueOrNull
        ?.where((m) => m.id == c.id)
        .map((m) => m.vibeKey)
        .firstOrNull;
    final vibeLabel = vibeKey == null
        ? null
        : DabblerVibe.fromKey(vibeKey)?.label;
    final tier = gamesSkillTierFor(c.minSkill, c.maxSkill);
    final skillLabel = tier == null ? null : gamesSkillTierLabel(l, tier);
    Widget glyph(String n) => DabblerIcon(n, size: DabblerSizing.iconSm);
    return DabblerDetailPage(
      header: DabblerDetailHeader(
        tile: DabblerDetailHeaderTile.amber,
        leading: _backButton(back),
        actions: <Widget>[
          DabblerOnColorIconButton(
            onTile: true,
            icon: 'share',
            semanticLabel: l.meetups_share,
            onPressed: () => _share(c),
          ),
          if (!c.isHost)
            DabblerOnColorIconButton(
              onTile: true,
              icon: 'more',
              semanticLabel: l.meetups_more,
              onPressed: () => _openMore(c),
            ),
        ],
        chips: <String>[
          if (c.isCancelled) l.meetups_cta_cancelled,
          ?_sportName(c),
          ?skillLabel,
          ?vibeLabel,
        ],
        title: c.title ?? '',
        place: c.locationName,
        meta: distance == null
            ? null
            : l.meetups_km_away((distance / 1000).toStringAsFixed(1)),
        extra: at == null
            ? null
            : '${meetupDayLabel(l, at, now, locale)} ${DateFormat.jm(locale).format(at)}',
      ),
      bottomBar: DabblerActionBar(
        price: l.listing_free,
        caption: l.meetups_free_note,
        primary: DabblerRsvpCta(
          state: state,
          label: rsvpLabel(l, state),
          loading: _busy || loadingCta,
          onPressed: () => _press(state, c),
        ),
      ),
      children: <Widget>[
        DabblerHeadcount(
          avatars: shown.isEmpty
              ? null
              : DabblerAvatarGroup(
                  people: <String>[
                    for (final a in shown) a.displayName ?? a.avatarUrl ?? '',
                  ],
                  imageUrls: <String?>[for (final a in shown) a.avatarUrl],
                  overflow: c.counts.going > shown.length
                      ? c.counts.going - shown.length
                      : 0,
                ),
          headline: l.meetups_going_count(c.counts.going),
          caption: <String>[
            if (c.capacity != null) l.meetups_max(c.capacity!),
            if (faces.isNotEmpty) _names(l, faces, c.counts.going),
          ].join(' · '),
        ),
        DabblerStatGrid(
          rowExtent: DabblerStatGrid.detailsRowHeight,
          children: <DabblerStatTile>[
            if (at != null)
              DabblerStatTile(
                size: DabblerStatTileSize.detail,
                tone: DabblerStatTileTone.accent,
                icon: glyph('clock'),
                value: end == null
                    ? DateFormat.jm(locale).format(at)
                    : '${end.difference(at).inMinutes} ${l.listing_unit_min}',
                label: end == null
                    ? DateFormat.yMMMEd(locale).format(at)
                    : '${DateFormat.jm(locale).format(at)} – ${DateFormat.jm(locale).format(end)}',
                fitValue: true,
              ),
            DabblerStatTile(
              size: DabblerStatTileSize.detail,
              tone: DabblerStatTileTone.ink,
              icon: glyph('ticket-2'),
              value: l.listing_free,
              label: l.meetups_tile_entry,
              fitValue: true,
            ),
            if (c.locationName != null)
              DabblerStatTile(
                size: DabblerStatTileSize.detail,
                tone: DabblerStatTileTone.amber,
                icon: glyph('location'),
                value: c.locationName!,
                label: l.meetups_tile_meeting_point,
                span: 6,
                fitValue: true,
              ),
          ],
        ),
        if (hostName != null) _HostSection(host: c.host!, name: hostName),
        if (c.isHost)
          DabblerActionRow(
            icon: 'setting-2',
            label: l.meetups_manage,
            onTap: () => context.push(RoutePaths.meetupManage(c.id)),
          ),
      ],
    );
  }
}

/// The host card with its Follow pill, wired like the profile screen: the
/// follow state is `isFollowingProvider` and the press is the same insert or
/// unfollow RPC ([meetupFollowActionProvider]). No pill for the viewer's own
/// meetup or while the viewer's profile is unknown.
class _HostSection extends ConsumerWidget {
  const _HostSection({required this.host, required this.name});

  final MeetupHost host;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hostId = host.actorProfileId;
    final myId = ref.watch(myProfileIdProvider).valueOrNull;
    final canFollow = hostId != null && myId != null && hostId != myId;
    final following = canFollow
        ? ref
              .watch(
                isFollowingProvider((
                  currentProfileId: myId,
                  targetProfileId: hostId,
                )),
              )
              .valueOrNull
        : null;
    return DabblerHostCard(
      name: name,
      imageUrl: host.avatarUrl,
      caption: l.meetups_host_caption,
      actionLabel: !canFollow || following == null
          ? null
          : (following
                ? l.user_profile_btn_following
                : l.user_profile_btn_follow),
      onAction: !canFollow || following == null
          ? null
          : () => ref.read(meetupFollowActionProvider)(
              myProfileId: myId,
              targetProfileId: hostId,
              currentlyFollowing: following,
            ),
    );
  }
}
