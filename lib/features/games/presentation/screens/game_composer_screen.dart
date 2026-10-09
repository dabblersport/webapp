import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_names.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_parts.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_sheet_page.dart';
import 'package:dabbler/features/games/presentation/widgets/game_create_gate.dart';
import 'package:dabbler/features/games/presentation/widgets/game_create_guard.dart';
import 'package:dabbler/features/games/presentation/widgets/game_composer_sheets.dart';
import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show activeChallengeSportsByProfileCountryProvider;
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';

// ─── Errors ───────────────────────────────────────────────────────────────────

/// Why a Create game load / submit failed. The notifier holds the code (and
/// its data); the widget turns it into words with `AppLocalizations`, so no
/// English text lives in the notifier (KAN-477).
enum GameComposerErrorCode {
  loadFailed,
  dailyLimit,
  sportUnavailable,
  invalidFormat,
  invalidTimeRange,
  profileIncomplete,
  notEditable,
  playerRange,
  playerCountMin,
  priceRequired,

  /// A failure with no code of its own; shows the server's own text.
  unknown,
}

/// A [GameComposerErrorCode] with the data its message needs.
class GameComposerError {
  const GameComposerError(this.code, {this.resetAt, this.raw});

  final GameComposerErrorCode code;

  /// [GameComposerErrorCode.dailyLimit]: when the daily limit resets.
  final DateTime? resetAt;

  /// [GameComposerErrorCode.unknown]: the server's text, shown as it is.
  final String? raw;

  /// The code for a server error message (`rpc_create_game` / `rpc_update_game`
  /// raise these as the exception message); anything else is [unknown] and
  /// keeps its text.
  factory GameComposerError.fromServer(String message) => switch (message) {
    'sport_not_challenge_eligible' => const GameComposerError(
      GameComposerErrorCode.sportUnavailable,
    ),
    'invalid_sport_variant' => const GameComposerError(
      GameComposerErrorCode.invalidFormat,
    ),
    'invalid_time_range' => const GameComposerError(
      GameComposerErrorCode.invalidTimeRange,
    ),
    'creator_profile_not_found' => const GameComposerError(
      GameComposerErrorCode.profileIncomplete,
    ),
    'not_host_or_not_found' => const GameComposerError(
      GameComposerErrorCode.notEditable,
    ),
    'invalid_player_range' => const GameComposerError(
      GameComposerErrorCode.playerRange,
    ),
    'price_required' => const GameComposerError(
      GameComposerErrorCode.priceRequired,
    ),
    'invalid_min_players' || 'invalid_max_players' => const GameComposerError(
      GameComposerErrorCode.playerCountMin,
    ),
    _ => GameComposerError(GameComposerErrorCode.unknown, raw: message),
  };

