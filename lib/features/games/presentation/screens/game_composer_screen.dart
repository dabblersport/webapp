import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show activeChallengeSportsByProfileCountryProvider;
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';

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
      requiredPlayers: clearVariant
          ? null
          : requiredPlayers ?? this.requiredPlayers,
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

      final rules = (row['rules'] as Map?)?.cast<String, dynamic>() ?? const {};
      // Round-trips the naive-local timestamps exactly as create wrote them
      // (no toLocal — GameView parses the same way for display).
      final startAt = DateTime.parse(row['start_at'] as String);
      final endAt = DateTime.parse(row['end_at'] as String);
      final duration =
          rules['duration_minutes'] as int? ??
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
          .select(
            'id, variant_key, name_en, required_players, players_per_side',
          )
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
      final startAt = DateTime(
        date.year,
        date.month,
        date.day,
        t.hour,
        t.minute,
      );
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
        if (state.venueSpaceId != null) 'p_venue_space_id': state.venueSpaceId,
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
        'invalid_max_players' => 'Player counts must be at least 1.',
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
        () => ref.read(_gameComposerProvider.notifier).ensureSports(),
      );
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
      DabblerToastProvider.of(context).show(
        DabblerToastSpec(
          message:
              err ??
              (_isEditing ? 'Failed to save changes' : 'Failed to create game'),
          tone: DabblerToastTone.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_gameComposerProvider);
    final notifier = ref.read(_gameComposerProvider.notifier);
    const gutter = EdgeInsetsDirectional.symmetric(
      horizontal: DabblerSpacing.space8,
    );
    const block = EdgeInsetsDirectional.symmetric(
      horizontal: DabblerSpacing.space8,
      vertical: DabblerSpacing.space4,
    );

    return ComposerDrawerShell(
      title: _isEditing
          ? AppLocalizations.of(context).game_edit
          : AppLocalizations.of(context).game_create,
      ctaLabel: _isEditing
          ? AppLocalizations.of(context).game_save_changes
          : AppLocalizations.of(context).game_create,
      canSubmit: state.canSubmit,
      isSubmitting: state.isSubmitting,
      onCtaTap: _submit,
      errorMessage: state.error,
      children: [
        // ── A. Sport ────────────────────────────────────────────────────────
        Padding(
          padding: block,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ComposerSectionLabel(
                label: AppLocalizations.of(context).game_sport,
              ),
              const SizedBox(height: DabblerSpacing.space3),
              // Sport is locked in edit mode — capacity and the roster
              // derive from the sport/format chosen at creation.
              DabblerInert(
                inert: _isEditing,
                child: _SportChipsRow(
                  sports: state.sports,
                  loaded: state.sportsLoaded,
                  selectedSportId: state.sportId,
                  onSelect: notifier.selectSport,
                ),
              ),
            ],
          ),
        ),
        const DabblerDivider(),

        // ── B. Format ───────────────────────────────────────────────────────
        Padding(
          padding: gutter,
          child: ComposerSettingsRow(
            icon: 'category',
            title: AppLocalizations.of(context).game_format,
            subtitle: AppLocalizations.of(context).game_format_sub,
            trailing: ComposerSelectPill(
              value:
                  state.variantNameEn ??
                  (state.sportId == null
                      ? AppLocalizations.of(context).game_select_sport_first
                      : AppLocalizations.of(context).game_select_format),
              caret: ComposerSelectCaret.right,
              // Disabled until a sport is picked, and locked in edit mode.
              onTap: (state.sportId == null || _isEditing)
                  ? null
                  : () => _openVariantPicker(context),
            ),
          ),
        ),

        // ── D. Venue ────────────────────────────────────────────────────────
        Padding(
          padding: gutter,
          child: ComposerSettingsRow(
            icon: 'location',
            title: AppLocalizations.of(context).composer_venue,
            subtitle: AppLocalizations.of(context).game_venue_sub,
            trailing: ComposerSelectPill(
              value: _venueLabel(state),
              caret: ComposerSelectCaret.right,
              onTap: () => _openVenuePicker(context),
            ),
          ),
        ),

        // ── C. Date & Time ──────────────────────────────────────────────────
        Padding(
          padding: gutter,
          child: ComposerSettingsRow(
            icon: 'calendar',
            title: AppLocalizations.of(context).game_date_time,
            subtitle: AppLocalizations.of(context).game_date_time_sub,
            trailing: Wrap(
              spacing: DabblerSpacing.space2,
              children: [
                ComposerCompactSelectPill(
                  value: _formatDateChip(state.selectedDate),
                  onTap: () => _pickDate(context),
                ),
                ComposerCompactSelectPill(
                  value: _formatTimeChip(context, state.selectedTime),
                  onTap: () => _pickTime(context),
                ),
              ],
            ),
          ),
        ),

        // ── C2. Duration ────────────────────────────────────────────────────
        Padding(
          padding: gutter,
          child: ComposerSettingsRow(
            icon: 'timer',
            title: AppLocalizations.of(context).game_duration,
            subtitle: AppLocalizations.of(context).game_duration_sub,
            trailing: Wrap(
              spacing: DabblerSpacing.space2,
              children: [
                for (final m in {30, 60, 120, state.durationMinutes})
                  ComposerCompactSelectPill(
                    value: _formatDurationChip(m),
                    highlighted: state.durationMinutes == m,
                    onTap: () => notifier.setDuration(m),
                  ),
              ],
            ),
          ),
        ),

        // ── E. Join Policy ──────────────────────────────────────────────────
        Padding(
          padding: block,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ComposerSectionLabel(
                label: AppLocalizations.of(context).game_join_policy,
              ),
              const SizedBox(height: DabblerSpacing.space3),
              Wrap(
                spacing: DabblerSpacing.space3,
                runSpacing: DabblerSpacing.space3,
                children: [
                  for (final entry in [
                    ('open', AppLocalizations.of(context).game_join_open),
                    ('request', AppLocalizations.of(context).game_join_request),
                    ('invite', AppLocalizations.of(context).game_join_invite),
                    ('link', AppLocalizations.of(context).game_join_link),
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
        const DabblerDivider(),

        // ── F. Visibility ───────────────────────────────────────────────────
        Padding(
          padding: block,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ComposerSectionLabel(
                label: AppLocalizations.of(context).game_visibility,
              ),
              const SizedBox(height: DabblerSpacing.space3),
              Wrap(
                spacing: DabblerSpacing.space3,
                runSpacing: DabblerSpacing.space3,
                children: [
                  for (final entry in [
                    (
                      'public',
                      AppLocalizations.of(context).composer_vis_public,
                    ),
                    (
                      'followers',
                      AppLocalizations.of(context).composer_vis_followers,
                    ),
                    (
                      'private',
                      AppLocalizations.of(context).composer_vis_private,
                    ),
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
        const DabblerDivider(),

        // ── G. Skill Level ──────────────────────────────────────────────────
        Padding(
          padding: gutter,
          child: ComposerSettingsRow(
            icon: 'medal-star',
            title: AppLocalizations.of(context).game_skill_level,
            subtitle: AppLocalizations.of(context).game_skill_sub,
            trailing: ComposerSelectPill(
              value:
                  state.skillLevel ??
                  AppLocalizations.of(context).game_any_level,
              caret: ComposerSelectCaret.down,
              onTap: () => _openSkillPicker(context),
            ),
          ),
        ),

        // ── H. Players ──────────────────────────────────────────────────────
        Padding(
          padding: gutter,
          child: ComposerSettingsRow(
            icon: 'people',
            title: AppLocalizations.of(context).game_players,
            subtitle: AppLocalizations.of(context).game_players_sub,
            trailing: Wrap(
              spacing: DabblerSpacing.space2,
              children: [
                DabblerStepperPill(
                  value: state.minPlayers ?? state.requiredPlayers ?? 2,
                  min: 1,
                  decreaseLabel: AppLocalizations.of(context).game_fewer_min,
                  increaseLabel: AppLocalizations.of(context).game_more_min,
                  onChanged: notifier.setMinPlayers,
                ),
                DabblerStepperPill(
                  value: state.maxPlayers ?? state.requiredPlayers ?? 10,
                  min: 1,
                  decreaseLabel: AppLocalizations.of(context).game_fewer_max,
                  increaseLabel: AppLocalizations.of(context).game_more_max,
                  onChanged: notifier.setMaxPlayers,
                ),
              ],
            ),
          ),
        ),

        // ── Options ─────────────────────────────────────────────────────────
        Padding(
          padding: gutter,
          child: Column(
            children: [
              ComposerSettingsRow(
                icon: 'profile-2user',
                title: AppLocalizations.of(context).game_waitlist,
                subtitle: AppLocalizations.of(context).game_waitlist_sub,
                trailing: ComposerToggle(
                  value: state.allowWaitlist,
                  onChanged: (_) => notifier.toggleWaitlist(),
                ),
              ),
              ComposerSettingsRow(
                icon: 'eye',
                title: AppLocalizations.of(context).game_spectators,
                subtitle: AppLocalizations.of(context).game_spectators_sub,
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
          padding: block,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ComposerSectionLabel(
                label: AppLocalizations.of(context).game_details,
              ),
              const SizedBox(height: DabblerSpacing.space3),
              ComposerGlassInput(
                controller: _titleController,
                hint: AppLocalizations.of(context).game_title_hint,
                onChanged: notifier.setTitle,
              ),
              const SizedBox(height: DabblerSpacing.space3),
              ComposerGlassInput(
                controller: _descController,
                hint: AppLocalizations.of(context).game_note_hint,
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
    if (date == null) return AppLocalizations.of(context).game_date;
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return AppLocalizations.of(context).game_today;
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return AppLocalizations.of(context).game_tomorrow;
    }
    return DateFormat('MMM d').format(date);
  }

  String _formatTimeChip(BuildContext context, TimeOfDay? time) {
    if (time == null) return AppLocalizations.of(context).game_time;
    return DabblerTimeFormat.format(time);
  }

  String _formatDurationChip(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String _venueLabel(_ComposerState state) {
    if (state.venueSpaceId == null)
      return AppLocalizations.of(context).composer_select;
    return [
      state.venueName,
      state.venueSpaceName,
    ].whereType<String>().join(' · ');
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

    final l = AppLocalizations.of(context);
    final pending = ValueNotifier<Map<String, dynamic>?>(
      notifier.variants.where((v) => v['id'] == state.variantId).firstOrNull,
    );
    await showComposerSheet<void>(
      context,
      title: l.composer_format_title(state.sportNameEn ?? ''),
      confirm: ComposerSheetConfirm(
        label: l.composer_confirm,
        onTap: () {
          final v = pending.value;
          if (v != null) notifier.selectVariant(v);
          Navigator.of(context).maybePop();
        },
      ),
      builder: (_) =>
          ComposerVariantSheet(variants: notifier.variants, pending: pending),
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

    await showComposerSportSheet(
      context,
      title: AppLocalizations.of(context).composer_which_sport,
      sportsProvider: activeChallengeSportsByProfileCountryProvider,
      selected: selectedSport,
      onConfirm: (sport) => notifier.selectSport({
        'id': sport.id,
        'name_en': sport.nameEn,
        'emoji': sport.emoji,
        'sport_key': sport.sportKey,
        'color_code': sport.colorCode,
      }),
    );
  }

  /// Step 1 of the design's date and time flow
  /// (`Home Feed.dc.html:1070-1100`): the calendar, then — on Continue — the
  /// time step. [timeOnly] opens the time step directly ("Kickoff time").
  Future<void> _pickDate(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final notifier = ref.read(_gameComposerProvider.notifier);
    final pending = ValueNotifier<DateTime?>(
      ref.read(_gameComposerProvider).selectedDate,
    );
    final canContinue = ValueNotifier<bool>(pending.value != null);
    pending.addListener(() => canContinue.value = pending.value != null);
    var advance = false;
    await showComposerSheet<void>(
      context,
      title: l.composer_pick_date,
      subtitle: l.composer_step_1,
      confirm: ComposerSheetConfirm(
        label: l.composer_continue_time,
        enabledWhen: canContinue,
        onTap: () {
          final d = pending.value;
          if (d == null) return;
          notifier.selectDate(d);
          advance = true;
          Navigator.of(context).maybePop();
        },
      ),
      builder: (_) => ComposerDateSheet(
        first: now,
        last: now.add(const Duration(days: 365)),
        pending: pending,
      ),
    );
    if (advance && context.mounted) {
      await _pickTime(context, step: 2);
    }
  }

  Future<void> _pickTime(BuildContext context, {int? step}) async {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(_gameComposerProvider.notifier);
    final pending = ValueNotifier<TimeOfDay>(
      ref.read(_gameComposerProvider).selectedTime ??
          const TimeOfDay(hour: 18, minute: 0),
    );
    await showComposerSheet<void>(
      context,
      title: l.composer_pick_time,
      subtitle: step == 2 ? l.composer_step_2 : l.composer_kickoff_time,
      confirm: ComposerSheetConfirm(
        label: l.composer_confirm,
        onTap: () {
          notifier.selectTime(pending.value);
          Navigator.of(context).maybePop();
        },
      ),
      builder: (_) => ComposerTimeSheet(pending: pending),
    );
  }

  Future<void> _openVenuePicker(BuildContext context) async {
    final notifier = ref.read(_gameComposerProvider.notifier);
    await notifier.loadVenueSpaces();
    final spaces = notifier.venueSpaces;
    if (!context.mounted) return;

    await showComposerSheet<void>(
      context,
      title: AppLocalizations.of(context).game_select_venue,
      builder: (_) => _VenuePickerSheet(
        spaces: spaces,
        onSelect: notifier.selectVenueSpace,
        onClear: notifier.clearVenue,
        canClear: ref.read(_gameComposerProvider).venueSpaceId != null,
      ),
    );
  }

  Future<void> _openSkillPicker(BuildContext context) async {
    await showComposerSheet<void>(
      context,
      title: AppLocalizations.of(context).game_skill_level,
      builder: (_) => _SkillPickerSheet(
        onSelect: ref.read(_gameComposerProvider.notifier).selectSkillLevel,
        onClear: ref.read(_gameComposerProvider.notifier).clearSkill,
        canClear: ref.read(_gameComposerProvider).skillLevel != null,
      ),
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
      return const SizedBox(
        height: DabblerSizing.touchTargetMin,
        child: Center(child: DabblerSpinner(size: DabblerSpinnerSize.sm)),
      );
    }
    if (sports.isEmpty) {
      return SizedBox(
        height: DabblerSizing.touchTargetMin,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: DabblerText(
            AppLocalizations.of(context).composer_sports_none,
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
        ),
      );
    }
    final colors = DabblerColors.of(context);
    return Wrap(
      spacing: DabblerSpacing.space3,
      runSpacing: DabblerSpacing.space3,
      children: [
        for (final sport in sports)
          DabblerSelectableCard(
            layout: DabblerSelectableCardLayout.tile,
            title:
                sport['name_en'] as String? ??
                AppLocalizations.of(context).game_sport,
            leading: DabblerSportIcon.fromKey(
              ((sport['sport_key'] as String?) ?? '').replaceAll('_', '-'),
              size: DabblerSizing.iconLg,
              color: colors.textPrimary,
            ),
            selected: (sport['id'] as String) == selectedSportId,
            onChanged: (_) => onSelect(sport),
            semanticLabel:
                'Sport: ${sport['name_en'] ?? AppLocalizations.of(context).game_sport}, tap to select',
          ),
      ],
    );
  }
}

// ─── Picker sheets ────────────────────────────────────────────────────────────

class ComposerVariantSheet extends StatelessWidget {
  const ComposerVariantSheet({required this.variants, required this.pending});

  final List<Map<String, dynamic>> variants;
  final ValueNotifier<Map<String, dynamic>?> pending;

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space8),
        child: ComposerCenteredState.message(
          AppLocalizations.of(context).game_no_formats,
        ),
      );
    }
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: pending,
      builder: (context, current, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in variants)
            ComposerPickerRow(
              title: v['name_en'] as String,
              subtitle: (v['required_players'] as int?) != null
                  ? AppLocalizations.of(
                      context,
                    ).composer_players_count(v['required_players'] as int)
                  : null,
              selected: current?['id'] == v['id'],
              onTap: () => pending.value = v,
            ),
        ],
      ),
    );
  }
}

class ComposerDateSheet extends StatefulWidget {
  const ComposerDateSheet({
    required this.first,
    required this.last,
    required this.pending,
  });

  final DateTime first;
  final DateTime last;
  final ValueNotifier<DateTime?> pending;

  @override
  State<ComposerDateSheet> createState() => _ComposerDateSheetState();
}

class _ComposerDateSheetState extends State<ComposerDateSheet> {
  late DateTime _month = DateTime(
    (widget.pending.value ?? widget.first).year,
    (widget.pending.value ?? widget.first).month,
  );

  @override
  Widget build(BuildContext context) {
    return DabblerCalendar(
      month: _month,
      selected: <DateTime>{
        if (widget.pending.value != null) widget.pending.value!,
      },
      minimum: widget.first,
      maximum: widget.last,
      showActions: false,
      onSelect: (d) => setState(() => widget.pending.value = d),
      onMonthChanged: (m) => setState(() => _month = m),
    );
  }
}

class ComposerTimeSheet extends StatefulWidget {
  const ComposerTimeSheet({required this.pending});

  final ValueNotifier<TimeOfDay> pending;

  @override
  State<ComposerTimeSheet> createState() => _ComposerTimeSheetState();
}

class _ComposerTimeSheetState extends State<ComposerTimeSheet> {
  @override
  Widget build(BuildContext context) {
    return DabblerTimePicker(
      value: widget.pending.value,
      showActions: false,
      onChanged: (t) => setState(() => widget.pending.value = t),
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
      return venueName.contains(q) || spaceName.contains(q) || area.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final hasAnySpaces = widget.spaces.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.canClear)
          ComposerClearRow(
            onClear: () {
              widget.onClear();
              Navigator.pop(context);
            },
          ),
        // Search — only shown when there are spaces to filter
        if (hasAnySpaces)
          ComposerSearchField(
            controller: _searchController,
            placeholder: 'Search venues, spaces or area…',
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ComposerScrollArea(
          fraction: 0.5,
          child: !hasAnySpaces
              ? const ComposerCenteredState.message(
                  'No venues available for this format',
                )
              : filtered.isEmpty
              ? ComposerCenteredState.message(
                  AppLocalizations.of(context).game_no_matches,
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final sp = filtered[i];
                    final venue =
                        sp['venue'] as Map<String, dynamic>? ?? const {};
                    final venueName =
                        venue['name_en'] as String? ??
                        AppLocalizations.of(context).composer_venue;
                    final area = venue['area'] as String?;
                    final spaceName = sp['name_en'] as String?;
                    return ComposerPickerRow(
                      icon: 'location',
                      title:
                          '$venueName'
                          '${spaceName != null ? ' · $spaceName' : ''}',
                      subtitle: area,
                      onTap: () {
                        widget.onSelect(sp);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canClear)
          ComposerClearRow(
            onClear: () {
              onClear();
              Navigator.pop(context);
            },
          ),
        for (final l in _levels)
          ComposerPickerRow(
            title: l.$1,
            subtitle: l.$3,
            trailingText: l.$2,
            onTap: () {
              onSelect(l.$1);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}
