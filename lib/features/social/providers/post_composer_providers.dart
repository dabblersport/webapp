import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/language_detector.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_create_request.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

// =============================================================================
// COMPOSER STATE
// =============================================================================

/// Holds all composer field values. Managed by [PostComposerNotifier].
class PostComposerState {
  const PostComposerState({
    this.kind = PostKind.moment,
    this.visibility = PostVisibility.public,
    this.body = '',
    this.vibeId,
    this.vibeName,
    this.vibeEmoji,
    this.sportId,
    this.sportName,
    this.sportEmoji,
    this.venueId,
    this.venueName,
    this.locationName,
    this.locationTagId,
    this.geoLat,
    this.geoLng,
    this.media = const [],
    this.allowReposts = true,
    this.expiresAt,
    this.circleId,
    this.squadId,
    this.gameId,
    this.gameName,
    this.tags = const [],
    this.contentClass = 'social',
    this.originType = OriginType.manual,
    this.originId,
    this.personaTypeSnapshot,
    this.isPinned = false,
    this.isSubmitting = false,
    this.error,
  });

  final PostKind kind;
  final PostVisibility visibility;
  final String body;

  // Vibe selection
  final String? vibeId;
  final String? vibeName;
  final String? vibeEmoji;

  // Sport selection
  final String? sportId;
  final String? sportName;
  final String? sportEmoji;

  // Location
  final String? venueId;
  final String? venueName;
  final String? locationName;
  final String? locationTagId;
  final double? geoLat;
  final double? geoLng;

  // Media
  final List<dynamic> media;

  // Toggles
  final bool allowReposts;
  final DateTime? expiresAt;
  final bool isPinned;

  // Scope (for circle/squad visibility)
  final String? circleId;
  final String? squadId;

  // Game linkage
  final String? gameId;
  final String? gameName;

  // Tags (manual + auto-extracted are merged on submit)
  final List<String> tags;

  // Content classification
  final String contentClass;
  final OriginType originType;
  final String? originId;

  // Persona snapshot
  final String? personaTypeSnapshot;

  // UI state
  final bool isSubmitting;
  final String? error;

  bool get hasBody => body.trim().isNotEmpty;
  bool get hasVibe => vibeId != null;
  bool get hasSport => sportId != null;

  /// True when a Mapbox place (no DB venue) is attached.
  bool get hasLocation =>
      venueId == null && (locationName != null || geoLat != null);

  /// True when a DB venue is linked.
  bool get hasVenue => venueId != null;
  bool get hasMedia => media.isNotEmpty;
  bool get hasGame => gameId != null;
  bool get hasTags => tags.isNotEmpty;

  /// True when the post has enough content to submit.
  bool get canSubmit => hasBody || hasVibe || hasSport || hasMedia;