  /// The message in [l]'s language; [locale] formats the daily-limit reset.
  String text(AppLocalizations l, String locale) => switch (code) {
    GameComposerErrorCode.loadFailed => l.game_load_failed,
    GameComposerErrorCode.dailyLimit => l.game_error_daily_limit(
      DateFormat(
        'MMM d, HH:mm',
        locale,
      ).format(resetAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    ),
    GameComposerErrorCode.sportUnavailable => l.game_error_sport_unavailable,
    GameComposerErrorCode.invalidFormat => l.game_error_invalid_format,
    GameComposerErrorCode.invalidTimeRange => l.game_error_invalid_time_range,
    GameComposerErrorCode.profileIncomplete => l.game_error_profile_incomplete,
    GameComposerErrorCode.notEditable => l.game_error_not_editable,
    GameComposerErrorCode.playerRange => l.game_error_player_range,
    GameComposerErrorCode.playerCountMin => l.game_error_player_count_min,
    GameComposerErrorCode.priceRequired => l.game_price_required,
    GameComposerErrorCode.unknown => raw ?? '',
  };
}

// ─── The sheet ────────────────────────────────────────────────────────────────

/// Opens Create game (or, with [editGameId], Edit game) as the design's sheet,
/// exactly as Create meet-up's `showMeetupComposerSheet` does: the DS sheet on
/// the page colour, content-sized up to 94% over the scrim, a scrim tap or
/// Cancel closing it (KAN-475). Every entry point calls this; the routes remain
/// for deep links and draw the same sheet (`GameComposerSheetPage`).
///
/// Create is guarded as the routes' redirects were: a profile the feature
/// flags refuse (`gameCreationAllowed`) gets the generic refusal and the form
/// never opens; the persona rule is `GameCreateGate`'s, inside the sheet.
/// Editing has no gate, as its route had none (the server stays the authority).
/// Resolves to true once the game was saved.
Future<bool?> showGameComposerSheet(
  BuildContext context, {
  String? editGameId,
}) {
  final l = AppLocalizations.of(context);
  final editing = editGameId != null;
  if (!editing &&
      !gameCreationAllowedFor(
        ProviderScope.containerOf(context, listen: false),
      )) {
    DabblerToastProvider.maybeOf(context)?.show(
      DabblerToastSpec(
        message: l.game_err_create_refused,
        tone: DabblerToastTone.error,
      ),
    );
    return Future<bool?>.value();
  }
  return showDabblerSheet<bool>(
    context: context,
    // `max-height: 94%`, `height: auto` (`sheetP94`), as Create meet-up.
    detent: DabblerSheetDetent.content,
    contentMaxFraction: DabblerSheet.contentMaxFractionFull,
    pageBackground: true,
    showCloseButton: false,
    title: editing ? l.game_edit : l.game_create,
    titleWidget: GameComposerSheetTitle(editing: editing),
    headerActionBuilder: (sheetContext) => GameComposerCancel(
      onPressed: () => Navigator.of(sheetContext).maybePop(),
    ),
    builder: (_) => editing
        ? GameComposerScreen(editGameId: editGameId)
        : const GameCreateGate(child: GameComposerScreen()),
  );
}

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
    this.variantNameAr,
    this.requiredPlayers,
    this.selectedDate,
    this.selectedTime,
    this.durationMinutes = 60,
    this.venueSpaceId,
    this.venueName,
    this.venueSpaceName,
    this.venueNameAr,
    this.venueSpaceNameAr,
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
    this.priceText = '',
    this.priceError = false,
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

  /// Display-only Arabic names (KAN-484); never sent to the server.
  final String? variantNameAr;
  final int? requiredPlayers;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final int durationMinutes;
  final String? venueSpaceId;
  final String? venueName;
  final String? venueSpaceName;
  final String? venueNameAr;
  final String? venueSpaceNameAr;
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

  /// What the host typed in the price field (AED per player). Required: the
  /// game cannot be created or saved without a value, 0 meaning free.
  final String priceText;

  /// Shown once a submit was refused for a missing / invalid price.
  final bool priceError;
  final bool isSubmitting;
  final GameComposerError? error;

  bool get isEditing => editingGameId != null;

