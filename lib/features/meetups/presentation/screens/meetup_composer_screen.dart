import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_inputs.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
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
/// frame (`Home Feed.dc.html:1132-1281`, `sheetP94`: content-sized up to 94%,
/// on the page colour). The sheet's own header is the frame's sticky title row
/// (`:1136-1139`: the title in 22/28 display, a small neutral Cancel, `gap:12`,
/// `padding-bottom:12`); its body is the frame's scroller (`padding: 0 18px
/// 18px`), and the Create button scrolls with the form as it does in the
/// frame. On success it closes and opens the new Details.
Future<void> showMeetupComposerSheet(
  BuildContext context, {
  ValueChanged<String>? onCreated,
  ComposerPlacePick? initialPlace,
}) {
  final router = GoRouter.maybeOf(context);
  final l = AppLocalizations.of(context);
  // Reached directly (a deep link, a stale button): a persona that may not
  // create is refused with the generic message and the form never opens. The
  // Create menu already hides the tile; the server is still the authority.
  final persona = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(activePersonaProvider);
  if (!canCreateGameOrMeetup(persona)) {
    DabblerToastProvider.maybeOf(context)?.show(
      DabblerToastSpec(
        message: l.meetups_err_create_refused,
        tone: DabblerToastTone.error,
      ),
    );
    return Future<void>.value();
  }
  return showDabblerSheet<void>(
    context: context,
    // `max-height: 94%`, `height: auto` (`sheetP94`): as tall as the form,
    // up to the frame's cap.
    detent: DabblerSheetDetent.content,
    contentMaxFraction: DabblerSheet.contentMaxFractionFull,
    pageBackground: true,
    showCloseButton: false,
    title: l.meetups_create_title,
    titleWidget: DabblerText(l.meetups_create_title, style: DabblerType.title2),
    headerActionBuilder: (sheetContext) => DabblerButton(
      label: l.composer_cancel,
      tone: DabblerButtonTone.neutral,
      size: DabblerButtonSize.small,
      onPressed: () => Navigator.of(sheetContext).maybePop(),
    ),
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

/// The Create meet-up drawer, drawn from `Home Feed.dc.html:1141-1279`:
/// Sport tiles, title and description, When (date, start, End), Location,
/// Capacity, the Advanced options toggle (open by default, `meetupMore: true`)
/// over Who can see it, How people join, Skill range, Vibe and Cost, then the
/// Create button.
///
/// v1 is public and free (the RPC rejects anything else, see
/// `visibility_not_supported` / `free_meetups_only`): "Who can see it" and
/// "Cost" show their only value, Public and Free, and open nothing. The
/// frame's "Members only" toggle is not drawn: members-only meetups are
/// deferred and a switch that cannot be turned on would claim otherwise.
///
/// The Create button is live once a sport is chosen, as the frame's
/// `meetupCtaBg` is. A missing title or place is then named in place, above
/// the button, rather than by a dead button.
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

  /// Indoor (true) / Outdoor (false); asked, and required, only while the
  /// place is not a venue (a venue supplies its own setting).
  bool? _indoor;
  bool _settingMissing = false;
  bool _more = true; // the frame opens with Advanced options shown
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

  /// The frame's rule: the button is live once an activity is chosen
  /// (`meetupCtaBg`, `:3469`).
  bool get _canSubmit => _sport != null && !_busy;

  /// What still blocks the RPC, named in place; null when the form can go.
  String? _missing(AppLocalizations l) {
    if (_title.text.trim().length < 3) return l.meetups_err_title_invalid;
    if (_place == null) return l.meetups_err_location_required;
    if (_place!.venueId == null && _indoor == null) {
      return l.meetup_setting_required;
    }
    return null;
  }

  DateTime _at(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final missing = _missing(l);
    if (missing != null) {
      setState(() {
        _error = missing;
        _settingMissing = _place?.venueId == null && _indoor == null;
      });
      return;
    }
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
            isIndoor: place.venueId == null ? _indoor : null,
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
        MeetupSkillRows(
          minSkill: _minSkill,
          onPick: (min, max) {
            setState(() {
              _minSkill = min;
              _maxSkill = max;
            });
            Navigator.pop(ctx);
          },
        ),
      ],
    ),
  );

  // Content-sized, capped at the frame's vibes 82% (`Home Feed.dc.html:650`,
  // `sheetP82`).
  Future<void> _pickVibe() => showDabblerSheet<void>(
    context: context,
    title: AppLocalizations.of(context).meetups_vibe,
    titleWidget: composerSheetTitle(AppLocalizations.of(context).meetups_vibe),
    detent: DabblerSheetDetent.content,
    contentMaxFraction: DabblerSheet.contentMaxFractionTall,
    pageBackground: true,
    showCloseButton: false,
    headerActionBuilder: (ctx) => composerSheetHeaderActions(context, ctx),
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
    if (p != null && mounted) {
      setState(() {
        _place = p;
        _settingMissing = false;
      });
    }
  }

  Future<void> _pickPolicy() => showComposerSheet<void>(
    context,
    title: AppLocalizations.of(context).meetups_policy,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final e in _policies(AppLocalizations.of(context)))
          ComposerPickerRow(
            title: e.$2,
            selected: _policy == e.$1,
            onTap: () {
              setState(() => _policy = e.$1);
              Navigator.pop(ctx);
            },
          ),
      ],
    ),
  );

  /// RSVP modes v1 supports: open | request | closed.
  static List<(String, String)> _policies(AppLocalizations l) =>
      <(String, String)>[
        ('open', l.game_join_open),
        ('request', l.game_join_request),
        ('closed', l.meetups_policy_closed),
      ];

  String _sportName(MeetupSport s) =>
      Directionality.of(context) == TextDirection.rtl &&
          (s.nameAr ?? '').isNotEmpty
      ? s.nameAr!
      : s.nameEn;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sports = ref.watch(meetupSportsProvider);
    final policyLabel = _policies(
      l,
    ).firstWhere((e) => e.$1 == _policy, orElse: () => _policies(l).first).$2;
    // The frame's scroller: one column, `gap:12px`, under the sticky header
    // and 12 below it (the sheet's body supplies the 18 gutters and the 18
    // at the foot).
    return DabblerSheetBody(
      children: <Widget>[
        _SectionLabel(l.game_sport, first: true),
        sports.when(
          loading: () => const SizedBox(
            height: DabblerEmojiTile.side,
            child: Center(child: DabblerSpinner(size: DabblerSpinnerSize.sm)),
          ),
          error: (_, __) => DabblerBanner(
            tone: DabblerBannerTone.error,
            message: l.meetups_sports_failed,
          ),
          data: (list) {
            _sport ??= list.isEmpty ? null : list.first;
            if (list.isEmpty) {
              return DabblerText(
                l.composer_sports_none,
                style: DabblerType.footnote,
                tone: DabblerTextTone.secondary,
              );
            }
            return Wrap(
              spacing: DabblerSpacing.space3,
              runSpacing: DabblerSpacing.space3,
              children: <Widget>[
                for (final s in list)
                  DabblerEmojiTile(
                    emoji: s.emoji ?? '',
                    label: _sportName(s),
                    selected: _sport?.id == s.id,
                    onTap: () => setState(() => _sport = s),
                  ),
              ],
            );
          },
        ),
        _SectionLabel(l.meetups_create_name_section),
        DabblerComposerField(
          controller: _title,
          placeholder: l.meetups_create_title_hint,
          onChanged: (_) => setState(() {
            if (_error != null) _error = null;
          }),
        ),
        DabblerComposerField(
          controller: _note,
          placeholder: l.meetups_create_note_hint,
          multiline: true,
        ),
        DabblerComposerRow(
          icon: 'calendar',
          title: l.meetups_when,
          subtitle: l.meetups_when_sub,
          trailing: MeetupWhenPills(
            date: _date,
            start: _start,
            end: _end,
            onDate: _pickDate,
            onStart: () => _pickTime(end: false),
            onEnd: () => _pickTime(end: true),
          ),
        ),
        DabblerComposerRow(
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
        // No venue: the host says Indoor or Outdoor (CEO 2026-10-08); a venue
        // brings its own setting, so the row is not asked then.
        if (_place?.venueId == null)
          DabblerComposerRow(
            icon: 'sun-1',
            title: l.meetup_setting,
            subtitle: _settingMissing
                ? l.meetup_setting_required
                : l.meetup_setting_sub,
            trailing: Wrap(
              spacing: DabblerSpacing.space2,
              children: <Widget>[
                ComposerPolicyChip(
                  label: l.listing_indoor,
                  selected: _indoor == true,
                  onTap: () => setState(() {
                    _indoor = true;
                    _settingMissing = false;
                  }),
                ),
                ComposerPolicyChip(
                  label: l.listing_outdoor,
                  selected: _indoor == false,
                  onTap: () => setState(() {
                    _indoor = false;
                    _settingMissing = false;
                  }),
                ),
              ],
            ),
          ),
        DabblerComposerRow(
          icon: 'people',
          title: l.meetups_capacity,
          subtitle: l.meetups_capacity_sub,
          trailing: DabblerStepperPill(
            value: _capacity,
            min: 0,
            // 0 is "no limit": the frame's `spotsLabel` draws it as ∞.
            valueLabel: (v) => v > 0 ? '$v' : DabblerStepperPill.unlimited,
            decreaseLabel: l.game_fewer_max,
            increaseLabel: l.game_more_max,
            onChanged: (v) => setState(() => _capacity = v),
          ),
        ),
        // The frame's centred brand link with a chevron-circle glyph
        // (`:1198-1201`, 48 high: `padding:14px 0` round a 20 line).
        SizedBox(
          height: DabblerComposerSubmit.height,
          child: Center(
            child: DabblerTextLink(
              label: l.meetups_advanced,
              underline: false,
              style: DabblerType.subheadline.resolveForDirection(
                Directionality.of(context),
              ),
              trailingIcon: _more ? 'arrow-circle-up' : 'arrow-circle-down',
              onPressed: () => setState(() => _more = !_more),
            ),
          ),
        ),
        if (_more)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DabblerComposerRow(
                icon: 'eye',
                title: l.meetups_visibility,
                subtitle: l.meetups_visibility_sub,
                // Public is v1's only visibility: shown, not offered.
                trailing: DabblerSelectPill(
                  label: l.composer_vis_public,
                  brandInk: true,
                  onTap: null,
                ),
              ),
              DabblerComposerRow(
                icon: 'login',
                title: l.meetups_policy,
                subtitle: l.meetups_policy_sub,
                trailing: DabblerSelectPill(
                  label: policyLabel,
                  brandInk: true,
                  onTap: _pickPolicy,
                ),
              ),
              DabblerComposerRow(
                icon: 'medal-star',
                title: l.meetups_skill,
                subtitle: l.meetups_skill_sub,
                trailing: DabblerSelectPill(
                  label: _minSkill == null
                      ? l.meetups_skill_any
                      : '$_minSkill–$_maxSkill',
                  brandInk: true,
                  onTap: _pickSkill,
                ),
              ),
              DabblerComposerRow(
                icon: 'emoji-happy',
                title: l.meetups_vibe,
                subtitle: l.meetups_vibe_sub,
                trailing: DabblerSelectPill(
                  label: _vibe?.label ?? l.meetups_vibe_choose,
                  brandInk: true,
                  onTap: _pickVibe,
                ),
              ),
              DabblerComposerRow(
                icon: 'money',
                title: l.meetups_cost,
                subtitle: l.meetups_cost_sub,
                divider: false,
                // Free is v1's only cost: shown, not offered.
                trailing: DabblerSelectPill(
                  label: l.listing_free,
                  brandInk: true,
                  onTap: null,
                ),
              ),
            ],
          ),
        if (_error != null)
          DabblerBanner(tone: DabblerBannerTone.error, message: _error),
        // `padding-block:12px 24px; border-top:1px solid var(--faint)`
        // (`:1276`) — the button's own footer block.
        DabblerComposerSubmit(
          label: l.meetups_create_title,
          enabled: _canSubmit,
          loading: _busy,
          footer: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// The frame's small section caption: 11/13 `--muted`, `padding-top:6px`.
///
/// The first one also carries the frame's 12 between the sticky header and
/// the scroller (`gap:12px`), which the sheet's header row does not draw.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.first = false});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(
      top: first
          ? DabblerSpacing.space4 + DabblerSpacing.space2
          : DabblerSpacing.space2,
    ),
    child: DabblerText(
      label,
      style: DabblerType.caption2,
      tone: DabblerTextTone.tertiary,
    ),
  );
}

