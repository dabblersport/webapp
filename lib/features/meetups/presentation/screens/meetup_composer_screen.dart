import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/games/presentation/screens/game_composer_screen.dart'
    show ComposerDateSheet, ComposerTimeSheet;
import 'package:dabbler/features/meetups/domain/models/meetup_inputs.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// The Create meet-up drawer, drawn from `Home Feed.dc.html:1132-1280`: sport
/// tiles, title and description, When (date, start, End), Location, Capacity,
/// and Advanced options (How people join, Skill range, Vibe).
///
/// v1 is public and free: the frame's "Who can see it", "Members only" and
/// "Cost" rows are not drawn (the RPC rejects any other value, see
/// `visibility_not_supported` / `free_meetups_only`).
class MeetupComposerScreen extends ConsumerStatefulWidget {
  const MeetupComposerScreen({
    super.key,
    this.onCreated,
    this.initialDate,
    this.initialStart,
    this.initialPlace,
  });

  /// Pre-fills for tests and deep links.
  final DateTime? initialDate;
  final TimeOfDay? initialStart;
  final ComposerPlacePick? initialPlace;

  /// Called with the new id; defaults to opening the new Details.
  final ValueChanged<String>? onCreated;

  @override
  ConsumerState<MeetupComposerScreen> createState() =>
      _MeetupComposerScreenState();
}