  /// The typed price, or null when empty / not a non-negative number.
  double? get priceAed {
    final v = double.tryParse(priceText.trim().replaceAll(',', '.'));
    return v == null || v.isNaN || v.isInfinite || v < 0 ? null : v;
  }

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
    String? variantNameAr,
    int? requiredPlayers,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    int? durationMinutes,
    String? venueSpaceId,
    String? venueName,
    String? venueSpaceName,
    String? venueNameAr,
    String? venueSpaceNameAr,
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
    String? priceText,
    bool? priceError,
    bool? isSubmitting,
    GameComposerError? error,
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
      variantNameAr: clearVariant ? null : variantNameAr ?? this.variantNameAr,
      requiredPlayers: clearVariant
          ? null
          : requiredPlayers ?? this.requiredPlayers,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      venueSpaceId: clearVenue ? null : venueSpaceId ?? this.venueSpaceId,
      venueName: clearVenue ? null : venueName ?? this.venueName,
      venueSpaceName: clearVenue ? null : venueSpaceName ?? this.venueSpaceName,
      venueNameAr: clearVenue ? null : venueNameAr ?? this.venueNameAr,
      venueSpaceNameAr: clearVenue
          ? null
          : venueSpaceNameAr ?? this.venueSpaceNameAr,
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
      priceText: priceText ?? this.priceText,
      priceError: priceError ?? this.priceError,
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
          .select('id, sport_key, name_en, name_ar, emoji, color_code')
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
        priceText: _priceTextFor(row['price_aed'] as num?),
      );

      // Warm the picker caches so format/venue sheets open populated.
      await loadVariants(row['sport_id'] as String);
      await loadVenueSpaces();
      _resolveArabicNames();
    } catch (_) {
      state = state.copyWith(
        error: const GameComposerError(GameComposerErrorCode.loadFailed),
      );
    }
  }

  /// Edit mode: `v_game_card` carries English names only, so the Arabic
  /// display names come from the warmed caches, matched by id.
  void _resolveArabicNames() {
    Map<String, dynamic>? byId(List<Map<String, dynamic>> rows, String? id) {
      for (final r in rows) {
        if (id != null && r['id'] == id) return r;
      }
      return null;
    }

    final variant = byId(_variants, state.variantId);
    final space = byId(_venueSpaces, state.venueSpaceId);
    final venue = space?['venue'] as Map<String, dynamic>?;
    state = state.copyWith(
      variantNameAr: variant?['name_ar'] as String?,
      venueNameAr: venue?['name_ar'] as String?,
      venueSpaceNameAr: space?['name_ar'] as String?,
    );
  }

  /// Reverse of [selectSkillLevel]'s (min, max) mapping.
  String? _skillLabelFor(int? min, int? max) => switch ((min, max)) {
    (1, 3) => 'Beginner',
    (4, 6) => 'Intermediate',
    // (7, 10) is what the picker writes; (7, 8) and (9, 10) are the old
    // Advanced and Pro rows, which open as Advanced.
    (7, 10) || (7, 8) || (9, 10) => 'Advanced',
    _ => null,
  };

  Future<void> loadVariants(String sportId) async {
    try {
      final rows = await _db
          .from(SupabaseConfig.sportVariantsTable)
          .select(
            'id, variant_key, name_en, name_ar, required_players, '
            'players_per_side',
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
            'id, name_en, name_ar, sport_id, sport_variant_keys, '
            'venue:venues(id, name_en, name_ar, area)',
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
      variantNameAr: variant['name_ar'] as String?,
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
      venueNameAr: venue['name_ar'] as String?,
      venueSpaceNameAr: space['name_ar'] as String?,
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
      'Advanced' => (7, 10),
      _ => (1, 10),
    };
    state = state.copyWith(skillLevel: level, minSkill: min, maxSkill: max);
  }

  void clearSkill() => state = state.copyWith(clearSkill: true);

  /// A stored price as the field shows it: `50`, `12.5`; empty when never set.
  static String _priceTextFor(num? v) {
    if (v == null) return '';
    final d = v.toDouble();
    return d == d.roundToDouble() ? d.round().toString() : d.toString();
  }

  /// Live check: an emptied or non-numeric price shows its error at once.
  void setPriceText(String v) {
    final next = state.copyWith(priceText: v);
    state = next.copyWith(priceError: next.priceAed == null);
  }

  /// False (and the field shows its error) while the price is missing.
  bool validatePrice() {
    if (state.priceAed != null) return true;
    state = state.copyWith(priceError: true);
    return false;
  }

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
          state = state.copyWith(
            isSubmitting: false,
            error: GameComposerError(
              GameComposerErrorCode.dailyLimit,
              resetAt: cooldown.resetAt,
            ),
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
          'p_price_aed': state.priceAed,
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
        'p_price_aed': state.priceAed,
      };

      await _db.rpc(SupabaseConfig.rpcCreateGameFn, params: params);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on PostgrestException catch (e) {
      final msg = GameComposerError.fromServer(e.message);
      state = state.copyWith(isSubmitting: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: GameComposerError(
          GameComposerErrorCode.unknown,
          raw: e.toString().replaceFirst('Exception: ', ''),
        ),
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
  final _priceController = TextEditingController();

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
        _priceController.text = s.priceText;
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
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!ref.read(_gameComposerProvider.notifier).validatePrice()) return;
    final ok = await ref.read(_gameComposerProvider.notifier).submit();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      final err = ref.read(_gameComposerProvider).error;
      DabblerToastProvider.of(context).show(
        DabblerToastSpec(
          message:
              err?.text(
                AppLocalizations.of(context),
                Localizations.localeOf(context).toString(),
              ) ??
              (_isEditing
                  ? AppLocalizations.of(context).game_save_failed
                  : AppLocalizations.of(context).game_create_failed),
          tone: DabblerToastTone.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_gameComposerProvider);
    final notifier = ref.read(_gameComposerProvider.notifier);
    final l = AppLocalizations.of(context);

    // The Create game frame's scroller (`Home Feed.dc.html:934-1061`): one
    // column, `gap:12px`; the DS sheet supplies the 18 gutters and the 18 at
    // the foot, the header is the sheet's sticky title row.
    //
    // KAN-473: the sub-sheets open from inside the composer frame scope, so
    // [showGamePickSheet] draws the design's pick-sheet frame (header
    // hairline, framed search, brand-ink chosen rows); the body below uses no
    // frame-aware kit widget, so it is unchanged.
    return ComposerFrameScope(
      child: Builder(
        builder: (context) => DabblerSheetBody(
          children: <Widget>[
            GameSectionLabel(l.game_sport, first: true),
            // Sport is locked in edit mode — capacity and the roster derive from
            // the sport/format chosen at creation.
            DabblerInert(
              inert: _isEditing,
              child: _SportTiles(
                sports: state.sports,
                loaded: state.sportsLoaded,
                selectedSportId: state.sportId,
                onSelect: notifier.selectSport,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DabblerComposerRow(
                  icon: 'grid-2',
                  title: l.game_format,
                  subtitle: l.game_format_sub,
                  // Locked until a sport is picked (`formatLabel`, `:3413`), and
                  // in edit mode.
                  trailing: GameSelectPill(
                    label: state.variantNameEn != null
                        ? localizedNameFor(
                            Localizations.localeOf(context).languageCode,
                            nameEn: state.variantNameEn,
                            nameAr: state.variantNameAr,
                          )
                        : (state.sportId == null
                              ? l.game_format_locked
                              : l.game_select_format),
                    state: state.sportId == null || _isEditing
                        ? GamePillState.locked
                        : state.variantNameEn == null
                        ? GamePillState.idle
                        : GamePillState.chosen,
                    onTap: () => _openVariantPicker(context),
                  ),
                ),
                DabblerComposerRow(
                  icon: 'location',
                  title: l.composer_venue,
                  subtitle: l.game_venue_sub,
                  // A venue SPACE (ruling 4): disabled until a format is picked,
                  // then the venue name in ink.
                  trailing: GameSelectPill(
                    label: _venueLabel(state),
                    state: state.variantId == null
                        ? GamePillState.locked
                        : state.venueSpaceId == null
                        ? GamePillState.idle
                        : GamePillState.chosen,
                    onTap: () => _openVenuePicker(context),
                  ),
                ),
                DabblerComposerRow(
                  icon: 'calendar',
                  title: l.game_date_time,
                  subtitle: l.game_date_time_sub,
                  trailing: Wrap(
                    spacing: DabblerSpacing.space2,
                    runSpacing: DabblerSpacing.space2,
                    children: <Widget>[
                      GameSelectPill(
                        label: _formatDateChip(state.selectedDate),
                        state: state.selectedDate == null
                            ? GamePillState.idle
                            : GamePillState.chosen,
                        onTap: () => _pickDate(context),
                      ),
                      GameSelectPill(
                        label: _formatTimeChip(context, state.selectedTime),
                        state: state.selectedTime == null
                            ? GamePillState.idle
                            : GamePillState.chosen,
                        onTap: () => _pickTime(context),
                      ),
                    ],
                  ),
                ),
                DabblerComposerRow(
                  icon: 'timer',
                  title: l.game_duration,
                  subtitle: l.game_duration_sub,
                  trailing: GameOptionPills<int>(
                    options: <(int, String)>[
                      for (final m in {30, 60, 120, state.durationMinutes})
                        (m, _formatDurationChip(l, m)),
                    ],
                    selected: state.durationMinutes,
                    onSelect: notifier.setDuration,
                  ),
                ),
              ],
            ),
            GameSectionLabel(l.game_join_policy),
            GameOptionPills<String>(
              options: <(String, String)>[
                ('open', l.game_join_open),
                ('request', l.game_join_request),
                ('invite', l.game_join_invite),
                ('link', l.game_join_link),
              ],
              selected: state.joinPolicy,
              onSelect: notifier.setJoinPolicy,
            ),
            GameSectionLabel(l.game_visibility),
            GameOptionPills<String>(
              options: <(String, String)>[
                ('public', l.composer_vis_public),
                ('followers', l.composer_vis_followers),
                ('private', l.composer_vis_private),
              ],
              selected: state.listingVisibility,
              onSelect: notifier.setVisibility,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DabblerComposerRow(
                  icon: 'medal-star',
                  title: l.game_skill_level,
                  subtitle: l.game_skill_sub,
                  // Ruling 5: the 3-level picker, "Any level" while unset.
                  trailing: GameSelectPill(
                    label: _skillText(l, state.skillLevel),
                    trailingIcon: 'arrow-circle-down',
                    state: state.skillLevel == null
                        ? GamePillState.idle
                        : GamePillState.chosen,
                    onTap: () => _openSkillPicker(context),
                  ),
                ),
                DabblerComposerRow(
                  icon: 'people',
                  title: l.game_players,
                  subtitle: l.game_players_sub,
                  trailing: Wrap(
                    spacing: DabblerSpacing.space2,
                    runSpacing: DabblerSpacing.space2,
                    children: <Widget>[
                      DabblerStepperPill(
                        value: state.minPlayers ?? state.requiredPlayers ?? 2,
                        min: 1,
                        valueLabel: (v) => '${l.game_players_min} $v',
                        decreaseLabel: l.game_fewer_min,
                        increaseLabel: l.game_more_min,
                        onChanged: notifier.setMinPlayers,
                      ),
                      DabblerStepperPill(
                        value: state.maxPlayers ?? state.requiredPlayers ?? 10,
                        min: 1,
                        valueLabel: (v) => '${l.game_players_max} $v',
                        decreaseLabel: l.game_fewer_max,
                        increaseLabel: l.game_more_max,
                        onChanged: notifier.setMaxPlayers,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Price (ruling 1, retained from 0f1cce48): required, 0 is free.
            GameSectionLabel(l.game_price),
            GamePriceField(
              controller: _priceController,
              showError: state.priceError,
              onChanged: notifier.setPriceText,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DabblerComposerRow(
                  icon: 'people',
                  title: l.game_waitlist,
                  subtitle: l.game_waitlist_sub,
                  trailing: DabblerToggle(
                    checked: state.allowWaitlist,
                    compactHitArea: true,
                    semanticLabel: l.game_waitlist,
                    onChanged: (_) => notifier.toggleWaitlist(),
                  ),
                ),
                DabblerComposerRow(
                  icon: 'eye',
                  title: l.game_spectators,
                  subtitle: l.game_spectators_sub,
                  trailing: DabblerToggle(
                    checked: state.allowSpectators,
                    compactHitArea: true,
                    semanticLabel: l.game_spectators,
                    onChanged: (_) => notifier.toggleSpectators(),
                  ),
                ),
              ],
            ),
            GameSectionLabel(l.game_details),
            DabblerComposerField(
              controller: _titleController,
              placeholder: l.game_title_hint,
              onChanged: notifier.setTitle,
            ),
            DabblerComposerField(
              controller: _descController,
              placeholder: l.game_note_hint,
              multiline: true,
              onChanged: notifier.setDescription,
            ),
            if (state.error != null &&
                state.error!
                    .text(l, Localizations.localeOf(context).toString())
                    .isNotEmpty)
              DabblerBanner(
                tone: DabblerBannerTone.error,
                message: state.error!.text(
                  l,
                  Localizations.localeOf(context).toString(),
                ),
              ),
            // The Create button scrolls at the end of the form (`:1060`).
            DabblerComposerSubmit(
              key: const ValueKey<String>('game-composer-submit'),
              label: _isEditing ? l.game_save_changes : l.game_create,
              enabled: state.canSubmit,
              loading: state.isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
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
    return DateFormat(
      'MMM d',
      Localizations.localeOf(context).toString(),
    ).format(date);
  }

  String _formatTimeChip(BuildContext context, TimeOfDay? time) {
    if (time == null) return AppLocalizations.of(context).game_time;
    return DabblerTimeFormat.format(time);
  }

  String _formatDurationChip(AppLocalizations l, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return l.game_duration_chip_hours_minutes(h, m);
    if (h > 0) return l.game_duration_chip_hours(h);
    return l.game_duration_chip_minutes(m);
  }

  String _venueLabel(_ComposerState state) {
    if (state.venueSpaceId == null) {
      return AppLocalizations.of(context).composer_select;
    }
    final lang = Localizations.localeOf(context).languageCode;
    return [
      localizedNameFor(
        lang,
        nameEn: state.venueName,
        nameAr: state.venueNameAr,
      ),
      localizedNameFor(
        lang,
        nameEn: state.venueSpaceName,
        nameAr: state.venueSpaceNameAr,
      ),
    ].where((n) => n.isNotEmpty).join(' · ');
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
    await showGamePickSheet<void>(
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
    await showGamePickSheet<void>(
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
      // The design's 12 gap under the header plus its body padding
      // (`padding:12px 18px 0`, `:1080`); the sheet supplies the 18 gutters.
      builder: (_) => Padding(
        padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space8),
        child: ComposerDateSheet(
          first: now,
          last: now.add(const Duration(days: 365)),
          pending: pending,
        ),
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
    await showGamePickSheet<void>(
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
      builder: (_) => Padding(
        padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space8),
        child: ComposerTimeSheet(pending: pending),
      ),
    );
  }

  /// The venue SPACE picker (ruling 4) drawn in the design's place-sheet
  /// frame (`Home Feed.dc.html:961-964`, `sheetP74`): header hairline, framed
  /// search, picker rows with the chosen tick, a header Clear and a Confirm
  /// foot that applies the pending space. What it selects is unchanged
  /// ([_ComposerNotifier.selectVenueSpace] with the same space map).
  Future<void> _openVenuePicker(BuildContext context) async {
    final notifier = ref.read(_gameComposerProvider.notifier);
    await notifier.loadVenueSpaces();
    final spaces = notifier.venueSpaces;
    if (!context.mounted) return;

    final l = AppLocalizations.of(context);
    final state = ref.read(_gameComposerProvider);
    final pending = ValueNotifier<Map<String, dynamic>?>(
      spaces.where((sp) => sp['id'] == state.venueSpaceId).firstOrNull,
    );
    final confirm = ComposerSheetConfirm(
      label: l.composer_confirm,
      onTap: () {
        final sp = pending.value;
        if (sp != null) notifier.selectVenueSpace(sp);
        Navigator.of(context).maybePop();
      },
    );
    await showGamePickSheet<void>(
      context,
      title: l.game_select_venue,
      contentMaxFraction: DabblerSheet.contentMaxFractionMedium,
      // The place sheet's header has no border (`:820`).
      headerDivider: false,
      onClear: state.venueSpaceId != null ? notifier.clearVenue : null,
      confirm: confirm,
      builder: (_) => _VenuePickerSheet(
        spaces: spaces,
        pending: pending,
        onSelect: (sp) => pending.value = sp,
        onClear: notifier.clearVenue,
        canClear: false,
      ),
    );
  }

  /// The skill sheet (ruling 5): the three levels as choice pills in the
  /// same sheet frame as the format sheet, a header Clear and a Confirm foot.
  /// The stored key and its (min, max) mapping are unchanged
  /// ([_ComposerNotifier.selectSkillLevel]).
  Future<void> _openSkillPicker(BuildContext context) async {
    final notifier = ref.read(_gameComposerProvider.notifier);
    final current = ref.read(_gameComposerProvider).skillLevel;
    final pending = ValueNotifier<String?>(current);
    await showGamePickSheet<void>(
      context,
      title: AppLocalizations.of(context).game_skill_level,
      onClear: current != null ? notifier.clearSkill : null,
      confirm: ComposerSheetConfirm(
        label: AppLocalizations.of(context).composer_confirm,
        onTap: () {
          final v = pending.value;
          if (v != null && v != current) notifier.selectSkillLevel(v);
          Navigator.of(context).maybePop();
        },
      ),
      builder: (_) => GameSkillPickerSheet(
        selected: current,
        onSelect: (v) => pending.value = v,
        onClear: notifier.clearSkill,
        canClear: false,
      ),
    );
  }
}

// ─── Sport tiles ─────────────────────────────────────────────────────────────

/// The frame's sport tiles (`Home Feed.dc.html:936-942`): the database's
/// challenge sports with their `sports.emoji` (ruling 2), as Create meet-up.
class _SportTiles extends StatelessWidget {
  const _SportTiles({
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
    final l = AppLocalizations.of(context);
    if (!loaded) {
      return const SizedBox(
        height: DabblerEmojiTile.side,
        child: Center(child: DabblerSpinner(size: DabblerSpinnerSize.sm)),
      );
    }
    if (sports.isEmpty) {
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
        for (final sport in sports) _sportTile(context, l, sport),
      ],
    );
  }

  /// One sport tile: the name in the viewer's language, and the screen-reader
  /// sentence from the ARB ("Sport: Football, tap to select").
  Widget _sportTile(
    BuildContext context,
    AppLocalizations l,
    Map<String, dynamic> sport,
  ) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final nameAr = (sport['name_ar'] as String?)?.trim();
    final name = ar && nameAr != null && nameAr.isNotEmpty
        ? nameAr
        : sport['name_en'] as String? ?? l.game_sport;
    return DabblerEmojiTile(
      emoji: sport['emoji'] as String? ?? '',
      label: name,
      semanticLabel: l.game_sport_tile_semantic(name),
      selected: (sport['id'] as String) == selectedSportId,
      onTap: () => onSelect(sport),
    );
  }
}

// ─── Picker sheets ────────────────────────────────────────────────────────────

class ComposerVariantSheet extends StatelessWidget {
  const ComposerVariantSheet({
    super.key,
    required this.variants,
    required this.pending,
  });

  final List<Map<String, dynamic>> variants;
  final ValueNotifier<Map<String, dynamic>?> pending;

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) {
      return ComposerCenteredState.message(
        AppLocalizations.of(context).game_no_formats,
      );
    }
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: pending,
      // The design's 12 body gap plus the list's `padding-block:6px`
      // (`:1108`) above the rows, measured 31 from Cancel to row 0 (KAN-473
      // C1); below, the 30 to the pill is the DS footer's own spacing.
      builder: (context, current, _) => Padding(
        padding: const EdgeInsetsDirectional.only(
          top:
              DabblerSpacing.space4 +
              DabblerSpacing.space2 +
              DabblerSizing.borderDefault,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in variants)
              GameSheetOptionRow(
                title: localizedRowName(
                  v,
                  Localizations.localeOf(context).languageCode,
                ),
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
      ),
    );
  }
}

class ComposerDateSheet extends StatefulWidget {
  const ComposerDateSheet({
    super.key,
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
  const ComposerTimeSheet({super.key, required this.pending});

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
    this.pending,
  });

  final List<Map<String, dynamic>> spaces;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback onClear;
  final bool canClear;

  /// The space picked but not yet confirmed; drawn with the chosen tick.
  final ValueListenable<Map<String, dynamic>?>? pending;

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
    return widget.spaces.where((sp) {
      final venue = sp['venue'] as Map<String, dynamic>? ?? const {};
      return namesMatch(_query, <String?>[
        venue['name_en'] as String?,
        venue['name_ar'] as String?,
        sp['name_en'] as String?,
        sp['name_ar'] as String?,
        venue['area'] as String?,
      ]);
    }).toList();
  }

  Widget _row(BuildContext context, Map<String, dynamic> sp, Object? chosen) {
    final venue = sp['venue'] as Map<String, dynamic>? ?? const {};
    final lang = Localizations.localeOf(context).languageCode;
    final venueLocal = localizedRowName(venue, lang);
    final venueName = venueLocal.isNotEmpty
        ? venueLocal
        : AppLocalizations.of(context).composer_venue;
    final spaceLocal = localizedRowName(sp, lang);
    final spaceName = spaceLocal.isEmpty ? null : spaceLocal;
    return GameSheetOptionRow(
      key: ValueKey<String>('game-venue-space-${sp['id']}'),
      icon: 'location',
      verticalPadding: GameSheetOptionRow.placePadding,
      subtitleStyle: DabblerType.caption1,
      title: '$venueName${spaceName != null ? ' · $spaceName' : ''}',
      subtitle: venue['area'] as String?,
      selected: chosen != null && chosen == sp['id'],
      onTap: () => widget.onSelect(sp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final hasAnySpaces = widget.spaces.isNotEmpty;
    final pending =
        widget.pending ?? ValueNotifier<Map<String, dynamic>?>(null);

    // The place sheet's body (`Home Feed.dc.html:818-870`): the framed search
    // box, then the rows. A bounded list only when it would not fit.
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
        const SizedBox(height: DabblerSpacing.space4),
        // Search — only shown when there are spaces to filter
        if (hasAnySpaces)
          ComposerSearchField(
            controller: _searchController,
            placeholder: AppLocalizations.of(
              context,
            ).game_venue_search_placeholder,
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        // The 12 between the search and the list (`:840`).
        if (hasAnySpaces) const SizedBox(height: DabblerSpacing.space4),
        if (!hasAnySpaces)
          ComposerCenteredState.message(
            AppLocalizations.of(context).game_venue_none,
          )
        else if (filtered.isEmpty)
          ComposerCenteredState.message(
            AppLocalizations.of(context).game_no_matches,
          )
        else
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: pending,
            builder: (context, current, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final sp in filtered) _row(context, sp, current?['id']),
              ],
            ),
          ),
      ],
    );
  }
}

/// The skill sheet (ruling 5): Beginner 1–3, Intermediate 4–6, Advanced
/// 7–10 as choice pills styled like the join-policy pills
/// (`Home Feed.dc.html:1001-1002`), each level's range and line under them.
class GameSkillPickerSheet extends StatefulWidget {
  const GameSkillPickerSheet({
    super.key,
    required this.onSelect,
    required this.onClear,
    required this.canClear,
    this.selected,
  });

  /// Called with the state key of the tapped pill.
  final void Function(String) onSelect;
  final VoidCallback onClear;
  final bool canClear;

  /// The level chosen when the sheet opens.
  final String? selected;

  /// (state key, range, localised title, localised subtitle). The state key
  /// stays the English word ([selectSkillLevel] and `_skillLabelFor` use it).
  static List<(String, String, String, String)> _levels(AppLocalizations l) => [
    ('Beginner', '1–3', l.listing_skill_beginner, l.skill_sub_beginner),
    (
      'Intermediate',
      '4–6',
      l.listing_skill_intermediate,
      l.skill_sub_intermediate,
    ),
    ('Advanced', '7–10', l.listing_skill_advanced, l.skill_sub_advanced),
  ];

  @override
  State<GameSkillPickerSheet> createState() => _GameSkillPickerSheetState();
}

class _GameSkillPickerSheetState extends State<GameSkillPickerSheet> {
  late String? _picked = widget.selected;

  @override
  Widget build(BuildContext context) {
    final levels = GameSkillPickerSheet._levels(AppLocalizations.of(context));
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
        Padding(
          padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space3),
          child: GameOptionPills<String>(
            options: <(String, String)>[for (final l in levels) (l.$1, l.$3)],
            selected: _picked ?? '',
            onSelect: (v) {
              setState(() => _picked = v);
              widget.onSelect(v);
            },
          ),
        ),
        const SizedBox(height: DabblerSpacing.space5),
        for (final l in levels)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: DabblerSpacing.space2,
            ),
            child: Row(
              children: [
                DabblerText(
                  // LTR isolate: "1–3" keeps its order inside Arabic text.
                  '\u2066${l.$2}\u2069',
                  style: DabblerType.caption1,
                  tone: l.$1 == _picked
                      ? DabblerTextTone.primary
                      : DabblerTextTone.secondary,
                ),
                const SizedBox(width: DabblerSpacing.space4),
                Expanded(
                  child: DabblerText(
                    l.$4,
                    style: DabblerType.footnote,
                    tone: DabblerTextTone.secondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The localised name of a stored skill key ('Beginner', 'Intermediate',
/// 'Advanced'); the "any level" words when none is chosen.
String _skillText(AppLocalizations l, String? key) => switch (key) {
  'Beginner' => l.listing_skill_beginner,
  'Intermediate' => l.listing_skill_intermediate,
  'Advanced' => l.listing_skill_advanced,
  _ => key ?? l.game_any_level,
};
