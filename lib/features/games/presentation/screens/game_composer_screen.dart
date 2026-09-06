import 'package:flutter/material.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show activeChallengeSportsByProfileCountryProvider;
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class _ComposerState {
  const _ComposerState({
    this.editingGameId,
    this.sports = const [],
    this.sportsLoaded = false,
    this.sportId,
    this.sportNameEn,
    this.sportEmoji,
    this.sportColorCode,
    this.variantId,
    this.variantKey,
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
    this.minPlayers,
    this.maxPlayers,
    this.isSubmitting = false,
    this.error,
  });

  /// Non-null when the composer edits an existing game instead of creating.
  final String? editingGameId;

  /// Sport rows loaded from `public.sports`. Cached in state so chip
  /// rendering is reactive without a separate FutureProvider.
  final List<Map<String, dynamic>> sports;
  final bool sportsLoaded;

  final String? sportId;
  final String? sportNameEn;
  final String? sportEmoji;
  final String? sportColorCode;
  final String? variantId;

  /// `sport_variants.variant_key` — used to filter `venue_spaces.sport_variant_keys`.
  final String? variantKey;
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
  final int? minPlayers;
  final int? maxPlayers;
  final bool isSubmitting;
  final String? error;

  bool get isEditing => editingGameId != null;

  bool get canSubmit =>
      sportId != null &&
      variantId != null &&
      selectedDate != null &&
      selectedTime != null &&
      !isSubmitting;

  _ComposerState copyWith({
    String? editingGameId,
    List<Map<String, dynamic>>? sports,
    bool? sportsLoaded,
    String? sportId,
    String? sportNameEn,
    String? sportEmoji,
    String? sportColorCode,
    String? variantId,
    String? variantKey,
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
    int? minPlayers,
    int? maxPlayers,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool clearVenue = false,
    bool clearVariant = false,
    bool clearSkill = false,
    bool clearPlayers = false,
  }) {
    return _ComposerState(
      editingGameId: editingGameId ?? this.editingGameId,
      sports: sports ?? this.sports,
      sportsLoaded: sportsLoaded ?? this.sportsLoaded,
      sportId: sportId ?? this.sportId,
      sportNameEn: sportNameEn ?? this.sportNameEn,
      sportEmoji: sportEmoji ?? this.sportEmoji,
      sportColorCode: sportColorCode ?? this.sportColorCode,
      variantId: clearVariant ? null : variantId ?? this.variantId,
      variantKey: clearVariant ? null : variantKey ?? this.variantKey,
      variantNameEn: clearVariant ? null : variantNameEn ?? this.variantNameEn,
      requiredPlayers:
          clearVariant ? null : requiredPlayers ?? this.requiredPlayers,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      venueSpaceId: clearVenue ? null : venueSpaceId ?? this.venueSpaceId,
      venueName: clearVenue ? null : venueName ?? this.venueName,
      venueSpaceName:
          clearVenue ? null : venueSpaceName ?? this.venueSpaceName,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      listingVisibility: listingVisibility ?? this.listingVisibility,
      allowWaitlist: allowWaitlist ?? this.allowWaitlist,
      allowSpectators: allowSpectators ?? this.allowSpectators,
      title: title ?? this.title,
      description: description ?? this.description,
      skillLevel: clearSkill ? null : skillLevel ?? this.skillLevel,
      minSkill: clearSkill ? null : minSkill ?? this.minSkill,
      maxSkill: clearSkill ? null : maxSkill ?? this.maxSkill,
      minPlayers: clearPlayers ? null : minPlayers ?? this.minPlayers,
      maxPlayers: clearPlayers ? null : maxPlayers ?? this.maxPlayers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class _ComposerNotifier extends StateNotifier<_ComposerState> {
  _ComposerNotifier() : super(const _ComposerState());

  final _db = Supabase.instance.client;

  // Variant + venue caches live on the notifier (only read by picker sheets).
  List<Map<String, dynamic>> _variants = [];
  List<Map<String, dynamic>> _venueSpaces = [];

  List<Map<String, dynamic>> get variants => _variants;
  List<Map<String, dynamic>> get venueSpaces => _venueSpaces;

  Future<void> ensureSports() async {
    if (state.sportsLoaded) return;
    try {
      final rows = await _db
          .from(SupabaseConfig.sportsTable)
          .select('id, sport_key, name_en, emoji, color_code')
          .eq('is_active', true)
          .eq('is_challenge_sport', true)
          .order('name_en');
      state = state.copyWith(
        sports: List<Map<String, dynamic>>.from(rows as List),
        sportsLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(sportsLoaded: true);
    }
  }

  /// Prefills the composer from an existing game (edit mode). Reads the same
  /// `v_game_card` view the detail screen uses — the raw `games` table is not
  /// client-readable (RLS with no policies).
  Future<void> initForEdit(String gameId) async {
    await ensureSports();
    try {
      final row = await _db
          .from(SupabaseConfig.vGameCardTable)
          .select()
          .eq('id', gameId)
          .single();

      final rules =
          (row['rules'] as Map?)?.cast<String, dynamic>() ?? const {};
      // Round-trips the naive-local timestamps exactly as create wrote them
      // (no toLocal — GameView parses the same way for display).
      final startAt = DateTime.parse(row['start_at'] as String);
      final endAt = DateTime.parse(row['end_at'] as String);
      final duration = rules['duration_minutes'] as int? ??
          endAt.difference(startAt).inMinutes;

      // Emoji/colour aren't on the view — resolve from the loaded sports.
      final sport = state.sports.firstWhere(
        (s) => s['id'] == row['sport_id'],
        orElse: () => const <String, dynamic>{},
      );

      final minSkill = row['min_skill'] as int?;
      final maxSkill = row['max_skill'] as int?;
      final title = (row['title'] as String?)?.trim();

      state = state.copyWith(
        editingGameId: gameId,
        sportId: row['sport_id'] as String?,
        sportNameEn: row['sport_name_en'] as String?,
        sportEmoji: sport['emoji'] as String?,
        sportColorCode: sport['color_code'] as String?,
        variantId: row['sport_variant_id'] as String?,
        variantKey: row['variant_key'] as String?,
        variantNameEn: row['variant_name_en'] as String?,
        requiredPlayers: row['required_players'] as int?,
        selectedDate: DateTime(startAt.year, startAt.month, startAt.day),
        selectedTime: TimeOfDay(hour: startAt.hour, minute: startAt.minute),
        durationMinutes: duration,
        venueSpaceId: row['venue_space_id'] as String?,
        venueName: row['venue_name'] as String?,
        venueSpaceName: row['venue_space_name'] as String?,
        joinPolicy: row['join_policy'] as String? ?? 'open',
        listingVisibility: row['listing_visibility'] as String? ?? 'public',
        allowWaitlist: row['allows_waitlist'] as bool? ?? false,
        allowSpectators: row['allow_spectators'] as bool? ?? false,
        title: (title == null || title.isEmpty) ? null : title,
        description: rules['notes'] as String?,
        minSkill: minSkill,
        maxSkill: maxSkill,
        skillLevel: _skillLabelFor(minSkill, maxSkill),
        // Create mirrors these into rules; capacity is the fallback for
        // games created before max_players was stored there.
        minPlayers: rules['min_players'] as int?,
        maxPlayers: rules['max_players'] as int? ?? row['capacity'] as int?,
      );

      // Warm the picker caches so format/venue sheets open populated.
      await loadVariants(row['sport_id'] as String);
      await loadVenueSpaces();
    } catch (_) {
      state = state.copyWith(error: 'Failed to load game');
    }
  }

  /// Reverse of [selectSkillLevel]'s (min, max) mapping.
  String? _skillLabelFor(int? min, int? max) => switch ((min, max)) {
        (1, 3) => 'Beginner',
        (4, 6) => 'Intermediate',
        (7, 8) => 'Advanced',
        (9, 10) => 'Pro',
        _ => null,
      };

  Future<void> loadVariants(String sportId) async {
    try {
      final rows = await _db
          .from(SupabaseConfig.sportVariantsTable)
          .select('id, variant_key, name_en, required_players, players_per_side')
          .eq('sport_id', sportId)
          .eq('is_active', true)
          .order('name_en');
      _variants = List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      _variants = [];
    }
  }

  /// Loads venue spaces matching the selected sport AND variant.
  ///
  /// Schema reality (verified 2026-06-16 against `public.venue_spaces`):
  /// the join is via `sport_id` (uuid) + `sport_variant_keys` (text[]
  /// containing the variant's `variant_key`). There's no `sport_variant_id`
  /// column — the previous filter on that column silently returned nothing.
  Future<void> loadVenueSpaces() async {
    final sportId = state.sportId;
    final variantKey = state.variantKey;
    if (sportId == null || variantKey == null) {
      _venueSpaces = [];
      return;
    }
    try {
      final rows = await _db
          .from(SupabaseConfig.venueSpacesTable)
          .select(
            'id, name_en, sport_id, sport_variant_keys, '
            'venue:venues(id, name_en, area)',
          )
          .eq('sport_id', sportId)
          .eq('is_active', true)
          .contains('sport_variant_keys', [variantKey]);
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
      sportColorCode: sport['color_code'] as String?,
      clearVariant: true,
      clearVenue: true,
      clearPlayers: true,
    );
    loadVariants(sport['id'] as String);
  }

  void selectVariant(Map<String, dynamic> variant) {
    final required = variant['required_players'] as int?;
    state = state.copyWith(
      variantId: variant['id'] as String,
      variantKey: variant['variant_key'] as String?,
      variantNameEn: variant['name_en'] as String,
      requiredPlayers: required,
      // Default min/max to the variant's `required_players` so the row reads
      // out something immediately; user can still tap to override.
      minPlayers: required,
      maxPlayers: required,
      clearVenue: true,
    );
    loadVenueSpaces();
  }

  void selectDate(DateTime date) => state = state.copyWith(selectedDate: date);
  void selectTime(TimeOfDay time) => state = state.copyWith(selectedTime: time);
  void setDuration(int minutes) =>
      state = state.copyWith(durationMinutes: minutes);

  void selectVenueSpace(Map<String, dynamic> space) {
    final venue = space['venue'] as Map<String, dynamic>? ?? {};
    state = state.copyWith(
      venueSpaceId: space['id'] as String,
      venueName: venue['name_en'] as String?,
      venueSpaceName: space['name_en'] as String?,
    );
  }

  void clearVenue() => state = state.copyWith(clearVenue: true);

  void setJoinPolicy(String policy) =>
      state = state.copyWith(joinPolicy: policy);
  void setVisibility(String v) => state = state.copyWith(listingVisibility: v);
  void toggleWaitlist() =>
      state = state.copyWith(allowWaitlist: !state.allowWaitlist);
  void toggleSpectators() =>
      state = state.copyWith(allowSpectators: !state.allowSpectators);
  void setTitle(String v) =>
      state = state.copyWith(title: v.isEmpty ? null : v);
  void setDescription(String v) =>
      state = state.copyWith(description: v.isEmpty ? null : v);

  void selectSkillLevel(String level) {
    final (min, max) = switch (level) {
      'Beginner' => (1, 3),
      'Intermediate' => (4, 6),
      'Advanced' => (7, 8),
      'Pro' => (9, 10),
      _ => (1, 10),
    };
    state = state.copyWith(skillLevel: level, minSkill: min, maxSkill: max);
  }

  void clearSkill() => state = state.copyWith(clearSkill: true);

  void setMinPlayers(int v) => state = state.copyWith(minPlayers: v);
  void setMaxPlayers(int v) => state = state.copyWith(maxPlayers: v);
  void clearPlayers() => state = state.copyWith(clearPlayers: true);

  Future<bool> submit() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      // Creation cooldown only — editing your own game is not rate-limited.
      if (!state.isEditing) {
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
      }

      final date = state.selectedDate!;
      final t = state.selectedTime!;
      final startAt =
          DateTime(date.year, date.month, date.day, t.hour, t.minute);
      final endAt = startAt.add(Duration(minutes: state.durationMinutes));

      final rules = <String, dynamic>{
        'duration_minutes': state.durationMinutes,
        if (state.description != null && state.description!.isNotEmpty)
          'notes': state.description,
      };

      if (state.isEditing) {
        final params = <String, dynamic>{
          'p_game_id': state.editingGameId!,
          'p_start_at': startAt.toIso8601String(),
          'p_end_at': endAt.toIso8601String(),
          'p_listing_visibility': state.listingVisibility,
          'p_join_policy': state.joinPolicy,
          'p_allow_spectators': state.allowSpectators,
          'p_allows_waitlist': state.allowWaitlist,
          'p_rules': rules,
          if (state.title != null && state.title!.isNotEmpty)
            'p_title': state.title,
          if (state.venueSpaceId != null)
            'p_venue_space_id': state.venueSpaceId
          else
            'p_clear_venue': true,
          if (state.minSkill != null) 'p_min_skill': state.minSkill,
          if (state.maxSkill != null) 'p_max_skill': state.maxSkill,
          if (state.minSkill == null && state.maxSkill == null)
            'p_clear_skill': true,
          if (state.minPlayers != null) 'p_min_players': state.minPlayers,
          if (state.maxPlayers != null) 'p_max_players': state.maxPlayers,
        };

        await _db.rpc(SupabaseConfig.rpcUpdateGameFn, params: params);
        state = state.copyWith(isSubmitting: false);
        return true;
      }

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
        if (state.title != null && state.title!.isNotEmpty)
          'p_title': state.title,
        if (state.venueSpaceId != null)
          'p_venue_space_id': state.venueSpaceId,
        if (state.minSkill != null) 'p_min_skill': state.minSkill,
        if (state.maxSkill != null) 'p_max_skill': state.maxSkill,
        // Editable Min/Max players — only sent when set. Back-end follow-up:
        // extend rpc_create_game to accept p_min_players / p_max_players.
        if (state.minPlayers != null) 'p_min_players': state.minPlayers,
        if (state.maxPlayers != null) 'p_max_players': state.maxPlayers,
      };

      await _db.rpc(SupabaseConfig.rpcCreateGameFn, params: params);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on PostgrestException catch (e) {
      final msg = switch (e.message) {
        'sport_not_challenge_eligible' => 'Sport not available for games.',
        'invalid_sport_variant' => 'Invalid format for this sport.',
        'invalid_time_range' => 'End time must be after start time.',
        'creator_profile_not_found' => 'Complete your profile first.',
        'not_host_or_not_found' => 'This game can no longer be edited.',
        'invalid_player_range' => 'Min players cannot exceed max players.',
        'invalid_min_players' ||
        'invalid_max_players' =>
          'Player counts must be at least 1.',
        _ => e.message,
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
  const GameComposerScreen({super.key, this.editGameId});

  /// When set, the composer opens prefilled and saves changes to this game
  /// instead of creating a new one. Sport & format are locked in edit mode.
  final String? editGameId;

  @override
  ConsumerState<GameComposerScreen> createState() => _GameComposerScreenState();
}

class _GameComposerScreenState extends ConsumerState<GameComposerScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  bool get _isEditing => widget.editGameId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      Future.microtask(() async {
        await ref
            .read(_gameComposerProvider.notifier)
            .initForEdit(widget.editGameId!);
        if (!mounted) return;
        final s = ref.read(_gameComposerProvider);
        _titleController.text = s.title ?? '';
        _descController.text = s.description ?? '';
      });
    } else {
      // Kick off sport load so the chips appear as soon as the drawer opens.
      Future.microtask(
          () => ref.read(_gameComposerProvider.notifier).ensureSports());
    }
  }

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
          content: Text(err ??
              (_isEditing ? 'Failed to save changes' : 'Failed to create game')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_gameComposerProvider);
    final notifier = ref.read(_gameComposerProvider.notifier);

    return ComposerDrawerShell(
      title: _isEditing ? 'Edit Game' : 'Quick Game',
      ctaLabel: _isEditing ? 'Save changes' : 'Create game',
      canSubmit: state.canSubmit,
      isSubmitting: state.isSubmitting,
      onCtaTap: _submit,
      errorMessage: state.error,
      children: [
        // ── A. Sport ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ComposerSectionLabel(label: 'SPORT'),
              const SizedBox(height: 8),
              // Sport is locked in edit mode — capacity and the roster
              // derive from the sport/format chosen at creation.
              IgnorePointer(
                ignoring: _isEditing,
                child: Opacity(
                  opacity: _isEditing ? 0.55 : 1,
                  child: _SportChipsRow(
                    sports: state.sports,
                    loaded: state.sportsLoaded,
                    selectedSportId: state.sportId,
                    onSelect: notifier.selectSport,
                  ),
                ),
              ),
            ],
          ),
        ),
        _SectionDivider(),

        // ── B. Format ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ComposerSettingsRow(
            icon: Icons.grid_view_outlined,
            title: 'Format',
            subtitle: 'Game format',
            showDivider: true,
            trailing: ComposerSelectPill(
              value: state.variantNameEn ??
                  (state.sportId == null
                      ? 'Select sport first'
                      : 'Select format'),
              caret: ComposerSelectCaret.right,
              // Disabled until a sport is picked, and locked in edit mode —
              // tap is ignored and the pill renders in the faint text colour.
              onTap: (state.sportId == null || _isEditing)
                  ? null
                  : () => _openVariantPicker(context),
            ),
          ),
        ),

        // ── C. Date & Time ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ComposerSettingsRow(
            icon: Icons.calendar_today_outlined,
            title: 'Date & Time',
            subtitle: 'When is the game',
            showDivider: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ComposerCompactSelectPill(
                  value: _formatDateChip(state.selectedDate),
                  onTap: () => _pickDate(context),
                ),
                const SizedBox(width: 8),
                ComposerCompactSelectPill(
                  value: _formatTimeChip(context, state.selectedTime),
                  onTap: () => _pickTime(context),
                ),
                const SizedBox(width: 8),
                ComposerCompactSelectPill(
                  value: _formatDurationChip(state.durationMinutes),
                  highlighted: true,
                  onTap: () => _openDurationPicker(context),
                ),
              ],
            ),
          ),
        ),

        // ── D. Venue ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ComposerSettingsRow(
            icon: Icons.location_on_outlined,
            title: 'Venue',
            subtitle: 'Where to play',
            showDivider: true,
            trailing: ComposerSelectPill(
              value: _venueLabel(state),
              caret: ComposerSelectCaret.right,
              onTap: () => _openVenuePicker(context),
            ),
          ),
        ),

        // ── E. Join Policy ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ComposerSectionLabel(label: 'JOIN POLICY'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const [
                    ('open', 'Open'),
                    ('request', 'Request'),
                    ('invite', 'Invite'),
                    ('link', 'Link'),
                  ])
                    ComposerPolicyChip(
                      label: entry.$2,
                      selected: state.joinPolicy == entry.$1,
                      onTap: () => notifier.setJoinPolicy(entry.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
        _SectionDivider(),

        // ── F. Visibility ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ComposerSectionLabel(label: 'VISIBILITY'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const [
                    ('public', 'Public'),
                    ('followers', 'Followers'),
                    ('private', 'Private'),
                  ])
                    ComposerPolicyChip(
                      label: entry.$2,
                      selected: state.listingVisibility == entry.$1,
                      onTap: () => notifier.setVisibility(entry.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
        _SectionDivider(),

        // ── G. Skill Level ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ComposerSettingsRow(
            icon: Icons.workspace_premium_outlined,
            title: 'Skill Level',
            subtitle: 'Player experience',
            showDivider: true,
            trailing: ComposerSelectPill(
              value: state.skillLevel ?? 'Any level',
              caret: ComposerSelectCaret.down,
              onTap: () => _openSkillPicker(context),
            ),
          ),
        ),

        // ── H. Players ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ComposerSettingsRow(
            icon: Icons.people_outline,
            title: 'Players',
            subtitle: 'Min & max players',
            showDivider: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ComposerCompactSelectPill(
                  value: state.minPlayers?.toString() ?? '—',
                  suffixLabel: 'min',
                  onTap: () => _openPlayerCountPicker(
                    context,
                    title: 'Minimum players',
                    initial: state.minPlayers ?? state.requiredPlayers ?? 2,
                    onSelect: notifier.setMinPlayers,
                  ),
                ),
                const SizedBox(width: 8),
                ComposerCompactSelectPill(
                  value: state.maxPlayers?.toString() ?? '—',
                  suffixLabel: 'max',
                  onTap: () => _openPlayerCountPicker(
                    context,
                    title: 'Maximum players',
                    initial: state.maxPlayers ?? state.requiredPlayers ?? 10,
                    onSelect: notifier.setMaxPlayers,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Options divider + Options section ───────────────────────────────
        _SectionDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              ComposerSettingsRow(
                icon: Icons.group_outlined,
                title: 'Waitlist',
                subtitle: 'Let players queue when full',
                showDivider: true,
                trailing: ComposerToggle(
                  value: state.allowWaitlist,
                  onChanged: (_) => notifier.toggleWaitlist(),
                ),
              ),
              ComposerSettingsRow(
                icon: Icons.visibility_outlined,
                title: 'Spectators',
                subtitle: 'Allow spectators to watch',
                showDivider: false,
                trailing: ComposerToggle(
                  value: state.allowSpectators,
                  onChanged: (_) => notifier.toggleSpectators(),
                ),
              ),
            ],
          ),
        ),

        // ── J. Details ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ComposerSectionLabel(
                label: 'DETAILS (OPTIONAL)',
                letterSpacing: 1.2,
              ),
              const SizedBox(height: 10),
              ComposerGlassInput(
                controller: _titleController,
                hint: 'Game title',
                onChanged: notifier.setTitle,
              ),
              const SizedBox(height: 10),
              ComposerGlassInput(
                controller: _descController,
                hint: 'Add a note for players...',
                minLines: 3,
                maxLines: 6,
                onChanged: notifier.setDescription,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Format helpers ────────────────────────────────────────────────────────

  String _formatDateChip(DateTime? date) {
    if (date == null) return 'Date';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    }
    return DateFormat('MMM d').format(date);
  }

  String _formatTimeChip(BuildContext context, TimeOfDay? time) {
    if (time == null) return 'Time';
    return time.format(context);
  }

  String _formatDurationChip(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String _venueLabel(_ComposerState state) {
    if (state.venueSpaceId == null) return 'Select';
    return [state.venueName, state.venueSpaceName]
        .whereType<String>()
        .join(' · ');
  }

  // ─── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _openVariantPicker(BuildContext context) async {
    final state = ref.read(_gameComposerProvider);
    if (state.sportId == null) {
      // Sport must be picked first — silently open the sport picker instead.
      return _openSportPicker(context);
    }
    final notifier = ref.read(_gameComposerProvider.notifier);
    if (notifier.variants.isEmpty) {
      await notifier.loadVariants(state.sportId!);
    }
    if (!context.mounted) return;

    await showAdaptiveSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (_) => _VariantPickerSheet(
        variants: notifier.variants,
        onSelect: notifier.selectVariant,
      ),
    );
  }

  Future<void> _openSportPicker(BuildContext context) async {
    final notifier = ref.read(_gameComposerProvider.notifier);
    final state = ref.read(_gameComposerProvider);
    final selectedSport = state.sportId != null
        ? Sport(
            id: state.sportId!,
            nameEn: state.sportNameEn ?? '',
            emoji: state.sportEmoji,
          )
        : null;
    if (!context.mounted) return;

    await showAdaptiveSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (_) => SportSelectionSheet(
        sportsProvider: activeChallengeSportsByProfileCountryProvider,
        selectedSport: selectedSport,
        onSelect: (sport) => notifier.selectSport({
          'id': sport.id,
          'name_en': sport.nameEn,
          'emoji': sport.emoji,
          'sport_key': sport.sportKey,
          'color_code': sport.colorCode,
        }),
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (_) => _VenuePickerSheet(
        spaces: spaces,
        onSelect: notifier.selectVenueSpace,
        onClear: notifier.clearVenue,
        canClear: ref.read(_gameComposerProvider).venueSpaceId != null,
      ),
    );
  }

  Future<void> _openSkillPicker(BuildContext context) async {
    await showAdaptiveSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (_) => _SkillPickerSheet(
        onSelect: ref.read(_gameComposerProvider.notifier).selectSkillLevel,
        onClear: ref.read(_gameComposerProvider.notifier).clearSkill,
        canClear: ref.read(_gameComposerProvider).skillLevel != null,
      ),
    );
  }

  Future<void> _openPlayerCountPicker(
    BuildContext context, {
    required String title,
    required int initial,
    required ValueChanged<int> onSelect,
  }) async {
    await showAdaptiveSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (_) => _PlayerCountPickerSheet(
        title: title,
        initialValue: initial,
        onSelect: onSelect,
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// 1px full-width divider used between Pencil "sections".
class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: ComposerPalette.of(context).divider,
    );
  }
}

