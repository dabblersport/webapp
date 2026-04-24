import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/services/moderation_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class _ComposerState {
  const _ComposerState({
    this.sportId,
    this.sportNameEn,
    this.sportEmoji,
    this.variantId,
    this.variantNameEn,
    this.requiredPlayers,
    this.selectedDate,
    this.selectedTime,
    this.durationMinutes = 60,
    this.venueSpaceId,
    this.venueName,
    this.venueSpaceName,
    this.joinPolicy = 'open',
    this.listingVisibility = 'public',
    this.allowWaitlist = false,
    this.allowSpectators = false,
    this.title,
    this.description,
    this.skillLevel,
    this.minSkill,
    this.maxSkill,
    this.isSubmitting = false,
    this.error,
  });

  final String? sportId;
  final String? sportNameEn;
  final String? sportEmoji;
  final String? variantId;
  final String? variantNameEn;
  final int? requiredPlayers;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final int durationMinutes;
  final String? venueSpaceId;
  final String? venueName;
  final String? venueSpaceName;
  final String joinPolicy;
  final String listingVisibility;
  final bool allowWaitlist;
  final bool allowSpectators;
  final String? title;
  final String? description;
  final String? skillLevel;
  final int? minSkill;
  final int? maxSkill;
  final bool isSubmitting;
  final String? error;

  bool get canSubmit =>
      sportId != null &&
      variantId != null &&
      selectedDate != null &&
      selectedTime != null &&
      !isSubmitting;

  _ComposerState copyWith({
    String? sportId,
    String? sportNameEn,
    String? sportEmoji,
    String? variantId,
    String? variantNameEn,
    int? requiredPlayers,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    int? durationMinutes,
    String? venueSpaceId,
    String? venueName,
    String? venueSpaceName,
    String? joinPolicy,
    String? listingVisibility,
    bool? allowWaitlist,
    bool? allowSpectators,
    String? title,
    String? description,
    String? skillLevel,
    int? minSkill,
    int? maxSkill,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool clearVenue = false,
    bool clearVariant = false,
    bool clearSkill = false,
  }) {
    return _ComposerState(
      sportId: sportId ?? this.sportId,
      sportNameEn: sportNameEn ?? this.sportNameEn,
      sportEmoji: sportEmoji ?? this.sportEmoji,
      variantId: clearVariant ? null : variantId ?? this.variantId,
      variantNameEn: clearVariant ? null : variantNameEn ?? this.variantNameEn,
      requiredPlayers: clearVariant ? null : requiredPlayers ?? this.requiredPlayers,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      venueSpaceId: clearVenue ? null : venueSpaceId ?? this.venueSpaceId,
      venueName: clearVenue ? null : venueName ?? this.venueName,
      venueSpaceName: clearVenue ? null : venueSpaceName ?? this.venueSpaceName,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      listingVisibility: listingVisibility ?? this.listingVisibility,
      allowWaitlist: allowWaitlist ?? this.allowWaitlist,
      allowSpectators: allowSpectators ?? this.allowSpectators,
      title: title ?? this.title,
      description: description ?? this.description,
      skillLevel: clearSkill ? null : skillLevel ?? this.skillLevel,
      minSkill: clearSkill ? null : minSkill ?? this.minSkill,
      maxSkill: clearSkill ? null : maxSkill ?? this.maxSkill,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class _ComposerNotifier extends StateNotifier<_ComposerState> {
  _ComposerNotifier() : super(const _ComposerState());

  final _db = Supabase.instance.client;

  // Sports / variants cache
  List<Map<String, dynamic>> _sports = [];
  List<Map<String, dynamic>> _variants = [];
  List<Map<String, dynamic>> _venueSpaces = [];

  bool _sportsLoaded = false;

  List<Map<String, dynamic>> get sports => _sports;
  List<Map<String, dynamic>> get variants => _variants;
  List<Map<String, dynamic>> get venueSpaces => _venueSpaces;

  Future<void> ensureSports() async {
    if (_sportsLoaded) return;
    try {
      final rows = await _db
          .from('sports')
          .select('id, sport_key, name_en, emoji')
          .eq('is_active', true)
          .eq('is_challenge_sport', true)
          .order('name_en');
      _sports = List<Map<String, dynamic>>.from(rows as List);
      _sportsLoaded = true;
    } catch (_) {}
  }

  Future<void> loadVariants(String sportId) async {
    try {
      final rows = await _db
          .from('sport_variants')
          .select('id, name_en, required_players, players_per_side')
          .eq('sport_id', sportId)
          .eq('is_active', true)
          .order('name_en');
      _variants = List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      _variants = [];
    }
  }

  Future<void> loadVenueSpaces() async {
    final variantId = state.variantId;
    if (variantId == null) {
      _venueSpaces = [];
      return;
    }
    try {
      final rows = await _db
          .from('venue_spaces')
          .select('id, name_en, venue:venues(id, name_en, area)')
          .eq('sport_variant_id', variantId)
          .eq('is_active', true);
      _venueSpaces = List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      _venueSpaces = [];
    }
  }

  void selectSport(Map<String, dynamic> sport) {
    state = state.copyWith(
      sportId: sport['id'] as String,
      sportNameEn: sport['name_en'] as String,
      sportEmoji: sport['emoji'] as String?,
      clearVariant: true,
      clearVenue: true,
    );
    loadVariants(sport['id'] as String);
  }

  void selectVariant(Map<String, dynamic> variant) {
    state = state.copyWith(
      variantId: variant['id'] as String,
      variantNameEn: variant['name_en'] as String,
      requiredPlayers: variant['required_players'] as int?,
      clearVenue: true,
    );
    loadVenueSpaces();
  }

  void selectDate(DateTime date) => state = state.copyWith(selectedDate: date);
  void selectTime(TimeOfDay time) => state = state.copyWith(selectedTime: time);
  void setDuration(int minutes) => state = state.copyWith(durationMinutes: minutes);

  void selectVenueSpace(Map<String, dynamic> space) {
    final venue = space['venue'] as Map<String, dynamic>? ?? {};
    state = state.copyWith(
      venueSpaceId: space['id'] as String,
      venueName: venue['name_en'] as String?,
      venueSpaceName: space['name_en'] as String?,
    );
  }

  void clearVenue() => state = state.copyWith(clearVenue: true);

  void setJoinPolicy(String policy) => state = state.copyWith(joinPolicy: policy);
  void setVisibility(String v) => state = state.copyWith(listingVisibility: v);
  void toggleWaitlist() => state = state.copyWith(allowWaitlist: !state.allowWaitlist);
  void toggleSpectators() => state = state.copyWith(allowSpectators: !state.allowSpectators);
  void setTitle(String v) => state = state.copyWith(title: v.isEmpty ? null : v);
  void setDescription(String v) => state = state.copyWith(description: v.isEmpty ? null : v);

  void selectSkillLevel(String level) {
    final (min, max) = switch (level) {
      'Beginner'     => (1, 3),
      'Intermediate' => (4, 6),
      'Advanced'     => (7, 8),
      'Pro'          => (9, 10),
      _              => (1, 10),
    };
    state = state.copyWith(skillLevel: level, minSkill: min, maxSkill: max);
  }

  void clearSkill() => state = state.copyWith(clearSkill: true);

  Future<bool> submit() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final moderation = ModerationService();
      final cooldown = await moderation.checkAndBumpCooldown(
        'game.create',
        windowSeconds: 86400,
        limitCount: 5,
      );
      if (!cooldown.allowed) {
        final reset = DateFormat('MMM d, HH:mm').format(cooldown.resetAt);
        state = state.copyWith(
          isSubmitting: false,
          error: 'Daily limit reached. Try again at $reset.',
        );
        return false;
      }

      final date = state.selectedDate!;
      final t = state.selectedTime!;
      final startAt = DateTime(date.year, date.month, date.day, t.hour, t.minute);
      final endAt = startAt.add(Duration(minutes: state.durationMinutes));

      final rules = <String, dynamic>{
        'duration_minutes': state.durationMinutes,
        if (state.description != null && state.description!.isNotEmpty)
          'notes': state.description,
      };

      final params = <String, dynamic>{
        'p_actor_type': 'player',
        'p_sport_id': state.sportId!,
        'p_sport_variant_id': state.variantId!,
        'p_start_at': startAt.toIso8601String(),
        'p_end_at': endAt.toIso8601String(),
        'p_bench_slots': 0,
        'p_listing_visibility': state.listingVisibility,
        'p_join_policy': state.joinPolicy,
        'p_allow_spectators': state.allowSpectators,
        'p_allows_waitlist': state.allowWaitlist,
        'p_rules': rules,
        if (state.title != null && state.title!.isNotEmpty) 'p_title': state.title,
        if (state.venueSpaceId != null) 'p_venue_space_id': state.venueSpaceId,
        if (state.minSkill != null) 'p_min_skill': state.minSkill,
        if (state.maxSkill != null) 'p_max_skill': state.maxSkill,
      };

      await _db.rpc('rpc_create_game', params: params);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on PostgrestException catch (e) {
      final msg = switch (e.message) {
        'sport_not_challenge_eligible' => 'Sport not available for games.',
        'invalid_sport_variant'        => 'Invalid format for this sport.',
        'invalid_time_range'           => 'End time must be after start time.',
        'creator_profile_not_found'    => 'Complete your profile first.',
        _                              => e.message,
      };
      state = state.copyWith(isSubmitting: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}

final _gameComposerProvider =
    StateNotifierProvider.autoDispose<_ComposerNotifier, _ComposerState>(
  (_) => _ComposerNotifier(),
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class GameComposerScreen extends ConsumerStatefulWidget {
  const GameComposerScreen({super.key});

  @override
  ConsumerState<GameComposerScreen> createState() => _GameComposerScreenState();
}

class _GameComposerScreenState extends ConsumerState<GameComposerScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(_gameComposerProvider.notifier).submit();
    if (!mounted) return;
    if (ok) {
      context.pop(true);
    } else {
      final err = ref.read(_gameComposerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Failed to create game'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(_gameComposerProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Game'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: state.canSubmit ? _submit : null,
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader('Sport & Format'),
          _SportVariantRow(
            sportLabel: state.sportId != null
                ? '${state.sportEmoji ?? ''} ${state.sportNameEn}'
                : null,
            variantLabel: state.variantNameEn,
            onTapSport: () => _openSportPicker(context),
            onTapVariant: state.sportId != null
                ? () => _openVariantPicker(context)
                : null,
          ),
          const SizedBox(height: 20),

          _SectionHeader('Date & Time'),
          _DateTimeRow(
            date: state.selectedDate,
            time: state.selectedTime,
            durationMinutes: state.durationMinutes,
            onTapDate: () => _pickDate(context),
            onTapTime: () => _pickTime(context),
            onTapDuration: () => _openDurationPicker(context),
          ),
          const SizedBox(height: 20),

          _SectionHeader('Venue'),
          _VenueChip(
            venueName: state.venueName,
            venueSpaceName: state.venueSpaceName,
            enabled: state.variantId != null,
            onTap: () => _openVenuePicker(context),
            onClear: ref.read(_gameComposerProvider.notifier).clearVenue,
          ),
          const SizedBox(height: 20),

          _SectionHeader('Join Policy'),
          _PillRow(
            options: const ['open', 'request', 'invite', 'link'],
            selected: state.joinPolicy,
            labels: const {
              'open': 'Open',
              'request': 'Request',
              'invite': 'Invite',
              'link': 'Link',
            },
            onSelect: ref.read(_gameComposerProvider.notifier).setJoinPolicy,
          ),
          const SizedBox(height: 16),

          _SectionHeader('Visibility'),
          _PillRow(
            options: const ['public', 'friends', 'private'],
            selected: state.listingVisibility,
            labels: const {
              'public': 'Public',
              'friends': 'Friends',
              'private': 'Private',
            },
            onSelect: ref.read(_gameComposerProvider.notifier).setVisibility,
          ),
          const SizedBox(height: 20),

          _SectionHeader('Skill Level'),
          _SkillChip(
            level: state.skillLevel,
            onTap: () => _openSkillPicker(context),
            onClear: ref.read(_gameComposerProvider.notifier).clearSkill,
          ),
          const SizedBox(height: 20),

          _SectionHeader('Options'),
          _ToggleRow(
            icon: Iconsax.clock,
            label: 'Waitlist',
            subtitle: 'Let players queue when full',
            value: state.allowWaitlist,
            onChanged: (_) =>
                ref.read(_gameComposerProvider.notifier).toggleWaitlist(),
          ),
          _ToggleRow(
            icon: Iconsax.eye,
            label: 'Spectators',
            subtitle: 'Allow spectators to watch',
            value: state.allowSpectators,
            onChanged: (_) =>
                ref.read(_gameComposerProvider.notifier).toggleSpectators(),
          ),
          const SizedBox(height: 20),

          _SectionHeader('Details (optional)'),
          _ComposerTextField(
            controller: _titleController,
            hint: 'Game title',
            onChanged: ref.read(_gameComposerProvider.notifier).setTitle,
          ),
          const SizedBox(height: 8),
          _ComposerTextField(
            controller: _descController,
            hint: 'Add a note for players...',
            minLines: 3,
            maxLines: 6,
            onChanged: ref.read(_gameComposerProvider.notifier).setDescription,
          ),
        ],
      ),
    );
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  Future<void> _openSportPicker(BuildContext context) async {
    final notifier = ref.read(_gameComposerProvider.notifier);
    await notifier.ensureSports();
    final sports = notifier.sports;
    if (!context.mounted) return;

    await showAdaptiveSheet(
      context: context,
      builder: (_) => _SportPickerSheet(
        sports: sports,
        onSelect: notifier.selectSport,
      ),
    );
  }

  Future<void> _openVariantPicker(BuildContext context) async {
    final notifier = ref.read(_gameComposerProvider.notifier);
    final variants = notifier.variants;
    if (!mounted) return;

    await showAdaptiveSheet(
      context: context,
      builder: (_) => _VariantPickerSheet(
        variants: variants,
        onSelect: notifier.selectVariant,
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(_gameComposerProvider).selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(_gameComposerProvider.notifier).selectDate(picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final current = ref.read(_gameComposerProvider).selectedTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      ref.read(_gameComposerProvider.notifier).selectTime(picked);
    }
  }

  Future<void> _openDurationPicker(BuildContext context) async {
    final current = ref.read(_gameComposerProvider).durationMinutes;
    await showAdaptiveSheet(
      context: context,
      builder: (_) => _DurationPickerSheet(
        currentMinutes: current,
        onSelect: ref.read(_gameComposerProvider.notifier).setDuration,
      ),
    );
  }

  Future<void> _openVenuePicker(BuildContext context) async {
    final notifier = ref.read(_gameComposerProvider.notifier);
    await notifier.loadVenueSpaces();
    final spaces = notifier.venueSpaces;
    if (!context.mounted) return;

    await showAdaptiveSheet(
      context: context,
      builder: (_) => _VenuePickerSheet(
        spaces: spaces,
        onSelect: notifier.selectVenueSpace,
      ),
    );
  }

  Future<void> _openSkillPicker(BuildContext context) async {
    await showAdaptiveSheet(
      context: context,
      builder: (_) => _SkillPickerSheet(
        onSelect: ref.read(_gameComposerProvider.notifier).selectSkillLevel,
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SportVariantRow extends StatelessWidget {
  const _SportVariantRow({
    required this.sportLabel,
    required this.variantLabel,
    required this.onTapSport,
    required this.onTapVariant,
  });

  final String? sportLabel;
  final String? variantLabel;
  final VoidCallback onTapSport;
  final VoidCallback? onTapVariant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChipButton(
            label: sportLabel ?? 'Select sport',
            icon: Iconsax.activity,
            filled: sportLabel != null,
            onTap: onTapSport,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChipButton(
            label: variantLabel ?? 'Format',
            icon: Iconsax.people,
            filled: variantLabel != null,
            onTap: onTapVariant,
            enabled: onTapVariant != null,
          ),
        ),
      ],
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.date,
    required this.time,
    required this.durationMinutes,
    required this.onTapDate,
    required this.onTapTime,
    required this.onTapDuration,
  });

  final DateTime? date;
  final TimeOfDay? time;
  final int durationMinutes;
  final VoidCallback onTapDate;
  final VoidCallback onTapTime;
  final VoidCallback onTapDuration;

  @override
  Widget build(BuildContext context) {
    final dateLabel = date != null
        ? DateFormat('EEE, MMM d').format(date!)
        : 'Date';
    final timeLabel = time != null ? time!.format(context) : 'Time';
    final durH = durationMinutes ~/ 60;
    final durM = durationMinutes % 60;
    final durLabel = durH > 0
        ? (durM > 0 ? '${durH}h ${durM}m' : '${durH}h')
        : '${durM}m';

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _ChipButton(
            label: dateLabel,
            icon: Iconsax.calendar_1,
            filled: date != null,
            onTap: onTapDate,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _ChipButton(
            label: timeLabel,
            icon: Iconsax.clock,
            filled: time != null,
            onTap: onTapTime,
          ),
        ),
        const SizedBox(width: 8),
        _ChipButton(
          label: durLabel,
          icon: Iconsax.timer_1,
          filled: false,
          onTap: onTapDuration,
        ),
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = filled ? cs.primaryContainer : cs.surfaceContainerHigh;
    final fgColor = filled ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final disabledColor = cs.surfaceContainerLow;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? color : disabledColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: enabled
                    ? fgColor
                    : cs.onSurface.withValues(alpha: 0.38)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: enabled
                          ? fgColor
                          : cs.onSurface.withValues(alpha: 0.38),
                      fontWeight:
                          filled ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueChip extends StatelessWidget {
  const _VenueChip({
    required this.venueName,
    required this.venueSpaceName,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  final String? venueName;
  final String? venueSpaceName;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasVenue = venueName != null;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasVenue
              ? cs.secondaryContainer
              : enabled
                  ? cs.surfaceContainerHigh
                  : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Iconsax.location,
              size: 16,
              color: hasVenue
                  ? cs.onSecondaryContainer
                  : cs.onSurfaceVariant.withValues(alpha: enabled ? 1 : 0.38),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasVenue
                    ? [venueName, venueSpaceName]
                        .whereType<String>()
                        .join(' · ')
                    : enabled
                        ? 'Select venue (optional)'
                        : 'Select a format first',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: hasVenue
                          ? cs.onSecondaryContainer
                          : cs.onSurfaceVariant
                              .withValues(alpha: enabled ? 1 : 0.38),
                      fontWeight:
                          hasVenue ? FontWeight.w600 : FontWeight.normal,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasVenue)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 16, color: cs.onSecondaryContainer),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.level,
    required this.onTap,
    required this.onClear,
  });

  final String? level;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: level != null
              ? cs.tertiaryContainer
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Iconsax.medal,
                size: 16,
                color: level != null
                    ? cs.onTertiaryContainer
                    : cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                level ?? 'Any skill level',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: level != null
                          ? cs.onTertiaryContainer
                          : cs.onSurfaceVariant,
                      fontWeight:
                          level != null ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
            if (level != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 16, color: cs.onTertiaryContainer),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({
    required this.options,
    required this.selected,
    required this.labels,
    required this.onSelect,
  });

  final List<String> options;
  final String selected;
  final Map<String, String> labels;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final isSelected = o == selected;
        return GestureDetector(
          onTap: () => onSelect(o),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              labels[o] ?? o,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        )),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ComposerTextField extends StatelessWidget {
  const _ComposerTextField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─── Picker Sheets ─────────────────────────────────────────────────────────────

class _SportPickerSheet extends StatelessWidget {
  const _SportPickerSheet({
    required this.sports,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> sports;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, controller) => Column(
        children: [
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('Select Sport',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: sports.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: controller,
                    itemCount: sports.length,
                    itemBuilder: (_, i) {
                      final s = sports[i];
                      return ListTile(
                        leading: Text(s['emoji'] as String? ?? '🏅',
                            style: const TextStyle(fontSize: 24)),
                        title: Text(s['name_en'] as String),
                        onTap: () {
                          onSelect(s);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _VariantPickerSheet extends StatelessWidget {
  const _VariantPickerSheet({
    required this.variants,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> variants;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      builder: (_, controller) => Column(
        children: [
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('Select Format',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: variants.isEmpty
                ? const Center(child: Text('No formats available'))
                : ListView.builder(
                    controller: controller,
                    itemCount: variants.length,
                    itemBuilder: (_, i) {
                      final v = variants[i];
                      final players = v['required_players'] as int?;
                      return ListTile(
                        title: Text(v['name_en'] as String),
                        subtitle: players != null
                            ? Text('$players players')
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          onSelect(v);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DurationPickerSheet extends StatelessWidget {
  const _DurationPickerSheet({
    required this.currentMinutes,
    required this.onSelect,
  });

  final int currentMinutes;
  final void Function(int) onSelect;

  static const _options = [30, 45, 60, 75, 90, 120, 150, 180];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.6,
      builder: (_, controller) => Column(
        children: [
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('Duration',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: _options.map((m) {
                final h = m ~/ 60;
                final min = m % 60;
                final label = h > 0
                    ? (min > 0 ? '$h h $min min' : '$h hour${h > 1 ? 's' : ''}')
                    : '$m minutes';
                return ListTile(
                  title: Text(label),
                  selected: m == currentMinutes,
                  onTap: () {
                    onSelect(m);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _VenuePickerSheet extends StatelessWidget {
  const _VenuePickerSheet({
    required this.spaces,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> spaces;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, controller) => Column(
        children: [
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('Select Venue',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: spaces.isEmpty
                ? const Center(child: Text('No venues available for this format'))
                : ListView.builder(
                    controller: controller,
                    itemCount: spaces.length,
                    itemBuilder: (_, i) {
                      final sp = spaces[i];
                      final venue =
                          sp['venue'] as Map<String, dynamic>? ?? {};
                      final venueName = venue['name_en'] as String? ?? 'Venue';
                      final area = venue['area'] as String?;
                      final spaceName = sp['name_en'] as String?;
                      return ListTile(
                        leading: const Icon(Iconsax.location),
                        title: Text('$venueName${spaceName != null ? ' · $spaceName' : ''}'),
                        subtitle: area != null ? Text(area) : null,
                        onTap: () {
                          onSelect(sp);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SkillPickerSheet extends StatelessWidget {
  const _SkillPickerSheet({required this.onSelect});
  final void Function(String) onSelect;

  static const _levels = [
    ('Beginner', '1–3', 'Just getting started'),
    ('Intermediate', '4–6', 'Plays regularly'),
    ('Advanced', '7–8', 'Competitive level'),
    ('Pro', '9–10', 'Elite / professional'),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.65,
      builder: (_, controller) => Column(
        children: [
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('Skill Level',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: _levels.map((l) {
                return ListTile(
                  title: Text(l.$1),
                  subtitle: Text(l.$3),
                  trailing: Text(l.$2,
                      style: Theme.of(context).textTheme.labelSmall),
                  onTap: () {
                    onSelect(l.$1);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
