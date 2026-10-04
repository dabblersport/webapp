import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_inputs.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_error_text.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_pickers.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Edit a meetup (host only): title, description, when, location, capacity.
/// It is the create drawer's content, prefilled, and sends only what changed
/// to `rpc_meetup_update` (a null leaves the field as it is; the RPC cannot
/// clear a description, end time or capacity). The server refuses a capacity
/// below the going count (`capacity_below_going_count`) and shows here.
class MeetupEditScreen extends ConsumerStatefulWidget {
  const MeetupEditScreen({super.key, required this.meetupId, this.onDone});

  final String meetupId;

  /// Called after a successful save; defaults to popping.
  final VoidCallback? onDone;

  @override
  ConsumerState<MeetupEditScreen> createState() => _MeetupEditScreenState();
}

class _MeetupEditScreenState extends ConsumerState<MeetupEditScreen> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  MeetupCard? _card;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  ComposerPlacePick? _place;
  int _capacity = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _seed(MeetupCard c) {
    _card = c;
    _title.text = c.title ?? '';
    _note.text = c.description ?? '';
    final s = c.startAt?.toLocal();
    final e = c.endAt?.toLocal();
    if (s != null) {
      _date = DateTime(s.year, s.month, s.day);
      _start = TimeOfDay(hour: s.hour, minute: s.minute);
    }
    if (e != null) _end = TimeOfDay(hour: e.hour, minute: e.minute);
    if (c.locationName != null) {
      _place = ComposerPlacePick(name: c.locationName!);
    }
    _capacity = c.capacity ?? 0;
  }

  DateTime _at(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<void> _save() async {
    final c = _card!;
    final l = AppLocalizations.of(context);
    final title = _title.text.trim();
    final note = _note.text.trim();
    final start = _date != null && _start != null ? _at(_date!, _start!) : null;
    final end = _date != null && _end != null ? _at(_date!, _end!) : null;
    final input = UpdateMeetupInput(
      meetupId: widget.meetupId,
      title: title.isNotEmpty && title != c.title ? title : null,
      description: note.isNotEmpty && note != (c.description ?? '')
          ? note
          : null,
      startAt: start != null && start != c.startAt?.toLocal() ? start : null,
      endAt: end != null && end != c.endAt?.toLocal() ? end : null,
      locationName: _place != null && _place!.name != c.locationName
          ? _place!.name
          : null,
      capacity: _capacity > 0 && _capacity != c.capacity ? _capacity : null,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(meetupActionsProvider).update(input);
    if (!mounted) return;
    r.fold(
      (f) => setState(() {
        _busy = false;
        _error = meetupErrorText(l, f, l.meetups_save_failed);
      }),
      (_) {
        setState(() => _busy = false);
        (widget.onDone ?? () => context.pop())();
      },
    );
  }

  String _dateLabel(AppLocalizations l, DateTime? d) {
    if (d == null) return l.game_date;
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return l.game_today;
    }
    return DateFormat('MMM d').format(d);
  }

  String _timeLabel(String empty, TimeOfDay? t) =>
      t == null ? empty : DabblerTimeFormat.format(t);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final card = ref.watch(meetupCardProvider(widget.meetupId));
    return card.when(
      loading: () => const Center(child: DabblerSpinner()),
      error: (_, __) => Center(
        child: DabblerEmptyState.error(
          title: l.meetups_load_detail_failed,
          retryLabel: l.feed_retry,
          onRetry: () => ref.invalidate(meetupCardProvider(widget.meetupId)),
        ),
      ),
      data: (c) {
        if (_card == null) _seed(c);
        const gutter = EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space8,
        );
        return ComposerDrawerShell(
          title: l.meetups_edit,
          ctaLabel: l.meetups_save,
          canSubmit: _title.text.trim().length >= 3 && _place != null,
          isSubmitting: _busy,
          onCtaTap: _save,
          errorMessage: _error,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: DabblerSpacing.space8,
                vertical: DabblerSpacing.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DabblerSpacing.space3,
                children: <Widget>[
                  ComposerSectionLabel(label: l.meetups_create_name_section),
                  ComposerGlassInput(
                    controller: _title,
                    hint: l.meetups_create_title_hint,
                    onChanged: (_) => setState(() {}),
                  ),
                  ComposerGlassInput(
                    controller: _note,
                    hint: l.meetups_create_note_hint,
                    minLines: 3,
                    maxLines: 6,
                  ),
                ],
              ),
            ),
            Padding(
              padding: gutter,
              child: ComposerSettingsRow(
                icon: 'calendar',
                title: l.meetups_when,
                subtitle: l.meetups_when_sub,
                trailing: Wrap(
                  spacing: DabblerSpacing.space2,
                  children: <Widget>[
                    ComposerCompactSelectPill(
                      value: _dateLabel(l, _date),
                      onTap: () async {
                        final d = await pickMeetupDate(context, _date);
                        if (d != null && mounted) setState(() => _date = d);
                      },
                    ),
                    ComposerCompactSelectPill(
                      value: _timeLabel(l.game_time, _start),
                      onTap: () async {
                        final t = await pickMeetupTime(context, _start);
                        if (t != null && mounted) setState(() => _start = t);
                      },
                    ),
                    ComposerCompactSelectPill(
                      value: _timeLabel(l.meetups_end, _end),
                      onTap: () async {
                        final t = await pickMeetupTime(context, _end);
                        if (t != null && mounted) setState(() => _end = t);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: gutter,
              child: ComposerSettingsRow(
                icon: 'location',
                title: l.meetups_location,
                subtitle: l.meetups_location_sub,
                trailing: ComposerSelectPill(
                  value: _place?.name ?? l.composer_select,
                  caret: ComposerSelectCaret.right,
                  onTap: () async {
                    final p = await pickMeetupPlace(context, _place);
                    if (p != null && mounted) setState(() => _place = p);
                  },
                ),
              ),
            ),
            Padding(
              padding: gutter,
              child: ComposerSettingsRow(
                icon: 'people',
                title: l.meetups_capacity,
                subtitle: l.meetups_capacity_sub,
                showDivider: false,
                trailing: DabblerStepperPill(
                  value: _capacity,
                  min: 0,
                  decreaseLabel: l.game_fewer_max,
                  increaseLabel: l.game_more_max,
                  onChanged: (v) => setState(() => _capacity = v),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