// ─── Sport chips row ─────────────────────────────────────────────────────────

class _SportChipsRow extends StatelessWidget {
  const _SportChipsRow({
    required this.sports,
    required this.loaded,
    required this.selectedSportId,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> sports;
  final bool loaded;
  final String? selectedSportId;
  final ValueChanged<Map<String, dynamic>> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return SizedBox(
        height: 78,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ComposerPalette.of(context).textMuted,
            ),
          ),
        ),
      );
    }
    if (sports.isEmpty) {
      return SizedBox(
        height: 78,
        child: Center(
          child: Text(
            'No sports available',
            style: TextStyle(
              fontSize: 13,
              color: ComposerPalette.of(context).textSubtle,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: sports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sport = sports[i];
          final id = sport['id'] as String;
          return _SportChip(
            label: sport['name_en'] as String? ?? 'Sport',
            emoji: sport['emoji'] as String?,
            selected: id == selectedSportId,
            onTap: () => onSelect(sport),
          );
        },
      ),
    );
  }
}

/// Sport tile chip.
/// Pencil: radius 12, padding [16, 12], vertical, gap 8, alignItems/justify
/// center, 28px Phosphor icon (we render the sport emoji) + label 13/500.
/// Selected = cs.primary fill, white content. Unselected = bgGlass +
/// borderGlass stroke, textMuted content.
class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = ComposerPalette.of(context);
    return Semantics(
      label: 'Sport: $label, tap to select',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 76,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : palette.bgGlass,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? null
                : Border.all(color: palette.borderGlass, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji ?? '🎯',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Picker sheets ────────────────────────────────────────────────────────────

class _VariantPickerSheet extends StatelessWidget {
  const _VariantPickerSheet({
    required this.variants,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> variants;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Select Format',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: variants.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No formats available')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: variants.length,
                    itemBuilder: (_, i) {
                      final v = variants[i];
                      final players = v['required_players'] as int?;
                      return ListTile(
                        title: Text(v['name_en'] as String),
                        subtitle:
                            players != null ? Text('$players players') : null,
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Duration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _options.map((m) {
                final h = m ~/ 60;
                final min = m % 60;
                final label = h > 0
                    ? (min > 0
                        ? '$h h $min min'
                        : '$h hour${h > 1 ? 's' : ''}')
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

class _VenuePickerSheet extends StatefulWidget {
  const _VenuePickerSheet({
    required this.spaces,
    required this.onSelect,
    required this.onClear,
    required this.canClear,
  });

  final List<Map<String, dynamic>> spaces;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback onClear;
  final bool canClear;

  @override
  State<_VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends State<_VenuePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered() {
    if (_query.isEmpty) return widget.spaces;
    final q = _query.toLowerCase();
    return widget.spaces.where((sp) {
      final venue = sp['venue'] as Map<String, dynamic>? ?? const {};
      final venueName = (venue['name_en'] as String? ?? '').toLowerCase();
      final spaceName = (sp['name_en'] as String? ?? '').toLowerCase();
      final area = (venue['area'] as String? ?? '').toLowerCase();
      return venueName.contains(q) ||
          spaceName.contains(q) ||
          area.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filtered = _filtered();
    final hasAnySpaces = widget.spaces.isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                Text(
                  'Select Venue',
                  style: tt.titleMedium,
                ),
                const Spacer(),
                if (widget.canClear)
                  TextButton(
                    onPressed: () {
                      widget.onClear();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear',
                      style: TextStyle(color: cs.primary),
                    ),
                  ),
              ],
            ),
          ),

          // Search — only shown when there are spaces to filter
          if (hasAnySpaces)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search venues, spaces or area…',
                  prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          // Results
          Flexible(
            child: !hasAnySpaces
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No venues available for this format'),
                    ),
                  )
                : filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No matches',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final sp = filtered[i];
                          final venue =
                              sp['venue'] as Map<String, dynamic>? ?? const {};
                          final venueName =
                              venue['name_en'] as String? ?? 'Venue';
                          final area = venue['area'] as String?;
                          final spaceName = sp['name_en'] as String?;
                          return ListTile(
                            leading: const Icon(Iconsax.location),
                            title: Text(
                              '$venueName'
                              '${spaceName != null ? ' · $spaceName' : ''}',
                            ),
                            subtitle: area != null ? Text(area) : null,
                            onTap: () {
                              widget.onSelect(sp);
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
  const _SkillPickerSheet({
    required this.onSelect,
    required this.onClear,
    required this.canClear,
  });

  final void Function(String) onSelect;
  final VoidCallback onClear;
  final bool canClear;

  static const _levels = [
    ('Beginner', '1–3', 'Just getting started'),
    ('Intermediate', '4–6', 'Plays regularly'),
    ('Advanced', '7–8', 'Competitive level'),
    ('Pro', '9–10', 'Elite / professional'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.65,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                Text(
                  'Skill Level',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (canClear)
                  TextButton(
                    onPressed: () {
                      onClear();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear',
                      style: TextStyle(color: cs.primary),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _levels.map((l) {
                return ListTile(
                  title: Text(l.$1),
                  subtitle: Text(l.$3),
                  trailing: Text(
                    l.$2,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
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

/// Number stepper sheet shared between Min and Max players.
class _PlayerCountPickerSheet extends StatefulWidget {
  const _PlayerCountPickerSheet({
    required this.title,
    required this.initialValue,
    required this.onSelect,
  });

  final String title;
  final int initialValue;
  final ValueChanged<int> onSelect;

  @override
  State<_PlayerCountPickerSheet> createState() =>
      _PlayerCountPickerSheetState();
}

class _PlayerCountPickerSheetState extends State<_PlayerCountPickerSheet> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(1, 50);
  }

  void _bump(int delta) {
    setState(() => _value = (_value + delta).clamp(1, 50));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  onTap: _value > 1 ? () => _bump(-1) : null,
                ),
                Text(
                  '$_value',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  onTap: _value < 50 ? () => _bump(1) : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onSelect(_value);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled
              ? cs.surfaceContainerHighest
              : cs.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 28,
          color: disabled
              ? cs.onSurfaceVariant.withValues(alpha: 0.5)
              : cs.primary,
        ),
      ),
    );
  }
}