class _MeetupComposerScreenState extends ConsumerState<MeetupComposerScreen> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  MeetupSport? _sport;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  ComposerPlacePick? _place;
  int _capacity = 0; // 0 = no limit
  String _policy = 'open';
  int? _minSkill;
  int? _maxSkill;
  DabblerVibe? _vibe;
  bool _more = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _start = widget.initialStart;
    _place = widget.initialPlace;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _sport != null &&
      _title.text.trim().length >= 3 &&
      _place != null &&
      _date != null &&
      _start != null;

  DateTime _at(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  String _message(AppLocalizations l, Failure f) => switch (f.code) {
    'organiser_required' => l.meetups_err_organiser_required,
    'title_invalid' => l.meetups_err_title_invalid,
    'invalid_time_range' => l.meetups_err_invalid_time_range,
    'invalid_capacity' => l.meetups_err_invalid_capacity,
    'auth_required' => l.meetups_err_auth_required,
    'free_meetups_only' ||
    'visibility_not_supported' => l.meetups_err_unsupported,
    _ => l.meetups_create_failed,
  };

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final sport = _sport!;
    final variants = await ref
        .read(meetupSportVariantsProvider(sport.id).future)
        .catchError((_) => const <MeetupSportVariant>[]);
    if (variants.isEmpty) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.meetups_create_failed;
        });
      }
      return;
    }
    final place = _place!;
    final start = _at(_date!, _start!);
    final result = await ref
        .read(meetupActionsProvider)
        .create(
          CreateMeetupInput(
            sportId: sport.id,
            sportVariantId: variants.first.id,
            title: _title.text.trim(),
            description: _note.text.trim().isEmpty ? null : _note.text.trim(),
            locationName: place.name,
            venueId: place.venueId,
            startAt: start,
            endAt: _end == null ? null : _at(_date!, _end!),
            capacity: _capacity > 0 ? _capacity : null,
            rsvpPolicy: _policy,
            minSkill: _minSkill,
            maxSkill: _maxSkill,
            vibeKey: _vibe?.key,
          ),
        );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _busy = false;
        _error = _message(l, f);
      }),
      (id) {
        setState(() => _busy = false);
        final done = widget.onCreated;
        if (done != null) {
          done(id);
        } else {
          context.pushReplacement(RoutePaths.meetupDetail(id));
        }
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

  Future<void> _pickDate() async {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final pending = ValueNotifier<DateTime?>(_date);
    await showComposerSheet<void>(
      context,
      title: l.composer_pick_date,
      confirm: ComposerSheetConfirm(
        label: l.composer_confirm,
        onTap: () {
          if (pending.value != null) setState(() => _date = pending.value);
          Navigator.of(context).maybePop();
        },
      ),
      builder: (_) => ComposerDateSheet(
        first: now,
        last: DateTime(now.year + 1, now.month, now.day),
        pending: pending,
      ),
    );
  }

  Future<void> _pickTime({required bool end}) async {
    final l = AppLocalizations.of(context);
    final pending = ValueNotifier<TimeOfDay>(
      (end ? _end : _start) ?? const TimeOfDay(hour: 18, minute: 0),
    );
    await showComposerSheet<void>(
      context,
      title: l.composer_pick_time,
      confirm: ComposerSheetConfirm(
        label: l.composer_confirm,
        onTap: () {
          setState(() => end ? _end = pending.value : _start = pending.value);
          Navigator.of(context).maybePop();
        },
      ),
      builder: (_) => ComposerTimeSheet(pending: pending),
    );
  }

  Future<void> _pickSkill() => showComposerSheet<void>(
    context,
    title: AppLocalizations.of(context).meetups_skill,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_minSkill != null)
          ComposerClearRow(
            onClear: () {
              setState(() {
                _minSkill = null;
                _maxSkill = null;
              });
              Navigator.pop(ctx);
            },
          ),
        for (final t in const <(String, int, int)>[
          ('Beginner', 1, 3),
          ('Intermediate', 4, 6),
          ('Advanced', 7, 8),
          ('Pro', 9, 10),
        ])
          ComposerPickerRow(
            title: t.$1,
            trailingText: '${t.$2}–${t.$3}',
            selected: _minSkill == t.$2,
            onTap: () {
              setState(() {
                _minSkill = t.$2;
                _maxSkill = t.$3;
              });
              Navigator.pop(ctx);
            },
          ),
      ],
    ),
  );

  Future<void> _pickVibe() => showComposerSheet<void>(
    context,
    title: AppLocalizations.of(context).meetups_vibe,
    tall: true,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_vibe != null)
          ComposerClearRow(
            onClear: () {
              setState(() => _vibe = null);
              Navigator.pop(ctx);
            },
          ),
        for (final v in DabblerVibe.values)
          ComposerPickerRow(
            title: v.label,
            selected: _vibe == v,
            onTap: () {
              setState(() => _vibe = v);
              Navigator.pop(ctx);
            },
          ),
      ],
    ),
  );

  void _pickPlace() {
    final l = AppLocalizations.of(context);
    final pending = ValueNotifier<ComposerPlacePick?>(_place);
    showComposerSheet<void>(
      context,
      title: l.composer_add_location,
      onClear: () => setState(() => _place = null),
      confirm: ComposerSheetConfirm(
        label: l.composer_confirm,
        onTap: () {
          if (pending.value != null) setState(() => _place = pending.value);
          Navigator.of(context).maybePop();
        },
      ),
      builder: (_) => ComposerPlaceSheet(pending: pending),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sports = ref.watch(meetupSportsProvider);
    const gutter = EdgeInsetsDirectional.symmetric(
      horizontal: DabblerSpacing.space8,
    );
    const block = EdgeInsetsDirectional.symmetric(
      horizontal: DabblerSpacing.space8,
      vertical: DabblerSpacing.space4,
    );
    final colors = DabblerColors.of(context);
    return ComposerDrawerShell(
      title: l.meetups_create_title,
      ctaLabel: l.meetups_create_title,
      canSubmit: _canSubmit,
      isSubmitting: _busy,
      onCtaTap: _submit,
      errorMessage: _error,
      children: <Widget>[
        Padding(
          padding: block,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DabblerSpacing.space3,
            children: <Widget>[
              ComposerSectionLabel(label: l.game_sport),
              sports.when(
                loading: () => const SizedBox(
                  height: DabblerSizing.touchTargetMin,
                  child: Center(
                    child: DabblerSpinner(size: DabblerSpinnerSize.sm),
                  ),
                ),
                error: (_, __) => DabblerText(
                  l.composer_sports_none,
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
                data: (list) => Wrap(
                  spacing: DabblerSpacing.space3,
                  runSpacing: DabblerSpacing.space3,
                  children: <Widget>[
                    for (final s in list)
                      DabblerSelectableCard(
                        layout: DabblerSelectableCardLayout.tile,
                        title: s.nameEn,
                        leading: DabblerSportIcon.fromKey(
                          (s.sportKey ?? '').replaceAll('_', '-'),
                          size: DabblerSizing.iconLg,
                          color: colors.textPrimary,
                        ),
                        selected: _sport?.id == s.id,
                        onChanged: (_) => setState(() => _sport = s),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const DabblerDivider(),
        Padding(
          padding: block,
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
                  onTap: _pickDate,
                ),
                ComposerCompactSelectPill(
                  value: _timeLabel(l.game_time, _start),
                  onTap: () => _pickTime(end: false),
                ),
                ComposerCompactSelectPill(
                  value: _timeLabel(l.meetups_end, _end),
                  onTap: () => _pickTime(end: true),
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
              onTap: _pickPlace,
            ),
          ),
        ),
        Padding(
          padding: gutter,
          child: ComposerSettingsRow(
            icon: 'people',
            title: l.meetups_capacity,
            subtitle: l.meetups_capacity_sub,
            trailing: DabblerStepperPill(
              value: _capacity,
              min: 0,
              decreaseLabel: l.game_fewer_max,
              increaseLabel: l.game_more_max,
              onChanged: (v) => setState(() => _capacity = v),
            ),
          ),
        ),
        Padding(
          padding: gutter,
          child: ComposerSettingsRow(
            icon: _more ? 'arrow-circle-up' : 'arrow-circle-down',
            title: l.meetups_advanced,
            onTap: () => setState(() => _more = !_more),
          ),
        ),
        if (_more) ...<Widget>[
          Padding(
            padding: block,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DabblerSpacing.space3,
              children: <Widget>[
                ComposerSectionLabel(label: l.meetups_policy),
                Wrap(
                  spacing: DabblerSpacing.space3,
                  runSpacing: DabblerSpacing.space3,
                  children: <Widget>[
                    for (final e in <(String, String)>[
                      ('open', l.game_join_open),
                      ('request', l.game_join_request),
                      ('closed', l.meetups_policy_closed),
                    ])
                      ComposerPolicyChip(
                        label: e.$2,
                        selected: _policy == e.$1,
                        onTap: () => setState(() => _policy = e.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: gutter,
            child: ComposerSettingsRow(
              icon: 'medal-star',
              title: l.meetups_skill,
              subtitle: l.meetups_skill_sub,
              trailing: ComposerSelectPill(
                value: _minSkill == null
                    ? l.meetups_skill_any
                    : '$_minSkill–$_maxSkill',
                caret: ComposerSelectCaret.down,
                onTap: _pickSkill,
              ),
            ),
          ),
          Padding(
            padding: gutter,
            child: ComposerSettingsRow(
              icon: 'emoji-happy',
              title: l.meetups_vibe,
              subtitle: l.meetups_vibe_sub,
              showDivider: false,
              trailing: ComposerSelectPill(
                value: _vibe?.label ?? l.meetups_vibe_choose,
                caret: ComposerSelectCaret.down,
                onTap: _pickVibe,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
