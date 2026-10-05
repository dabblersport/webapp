import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_user_lookup.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_error_text.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Host-only management of a meetup: who is going, interested or waiting, an
/// Approve / Decline pair on each request, Remove on each response, then Edit
/// and Cancel. No frame draws it, so it is composed from design-system parts.
///
/// The screen trusts nothing: every action is a server call that checks the
/// host (`not_host`), and the entry on Details shows only when the card says
/// `is_host`.
class MeetupManageScreen extends ConsumerStatefulWidget {
  const MeetupManageScreen({
    super.key,
    required this.meetupId,
    this.onBack,
    this.onEdit,
    this.onCancelled,
  });

  final String meetupId;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onCancelled;

  @override
  ConsumerState<MeetupManageScreen> createState() => _MeetupManageScreenState();
}

class _MeetupManageScreenState extends ConsumerState<MeetupManageScreen> {
  bool _busy = false;

  void _toast(String message) => DabblerToastProvider.maybeOf(
    context,
  )?.show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));

  Future<void> _decide(MeetupAttendee a, MeetupDecision d) async {
    await _run((l) async {
      final uid = await _userId(a);
      if (uid == null) return l.meetups_action_failed;
      final r = await ref
          .read(meetupActionsProvider)
          .decideRequest(widget.meetupId, uid, d);
      return r.fold(
        (f) => meetupErrorText(l, f, l.meetups_action_failed),
        (_) => null,
      );
    });
  }

  Future<void> _remove(MeetupAttendee a) async {
    final l = AppLocalizations.of(context);
    final name = a.displayName ?? a.username ?? '';
    final ok = await showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => DabblerDialog(
        title: l.meetups_remove_title(context.isolate(name)),
        description: l.meetups_remove_body,
        destructive: true,
        onClose: () => Navigator.pop(ctx, false),
        secondaryAction: DabblerDialogAction(
          label: l.composer_cancel,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: l.meetups_remove,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _run((l) async {
      final uid = await _userId(a);
      if (uid == null) return l.meetups_action_failed;
      final r = await ref
          .read(meetupActionsProvider)
          .removeAttendee(widget.meetupId, uid);
      return r.fold(
        (f) => meetupErrorText(l, f, l.meetups_action_failed),
        (_) => null,
      );
    });
  }

  Future<void> _cancelMeetup() async {
    final l = AppLocalizations.of(context);
    final ok = await showDabblerDialog<bool>(
      context: context,
      builder: (ctx) => DabblerDialog(
        title: l.meetups_cancel_title,
        description: l.meetups_cancel_body,
        destructive: true,
        onClose: () => Navigator.pop(ctx, false),
        secondaryAction: DabblerDialogAction(
          label: l.meetups_keep,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        primaryAction: DabblerDialogAction(
          label: l.meetups_cancel_confirm,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _run((l) async {
      final r = await ref.read(meetupActionsProvider).cancel(widget.meetupId);
      return r.fold((f) => meetupErrorText(l, f, l.meetups_action_failed), (_) {
        (widget.onCancelled ?? () => context.pop())();
        return null;
      });
    });
  }

  Future<String?> _userId(MeetupAttendee a) async {
    final pid = a.actorProfileId;
    if (a.userId != null) return a.userId;
    if (pid == null) return null;
    return ref.read(meetupUserIdLookupProvider)(pid);
  }

  /// Runs [body]; a returned string is an error toast.
  Future<void> _run(Future<String?> Function(AppLocalizations l) body) async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final err = await body(l);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) _toast(err);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final back = widget.onBack ?? () => context.pop();
    final attendees = ref.watch(meetupAttendeesProvider(widget.meetupId));
    Widget row(MeetupAttendee a, List<Widget> actions) => DabblerListRow(
      leading: DabblerAvatar(
        seed: a.displayName ?? a.username ?? a.actorProfileId ?? '',
        size: DabblerAvatarSize.sm,
      ),
      title: a.displayName ?? a.username ?? '',
      subtitle: a.displayName != null ? a.username : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DabblerSpacing.space2,
        children: actions,
      ),
    );
    Widget section(String title, List<MeetupAttendee> list, bool request) {
      if (list.isEmpty) return const SizedBox.shrink();
      return DabblerSection(
        title: title,
        subtitle: '${list.length}',
        children: <Widget>[
          DabblerListGroup(
            children: <Widget>[
              for (final a in list)
                row(a, <Widget>[
                  if (request) ...<Widget>[
                    DabblerButton(
                      label: l.meetups_approve,
                      size: DabblerButtonSize.small,
                      disabled: _busy,
                      onPressed: () => _decide(a, MeetupDecision.approve),
                    ),
                    DabblerButton(
                      label: l.meetups_decline,
                      size: DabblerButtonSize.small,
                      tone: DabblerButtonTone.neutral,
                      disabled: _busy,
                      onPressed: () => _decide(a, MeetupDecision.decline),
                    ),
                  ] else
                    DabblerButton(
                      label: l.meetups_remove,
                      size: DabblerButtonSize.small,
                      tone: DabblerButtonTone.destructive,
                      disabled: _busy,
                      onPressed: () => _remove(a),
                    ),
                ]),
            ],
          ),
        ],
      );
    }

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: l.meetups_manage_title,
        onBack: back,
      ),
      body: attendees.when(
        loading: () => const Center(child: DabblerSpinner()),
        error: (_, __) => Center(
          child: DabblerEmptyState.error(
            title: l.meetups_load_detail_failed,
            retryLabel: l.feed_retry,
            onRetry: () =>
                ref.invalidate(meetupAttendeesProvider(widget.meetupId)),
          ),
        ),
        data: (all) {
          List<MeetupAttendee> by(RsvpStatus s) => <MeetupAttendee>[
            for (final a in all)
              if (a.status == s) a,
          ];
          final pending = by(RsvpStatus.pending);
          final going = by(RsvpStatus.going);
          final interested = by(RsvpStatus.interested);
          return ListView(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: DabblerSpacing.space6,
              vertical: DabblerSpacing.space4,
            ),
            children: <Widget>[
              if (pending.isEmpty && going.isEmpty && interested.isEmpty)
                DabblerEmptyState(
                  icon: 'people',
                  title: l.meetups_manage_empty,
                ),
              section(l.meetups_section_pending, pending, true),
              section(l.meetups_section_going, going, false),
              section(l.meetups_section_interested, interested, false),
              const DabblerGap.v(DabblerSpacing.space6),
              DabblerButton(
                label: l.meetups_edit,
                icon: 'edit',
                tone: DabblerButtonTone.outlined,
                fullWidth: true,
                disabled: _busy,
                onPressed:
                    widget.onEdit ??
                    () => context.push(RoutePaths.meetupEdit(widget.meetupId)),
              ),
              const DabblerGap.v(DabblerSpacing.space3),
              DabblerButton(
                label: l.meetups_cancel_meetup,
                tone: DabblerButtonTone.destructive,
                fullWidth: true,
                disabled: _busy,
                onPressed: _cancelMeetup,
              ),
            ],
          );
        },
      ),
    );
  }
}