/// The skill rows of the meetup composer: Beginner 1–3, Intermediate 4–6,
/// Advanced 7–10 (the app's one scale). A stored value anywhere in a band
/// selects it, so an old (9, 10) meetup shows Advanced.
class MeetupSkillRows extends StatelessWidget {
  const MeetupSkillRows({
    super.key,
    required this.minSkill,
    required this.onPick,
  });

  final int? minSkill;
  final void Function(int min, int max) onPick;

  static const List<(String, int, int)> bands = <(String, int, int)>[
    ('Beginner', 1, 3),
    ('Intermediate', 4, 6),
    ('Advanced', 7, 10),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final titles = <String>[
      l.listing_skill_beginner,
      l.listing_skill_intermediate,
      l.listing_skill_advanced,
    ];
    final subtitles = <String>[
      l.skill_sub_beginner,
      l.skill_sub_intermediate,
      l.skill_sub_advanced,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < bands.length; i++)
          ComposerPickerRow(
            title: titles[i],
            subtitle: subtitles[i],
            // LTR isolate: "1–3" keeps its order inside Arabic text.
            trailingText: '\u2066${bands[i].$2}–${bands[i].$3}\u2069',
            // Any stored value in the band selects it (old (9, 10) rows too).
            selected:
                minSkill != null &&
                minSkill! >= bands[i].$2 &&
                minSkill! <= bands[i].$3,
            onTap: () => onPick(bands[i].$2, bands[i].$3),
          ),
      ],
    );
  }
}
