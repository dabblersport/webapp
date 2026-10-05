import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_inputs.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_error_text.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_pickers.dart';
import 'package:dabbler/features/meetups/presentation/widgets/meetup_when_row.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opens the Create meet-up drawer as a design-system bottom sheet, like the
/// frame (`Home Feed.dc.html:1134`, a 94% sheet on the page colour): the title
/// row with Cancel, the scrolling form and the sticky Create button are the
/// composer shell's. On success it closes and opens the new Details.
Future<void> showMeetupComposerSheet(
  BuildContext context, {
  ValueChanged<String>? onCreated,
  ComposerPlacePick? initialPlace,
}) {
  final router = GoRouter.maybeOf(context);
  return showDabblerSheet<void>(
    context: context,
    detent: DabblerSheetDetent.fractions,
    detents: const <double>[0.94],
    pageBackground: true,
    showCloseButton: false,
    // The shell draws the title row (with Cancel) and the sticky footer; the
    // sheet's own header carries only the grab handle and the route's name.
    title: AppLocalizations.of(context).meetups_create_title,
    titleWidget: const SizedBox.shrink(),
    builder: (sheetContext) => MeetupComposerScreen(
      initialPlace: initialPlace,
      onCreated: (id) {
        Navigator.of(sheetContext).maybePop();
        if (onCreated != null) {
          onCreated(id);
        } else {
          router?.push(RoutePaths.meetupDetail(id));
        }
      },
    ),
  );
}

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
  int _capacity = 8; // the frame's default; 0 = no limit (sent as null)
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
    // The frame opens on Today at 6:00 AM; when that moment has passed, the
    // next sensible start is tomorrow at 6:00 AM.
    final now = DateTime.now();
    const sixAm = TimeOfDay(hour: 6, minute: 0);
    final todaySix = DateTime(now.year, now.month, now.day, 6);
    _date =
        widget.initialDate ??
        (todaySix.isAfter(now)
            ? DateTime(now.year, now.month, now.day)
            : DateTime(now.year, now.month, now.day + 1));
    _start = widget.initialStart ?? sixAm;
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
        _error = meetupErrorText(l, f, l.meetups_create_failed);
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

  Future<void> _pickDate() async {
    final d = await pickMeetupDate(context, _date);
    if (d != null && mounted) setState(() => _date = d);
  }

  Future<void> _pickTime({required bool end}) async {
    final t = await pickMeetupTime(context, end ? _end : _start);
    if (t != null && mounted) {
      setState(() => end ? _end = t : _start = t);
    }
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

  Future<void> _pickPlace() async {
    final p = await pickMeetupPlace(context, _place);
    if (p != null && mounted) setState(() => _place = p);
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
                data: (list) {
                  _sport ??= list.isEmpty ? null : list.first;
                  return DabblerTileGrid(
                    columns: 4,
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
                  );
                },
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
          child: MeetupWhenRow(
            date: _date,
            start: _start,
            end: _end,
            onDate: _pickDate,
            onStart: () => _pickTime(end: false),
            onEnd: () => _pickTime(end: true),
          ),
        ),
        Padding(
          padding: gutter,
          child: ComposerSettingsRow(
            icon: 'location',
            title: l.meetups_location,
            subtitle: _place?.name ?? l.meetups_location_sub,
            trailing: DabblerButton.icon(
              icon: 'map',
              semanticLabel: l.meetups_location,
              tone: DabblerButtonTone.text,
              onPressed: _pickPlace,
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
        // The frame's centred brand-ink link with a chevron-circle glyph
        // (`Home Feed.dc.html:1198`).
        Padding(
          padding: block,
          child: Center(
            child: DabblerTextLink(
              label: l.meetups_advanced,
              trailingIcon: _more ? 'arrow-circle-up' : 'arrow-circle-down',
              onPressed: () => setState(() => _more = !_more),
            ),
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
