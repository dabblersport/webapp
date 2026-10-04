import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
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

  /// The first two names, then how many others — `Lina, Yousef and 22 others`.
  String _names(AppLocalizations l, List<MeetupAttendee> going, int total) {
    String first(MeetupAttendee a) =>
        (a.displayName ?? a.username ?? '').split(' ').first;
    final named = going.take(2).map(first).where((n) => n.isNotEmpty).toList();
    final others = total - named.length;
    if (others <= 0) return named.join(', ');
    return l.meetups_names_and_others(named.join(', '), others);
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
    final going = <MeetupAttendee>[
      for (final a in attendees)
        if (a.status == RsvpStatus.going) a,
    ];
    final shown = going.take(5).toList();
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
    String seed(MeetupAttendee a) =>
        a.displayName ?? a.username ?? a.actorProfileId ?? '';
    final hostName = c.host?.displayName ?? c.host?.username;
    Widget glyph(String n) => DabblerIcon(n, size: DabblerSizing.iconSm);
    return DabblerDetailPage(
      header: DabblerDetailHeader(
        tile: DabblerDetailHeaderTile.amber,
        leading: _backButton(back),
        chips: <String>[if (c.isCancelled) l.meetups_cta_cancelled],
        title: c.title ?? '',
        place: c.locationName,
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
                  people: <String>[for (final a in shown) seed(a)],
                  overflow: going.length > shown.length
                      ? going.length - shown.length
                      : 0,
                ),
          headline: l.meetups_going_count(c.counts.going),
          caption: <String>[
            if (c.capacity != null) l.meetups_max(c.capacity!),
            if (going.isNotEmpty) _names(l, going, c.counts.going),
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
        if (hostName != null)
          DabblerHostCard(name: hostName, caption: l.meetups_host_caption),
      ],
    );
  }
}