  PostComposerState copyWith({
    PostKind? kind,
    PostVisibility? visibility,
    String? body,
    String? vibeId,
    String? vibeName,
    String? vibeEmoji,
    String? sportId,
    String? sportName,
    String? sportEmoji,
    String? venueId,
    String? venueName,
    String? locationName,
    String? locationTagId,
    double? geoLat,
    double? geoLng,
    List<dynamic>? media,
    bool? allowReposts,
    DateTime? expiresAt,
    String? circleId,
    String? squadId,
    String? gameId,
    String? gameName,
    List<String>? tags,
    String? contentClass,
    OriginType? originType,
    String? originId,
    String? personaTypeSnapshot,
    bool? isPinned,
    bool? isSubmitting,
    String? error,
  }) {
    return PostComposerState(
      kind: kind ?? this.kind,
      visibility: visibility ?? this.visibility,
      body: body ?? this.body,
      vibeId: vibeId ?? this.vibeId,
      vibeName: vibeName ?? this.vibeName,
      vibeEmoji: vibeEmoji ?? this.vibeEmoji,
      sportId: sportId ?? this.sportId,
      sportName: sportName ?? this.sportName,
      sportEmoji: sportEmoji ?? this.sportEmoji,
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
      locationName: locationName ?? this.locationName,
      locationTagId: locationTagId ?? this.locationTagId,
      geoLat: geoLat ?? this.geoLat,
      geoLng: geoLng ?? this.geoLng,
      media: media ?? this.media,
      allowReposts: allowReposts ?? this.allowReposts,
      expiresAt: expiresAt ?? this.expiresAt,
      circleId: circleId ?? this.circleId,
      squadId: squadId ?? this.squadId,
      gameId: gameId ?? this.gameId,
      gameName: gameName ?? this.gameName,
      tags: tags ?? this.tags,
      contentClass: contentClass ?? this.contentClass,
      originType: originType ?? this.originType,
      originId: originId ?? this.originId,
      personaTypeSnapshot: personaTypeSnapshot ?? this.personaTypeSnapshot,
      isPinned: isPinned ?? this.isPinned,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

// =============================================================================
// COMPOSER NOTIFIER
// =============================================================================

class PostComposerNotifier extends StateNotifier<PostComposerState> {
  PostComposerNotifier(this._ref) : super(const PostComposerState());
  final Ref _ref;

  PostRepository get _repo => _ref.read(postRepositoryProvider);

  // ── Field Setters ───────────────────────────────────────────────────

  void setKind(PostKind kind) => state = state.copyWith(kind: kind);

  void setVisibility(PostVisibility v) => state = state.copyWith(visibility: v);

  void setBody(String body) => state = state.copyWith(body: body);

  void setVibe({required String id, String? label, String? emoji}) {
    state = state.copyWith(vibeId: id, vibeName: label, vibeEmoji: emoji);
  }

  void clearVibe() {
    // Rebuild without vibe fields — use copyWith-like manual construction
    // to null out the three vibe fields while preserving everything else.
    state = PostComposerState(
      kind: state.kind,
      visibility: state.visibility,
      body: state.body,
      sportId: state.sportId,
      sportName: state.sportName,
      sportEmoji: state.sportEmoji,
      venueId: state.venueId,
      venueName: state.venueName,
      locationName: state.locationName,
      locationTagId: state.locationTagId,
      geoLat: state.geoLat,
      geoLng: state.geoLng,
      media: state.media,
      allowReposts: state.allowReposts,
      expiresAt: state.expiresAt,
      circleId: state.circleId,
      squadId: state.squadId,
      gameId: state.gameId,
      gameName: state.gameName,
      tags: state.tags,
      contentClass: state.contentClass,
      originType: state.originType,
      originId: state.originId,
      personaTypeSnapshot: state.personaTypeSnapshot,
      isPinned: state.isPinned,
    );
  }

  void setSport({required String id, String? name, String? emoji}) {
    state = state.copyWith(sportId: id, sportName: name, sportEmoji: emoji);
  }

  void clearSport() {
    state = PostComposerState(
      kind: state.kind,
      visibility: state.visibility,
      body: state.body,
      vibeId: state.vibeId,
      vibeName: state.vibeName,
      vibeEmoji: state.vibeEmoji,
      venueId: state.venueId,
      venueName: state.venueName,
      locationName: state.locationName,
      locationTagId: state.locationTagId,
      geoLat: state.geoLat,
      geoLng: state.geoLng,
      media: state.media,
      allowReposts: state.allowReposts,
      expiresAt: state.expiresAt,
      circleId: state.circleId,
      squadId: state.squadId,
      gameId: state.gameId,
      gameName: state.gameName,
      tags: state.tags,
      contentClass: state.contentClass,
      originType: state.originType,
      originId: state.originId,
      personaTypeSnapshot: state.personaTypeSnapshot,
      isPinned: state.isPinned,
    );
  }

  void setVenue({
    required String id,
    required String name,
    double? lat,
    double? lng,
  }) {
    state = state.copyWith(
      venueId: id,
      venueName: name,
      locationName: name,
      geoLat: lat,
      geoLng: lng,
    );
  }

  void setRawLocation({required String name, double? lat, double? lng}) {
    // Clear venue-specific fields but set location_name/geo.
    state = PostComposerState(
      kind: state.kind,
      visibility: state.visibility,
      body: state.body,
      vibeId: state.vibeId,
      vibeName: state.vibeName,
      vibeEmoji: state.vibeEmoji,
      sportId: state.sportId,
      sportName: state.sportName,
      sportEmoji: state.sportEmoji,
      locationName: name,
      geoLat: lat,
      geoLng: lng,
      media: state.media,
      allowReposts: state.allowReposts,
      expiresAt: state.expiresAt,
      circleId: state.circleId,
      squadId: state.squadId,
      gameId: state.gameId,
      gameName: state.gameName,
      tags: state.tags,
      contentClass: state.contentClass,
      originType: state.originType,
      originId: state.originId,
      personaTypeSnapshot: state.personaTypeSnapshot,
      isPinned: state.isPinned,
    );
  }

  void clearLocation() {
    state = PostComposerState(
      kind: state.kind,
      visibility: state.visibility,
      body: state.body,
      vibeId: state.vibeId,
      vibeName: state.vibeName,
      vibeEmoji: state.vibeEmoji,
      sportId: state.sportId,
      sportName: state.sportName,
      sportEmoji: state.sportEmoji,
      media: state.media,
      allowReposts: state.allowReposts,
      expiresAt: state.expiresAt,
      circleId: state.circleId,
      squadId: state.squadId,
      gameId: state.gameId,
      gameName: state.gameName,
      tags: state.tags,
      contentClass: state.contentClass,
      originType: state.originType,
      originId: state.originId,
      personaTypeSnapshot: state.personaTypeSnapshot,
      isPinned: state.isPinned,
    );
  }

  /// Clears only the DB venue link, preserving any Mapbox location.
  void clearVenue() {
    state = PostComposerState(
      kind: state.kind,
      visibility: state.visibility,
      body: state.body,
      vibeId: state.vibeId,
      vibeName: state.vibeName,
      vibeEmoji: state.vibeEmoji,
      sportId: state.sportId,
      sportName: state.sportName,
      sportEmoji: state.sportEmoji,
      media: state.media,
      allowReposts: state.allowReposts,
      expiresAt: state.expiresAt,
      circleId: state.circleId,
      squadId: state.squadId,
      gameId: state.gameId,
      gameName: state.gameName,
      tags: state.tags,
      contentClass: state.contentClass,
      originType: state.originType,
      originId: state.originId,
      personaTypeSnapshot: state.personaTypeSnapshot,
      isPinned: state.isPinned,
    );
  }

  void setMedia(List<dynamic> media) => state = state.copyWith(media: media);

  void toggleAllowReposts() =>
      state = state.copyWith(allowReposts: !state.allowReposts);

  void setExpiresAt(DateTime? dt) => state = state.copyWith(expiresAt: dt);

  void setCircleId(String? id) => state = state.copyWith(circleId: id);

  void setSquadId(String? id) => state = state.copyWith(squadId: id);

  // ── NEW Setters ─────────────────────────────────────────────────────

  void setGame({required String id, required String name}) {
    state = state.copyWith(gameId: id, gameName: name);
  }

  void clearGame() {
    state = PostComposerState(
      kind: state.kind,
      visibility: state.visibility,
      body: state.body,
      vibeId: state.vibeId,
      vibeName: state.vibeName,
      vibeEmoji: state.vibeEmoji,
      sportId: state.sportId,
      sportName: state.sportName,
      sportEmoji: state.sportEmoji,
      venueId: state.venueId,
      venueName: state.venueName,
      locationName: state.locationName,
      locationTagId: state.locationTagId,
      geoLat: state.geoLat,
      geoLng: state.geoLng,
      media: state.media,
      allowReposts: state.allowReposts,
      expiresAt: state.expiresAt,
      circleId: state.circleId,
      squadId: state.squadId,
      tags: state.tags,
      contentClass: state.contentClass,
      originType: state.originType,
      originId: state.originId,
      personaTypeSnapshot: state.personaTypeSnapshot,
      isPinned: state.isPinned,
    );
  }

  void addTag(String tag) {
    final cleaned = tag.trim().replaceAll('#', '').trim();
    if (cleaned.isEmpty) return;
    if (state.tags.contains(cleaned)) return;
    state = state.copyWith(tags: [...state.tags, cleaned]);
  }

  void removeTag(String tag) {
    state = state.copyWith(tags: state.tags.where((t) => t != tag).toList());
  }

  void setTags(List<String> tags) => state = state.copyWith(tags: tags);

  void setContentClass(String cc) => state = state.copyWith(contentClass: cc);

  void setOriginType(OriginType ot) => state = state.copyWith(originType: ot);

  void setOriginId(String? id) => state = state.copyWith(originId: id);

  void setPersonaTypeSnapshot(String? persona) =>
      state = state.copyWith(personaTypeSnapshot: persona);

  void togglePinned() => state = state.copyWith(isPinned: !state.isPinned);

  void setLocationTagId(String? id) =>
      state = state.copyWith(locationTagId: id);

  void addMediaUrl(String url) {
    if (url.trim().isEmpty) return;
    state = state.copyWith(media: [...state.media, url.trim()]);
  }

  void removeMediaAt(int index) {
    if (index < 0 || index >= state.media.length) return;
    final updated = List<dynamic>.from(state.media)..removeAt(index);
    state = state.copyWith(media: updated);
  }

  /// Upload a media file to the `post-media` storage bucket and add
  /// the resulting public URL to the media list.
  ///
  /// Sets [isSubmitting] while uploading and populates [error] on failure.
  Future<void> uploadMedia(XFile file) async {
    state = state.copyWith(isSubmitting: true, error: null);
    final result = await _repo.uploadPostMedia(file);
    result.fold(
      (f) {
        state = state.copyWith(
          isSubmitting: false,
          error: 'Upload failed: ${f.message}',
        );
      },
      (url) {
        state = state.copyWith(
          isSubmitting: false,
          media: [...state.media, url],
        );
      },
    );
  }
  // ── Submit ──────────────────────────────────────────────────────────

  /// Execute the full pre-insert pipeline and submit to Supabase.
  ///
  /// Steps:
  /// 1. Validate content
  /// 2. Detect language
  /// 3. Merge manual tags + auto-extracted hashtags
  /// 4. Generate link_token if needed
  /// 5. Auto-resolve origin_type + origin_id from linked entities
  /// 6. Capture persona_type_snapshot from active profile
  /// 7. Construct request
  /// 8. Insert via repository
  Future<Result<Post, Failure>> submit() async {
    final s = state;

    // 1. Validate
    if (!s.canSubmit) {
      final err = const Failure(
        category: FailureCode.validation,
        message: 'Add some text, a vibe, a sport, or media to post.',
      );
      state = s.copyWith(error: err.message);
      return Err(err);
    }

    // Circle visibility requires a circle
    if (s.visibility == PostVisibility.circle && s.circleId == null) {
      final err = const Failure(
        category: FailureCode.validation,
        message: 'Select a circle to post to.',
      );
      state = s.copyWith(error: err.message);
      return Err(err);
    }

    // Squad visibility requires a squad
    if (s.visibility == PostVisibility.squad && s.squadId == null) {
      final err = const Failure(
        category: FailureCode.validation,
        message: 'Select a squad to post to.',
      );
      state = s.copyWith(error: err.message);
      return Err(err);
    }

    state = s.copyWith(isSubmitting: true, error: null);

    // 2. Detect language
    final body = s.body.trim().isEmpty ? null : s.body.trim();
    if (body != null && !hasNonHashtagWord(body)) {
      final err = const Failure(
        category: FailureCode.validation,
        message: 'Add at least one non-hashtag word to your post body.',
      );
      state = s.copyWith(isSubmitting: false, error: err.message);
      return Err(err);
    }
    final lang = body != null ? detectLanguage(body) : null;

    // 3. Merge manual tags + auto-extracted hashtags (deduplicated)
    final autoTags = body != null ? extractHashtags(body) : <String>[];
    final mergedTags = {...s.tags, ...autoTags}.toList();

    // 4. Generate link_token if visibility == link
    String? linkToken;
    if (s.visibility == PostVisibility.link) {
      linkToken = const Uuid().v4();
    }

    // 5. Auto-resolve origin_type + origin_id from linked entities
    OriginType resolvedOriginType = s.originType;
    String? resolvedOriginId = s.originId;
    if (s.gameId != null && resolvedOriginType == OriginType.manual) {
      resolvedOriginType = OriginType.game;
      resolvedOriginId ??= s.gameId;
    } else if (s.venueId != null && resolvedOriginType == OriginType.manual) {
      resolvedOriginType = OriginType.venue;
      resolvedOriginId ??= s.venueId;
    }

    // 6. Capture persona_type_snapshot from active profile
    String? persona = s.personaTypeSnapshot;
    if (persona == null || persona.isEmpty) {
      try {
        persona = _ref.read(activeProfileTypeProvider);
      } catch (_) {}
    }

    // 7. Construct request
    final request = PostCreateRequest(
      kind: s.kind,
      visibility: s.visibility,
      body: body,
      lang: lang,
      media: s.media.isNotEmpty ? s.media : null,
      tags: mergedTags.isNotEmpty ? mergedTags : null,
      vibeId: s.vibeId,
      sportId: s.sportId,
      venueId: s.venueId,
      locationTagId: s.locationTagId,
      locationName: s.locationName,
      geoLat: s.geoLat,
      geoLng: s.geoLng,
      linkToken: linkToken,
      allowReposts: s.allowReposts,
      expiresAt: s.expiresAt,
      originType: resolvedOriginType,
      contentClass: s.contentClass,
      circleId: s.circleId,
      squadId: s.squadId,
      gameId: s.gameId,
      originId: resolvedOriginId,
      personaTypeSnapshot: persona,
      isPinned: s.isPinned,
    );

    // 8. Insert
    final result = await _repo.createFullPost(request);

    result.fold(
      (err) {
        debugPrint('[PostComposer] submit FAILED: ${err.message}');
        state = state.copyWith(isSubmitting: false, error: err.message);
      },
      (_) {
        state = state.copyWith(isSubmitting: false);
        // Invalidate feeds.
        _ref.invalidate(homeFeedProvider);
        try {
          _ref.read(feedNotifierProvider.notifier).load();
        } catch (_) {}
      },
    );

    return result;
  }
}

// =============================================================================
// PROVIDER
// =============================================================================

/// Composer state provider — auto-disposed when the screen is closed.
final postComposerProvider =
    StateNotifierProvider.autoDispose<PostComposerNotifier, PostComposerState>((
      ref,
    ) {
      return PostComposerNotifier(ref);
    });

/// Venue search results provider.
final venueSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, query) async {
      if (query.trim().length < 2) return [];
      final repo = ref.watch(postRepositoryProvider);
      final result = await repo.searchVenues(query.trim());
      return result.fold((err) => <Map<String, dynamic>>[], (venues) => venues);
    });

/// Game search results provider.
final gameSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, query) async {
      if (query.trim().length < 2) return [];
      final repo = ref.watch(postRepositoryProvider);
      final result = await repo.searchGames(query.trim());
      return result.fold((err) => <Map<String, dynamic>>[], (games) => games);
    });
