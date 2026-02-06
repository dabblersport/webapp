import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/create_post_usecase.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/data/models/authentication/user_model.dart';
import '../../../../utils/enums/social_enums.dart';

/// State for post creation and management
class PostsState {
  final PostModel? currentDraft;
  final Map<String, PostModel> savedDrafts;
  final bool isCreatingPost;
  final bool isSavingDraft;
  final String? error;
  final Map<String, MediaUploadProgress> mediaUploadProgress;
  final List<UserModel> mentionSuggestions;
  final List<String> hashtagSuggestions;
  final List<PostModel> scheduledPosts;
  final bool isLoadingMentions;
  final bool isLoadingHashtags;
  final String mentionQuery;
  final String hashtagQuery;

  // Additional properties for create post screen
  final List<dynamic> selectedMedia;
  final List<String> selectedSports;
  final String? selectedLocation;
  final PostVisibility visibility;
  final DateTime? scheduledTime;
  final bool isDraftAutoSaving;
  final Map<String, double> uploadProgress;
  final List<dynamic> drafts;
  final bool isPosting;
  final bool isUploadingMedia;

  const PostsState({
    this.currentDraft,
    this.savedDrafts = const {},
    this.isCreatingPost = false,
    this.isSavingDraft = false,
    this.error,
    this.mediaUploadProgress = const {},
    this.mentionSuggestions = const [],
    this.hashtagSuggestions = const [],
    this.scheduledPosts = const [],
    this.isLoadingMentions = false,
    this.isLoadingHashtags = false,
    this.mentionQuery = '',
    this.hashtagQuery = '',
    this.selectedMedia = const [],
    this.selectedSports = const [],
    this.selectedLocation,
    this.visibility = PostVisibility.public,
    this.scheduledTime,
    this.isDraftAutoSaving = false,
    this.uploadProgress = const {},
    this.drafts = const [],
    this.isPosting = false,
    this.isUploadingMedia = false,
  });

  PostsState copyWith({
    PostModel? currentDraft,
    Map<String, PostModel>? savedDrafts,
    bool? isCreatingPost,
    bool? isSavingDraft,
    String? error,
    Map<String, MediaUploadProgress>? mediaUploadProgress,
    List<UserModel>? mentionSuggestions,
    List<String>? hashtagSuggestions,
    List<PostModel>? scheduledPosts,
    bool? isLoadingMentions,
    bool? isLoadingHashtags,
    String? mentionQuery,
    String? hashtagQuery,
    List<dynamic>? selectedMedia,
    List<String>? selectedSports,
    String? selectedLocation,
    PostVisibility? visibility,
    DateTime? scheduledTime,
    bool? isDraftAutoSaving,
    Map<String, double>? uploadProgress,
    List<dynamic>? drafts,
    bool? isPosting,
    bool? isUploadingMedia,
  }) {
    return PostsState(
      currentDraft: currentDraft ?? this.currentDraft,
      savedDrafts: savedDrafts ?? this.savedDrafts,
      isCreatingPost: isCreatingPost ?? this.isCreatingPost,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      error: error,
      mediaUploadProgress: mediaUploadProgress ?? this.mediaUploadProgress,
      mentionSuggestions: mentionSuggestions ?? this.mentionSuggestions,
      hashtagSuggestions: hashtagSuggestions ?? this.hashtagSuggestions,
      scheduledPosts: scheduledPosts ?? this.scheduledPosts,
      isLoadingMentions: isLoadingMentions ?? this.isLoadingMentions,
      isLoadingHashtags: isLoadingHashtags ?? this.isLoadingHashtags,
      mentionQuery: mentionQuery ?? this.mentionQuery,
      hashtagQuery: hashtagQuery ?? this.hashtagQuery,
      selectedMedia: selectedMedia ?? this.selectedMedia,
      selectedSports: selectedSports ?? this.selectedSports,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      visibility: visibility ?? this.visibility,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isDraftAutoSaving: isDraftAutoSaving ?? this.isDraftAutoSaving,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      drafts: drafts ?? this.drafts,
      isPosting: isPosting ?? this.isPosting,
      isUploadingMedia: isUploadingMedia ?? this.isUploadingMedia,
    );
  }

  // Computed getters
  bool get hasDraft => currentDraft != null;
  bool get canPublish =>
      currentDraft != null &&
      currentDraft!.content.trim().isNotEmpty &&
      !isCreatingPost;
  bool get hasScheduledPosts => scheduledPosts.isNotEmpty;
  int get totalMediaUploading => mediaUploadProgress.values
      .where((progress) => !progress.isCompleted)
      .length;
  double get overallUploadProgress {
    if (mediaUploadProgress.isEmpty) return 0.0;
    final total = mediaUploadProgress.values.fold<double>(
      0.0,
      (sum, progress) => sum + progress.progress,
    );
    return total / mediaUploadProgress.length;
  }
}

/// Media upload progress tracking
class MediaUploadProgress {
  final String mediaId;
  final String fileName;
  final double progress;
  final bool isCompleted;
  final String? error;
  final String? uploadedUrl;

  const MediaUploadProgress({
    required this.mediaId,
    required this.fileName,
    this.progress = 0.0,
    this.isCompleted = false,
    this.error,
    this.uploadedUrl,
  });

  MediaUploadProgress copyWith({
    String? mediaId,
    String? fileName,
    double? progress,
    bool? isCompleted,
    String? error,
    String? uploadedUrl,
  }) {
    return MediaUploadProgress(
      mediaId: mediaId ?? this.mediaId,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
      uploadedUrl: uploadedUrl ?? this.uploadedUrl,
    );
  }
}

/// Controller for post creation and management
class PostsController extends StateNotifier<PostsState> {
  final dynamic _createPostUseCase;

  Timer? _draftAutoSaveTimer;
  Timer? _mentionDebounceTimer;
  Timer? _hashtagDebounceTimer;
  static const Duration _autoSaveInterval = Duration(seconds: 10);
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  PostsController(this._createPostUseCase) : super(const PostsState()) {
    _loadDrafts();
    _loadScheduledPosts();
  }

  @override
  void dispose() {
    _draftAutoSaveTimer?.cancel();
    _mentionDebounceTimer?.cancel();
    _hashtagDebounceTimer?.cancel();
    super.dispose();
  }

  /// Start new post draft
  void startNewPost() {
    final newDraft = PostModel(
      id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
      authorId: 'current_user', // From auth state
      authorName: 'Current User',
      authorAvatar: 'https://example.com/avatar.jpg',
      content: '',
      mediaUrls: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      visibility: PostVisibility.public,
    );

    state = state.copyWith(currentDraft: newDraft, error: null);

    _startAutoSave();
  }

  /// Update post content
  void updatePostContent(String content) {
    if (state.currentDraft == null) return;

    final updatedDraft = state.currentDraft!.copyWith(
      content: content,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(currentDraft: updatedDraft);

    // Extract mentions and hashtags
    _extractMentions(content);
    _extractHashtags(content);
  }

  /// Add media to post
  Future<void> addMediaToPost(List<File> mediaFiles) async {
    if (state.currentDraft == null) return;

    // Start upload progress tracking
    final uploadProgress = <String, MediaUploadProgress>{};

    for (int i = 0; i < mediaFiles.length; i++) {
      final file = mediaFiles[i];
      final mediaId = 'media_${DateTime.now().millisecondsSinceEpoch}_$i';

      uploadProgress[mediaId] = MediaUploadProgress(
        mediaId: mediaId,
        fileName: file.path.split('/').last,
      );
    }

    state = state.copyWith(
      mediaUploadProgress: {...state.mediaUploadProgress, ...uploadProgress},
    );

    // Upload media files
    for (int i = 0; i < mediaFiles.length; i++) {
      final file = mediaFiles[i];
      final mediaId = 'media_${DateTime.now().millisecondsSinceEpoch}_$i';

      try {
        await _uploadMedia(mediaId, file);
      } catch (e) {
        _updateMediaProgress(mediaId, error: e.toString());
      }
    }
  }

  /// Remove media from post
  void removeMediaFromPost(String mediaId) {
    final updatedProgress = Map<String, MediaUploadProgress>.from(
      state.mediaUploadProgress,
    );
    updatedProgress.remove(mediaId);

    // Update draft to remove media reference
    if (state.currentDraft != null) {
      final updatedMediaList = state.currentDraft!.mediaUrls
          .where((url) => !url.contains(mediaId))
          .toList();

      final updatedDraft = state.currentDraft!.copyWith(
        mediaUrls: updatedMediaList,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        currentDraft: updatedDraft,
        mediaUploadProgress: updatedProgress,
      );
    }
  }

  /// Set post privacy/visibility
  void updatePostPrivacy(PostVisibility visibility) {
    if (state.currentDraft == null) return;

    final updatedDraft = state.currentDraft!.copyWith(
      visibility: visibility,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(currentDraft: updatedDraft);
  }

  /// Add sport categories
  void updateSportsCategories(List<String> categories) {
    if (state.currentDraft == null) return;

    final updatedDraft = state.currentDraft!.copyWith(
      tags: categories,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(currentDraft: updatedDraft);
  }

  /// Save draft
  Future<void> saveDraft() async {
    if (state.currentDraft == null) return;

    state = state.copyWith(isSavingDraft: true);

    try {
      final draft = state.currentDraft!.copyWith(updatedAt: DateTime.now());

      // Save to local storage
      final updatedDrafts = Map<String, PostModel>.from(state.savedDrafts);
      updatedDrafts[draft.id] = draft;

      state = state.copyWith(savedDrafts: updatedDrafts, isSavingDraft: false);

      // Persist to storage
      await _persistDraft(draft);
    } catch (e) {
      state = state.copyWith(isSavingDraft: false, error: e.toString());
    }
  }

  /// Load draft
  void loadDraft(String draftId) {
    final draft = state.savedDrafts[draftId];
    if (draft != null) {
      state = state.copyWith(currentDraft: draft, error: null);
      _startAutoSave();
    }
  }

  /// Delete draft
  Future<void> deleteDraft(String draftId) async {
    try {
      final updatedDrafts = Map<String, PostModel>.from(state.savedDrafts);
      updatedDrafts.remove(draftId);

      state = state.copyWith(savedDrafts: updatedDrafts);

      // Clear current draft if it's the one being deleted
      if (state.currentDraft?.id == draftId) {
        state = state.copyWith(currentDraft: null);
        _stopAutoSave();
      }

      await _deleteDraftFromStorage(draftId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Publish post
  Future<void> publishPost() async {
    if (state.currentDraft == null || state.isCreatingPost) return;

    state = state.copyWith(isCreatingPost: true, error: null);

    try {
      final params = CreatePostParams(
        userId: state.currentDraft!.authorId,
        content: state.currentDraft!.content,
        mediaFiles: [], // Media should already be uploaded
        existingMediaUrls: state.currentDraft!.mediaUrls,
        visibility: state.currentDraft!.visibility,
        cityName: state.currentDraft!.cityName,
        tags: state.currentDraft!.tags,
        mentionedUsers: state.currentDraft!.mentionedUsers,
      );

      final result = await _createPostUseCase(params);

      result.fold(
        (failure) {
          state = state.copyWith(isCreatingPost: false, error: failure.message);
        },
        (success) {
          // Clear current draft and remove from saved drafts
          final updatedDrafts = Map<String, PostModel>.from(state.savedDrafts);
          if (state.currentDraft != null) {
            updatedDrafts.remove(state.currentDraft!.id);
          }

          state = state.copyWith(
            currentDraft: null,
            savedDrafts: updatedDrafts,
            isCreatingPost: false,
            mediaUploadProgress: {},
          );

          _stopAutoSave();
        },
      );
    } catch (e) {
      state = state.copyWith(isCreatingPost: false, error: e.toString());
    }
  }

  /// Schedule post for later
  Future<void> schedulePost(DateTime scheduledTime) async {
    if (state.currentDraft == null) return;

    try {
      final scheduledPost = state.currentDraft!.copyWith(
        updatedAt: DateTime.now(),
      );

      // Add to scheduled posts
      final updatedScheduled = [...state.scheduledPosts, scheduledPost];

      // Remove from current draft and saved drafts
      final updatedDrafts = Map<String, PostModel>.from(state.savedDrafts);
      updatedDrafts.remove(state.currentDraft!.id);

      state = state.copyWith(
        currentDraft: null,
        savedDrafts: updatedDrafts,
        scheduledPosts: updatedScheduled,
      );

      _stopAutoSave();
      await _persistScheduledPost(scheduledPost);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Cancel scheduled post
  Future<void> cancelScheduledPost(String postId) async {
    try {
      final updatedScheduled = state.scheduledPosts
          .where((post) => post.id != postId)
          .toList();

      state = state.copyWith(scheduledPosts: updatedScheduled);

      await _removeScheduledPostFromStorage(postId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Search for mention suggestions
  void searchMentions(String query) {
    state = state.copyWith(mentionQuery: query);

    _mentionDebounceTimer?.cancel();
    _mentionDebounceTimer = Timer(_debounceDelay, () async {
      if (query.isEmpty) {
        state = state.copyWith(mentionSuggestions: []);
        return;
      }

      state = state.copyWith(isLoadingMentions: true);

      try {
        final suggestions = await _fetchMentionSuggestions(query);

        // Only update if query hasn't changed
        if (state.mentionQuery == query) {
          state = state.copyWith(
            mentionSuggestions: suggestions,
            isLoadingMentions: false,
          );
        }
      } catch (e) {
        if (state.mentionQuery == query) {
          state = state.copyWith(isLoadingMentions: false, error: e.toString());
        }
      }
    });
  }

  /// Search for hashtag suggestions
  void searchHashtags(String query) {
    state = state.copyWith(hashtagQuery: query);

    _hashtagDebounceTimer?.cancel();
    _hashtagDebounceTimer = Timer(_debounceDelay, () async {
      if (query.isEmpty) {
        state = state.copyWith(hashtagSuggestions: []);
        return;
      }

      state = state.copyWith(isLoadingHashtags: true);

      try {
        final suggestions = await _fetchHashtagSuggestions(query);

        // Only update if query hasn't changed
        if (state.hashtagQuery == query) {
          state = state.copyWith(
            hashtagSuggestions: suggestions,
            isLoadingHashtags: false,
          );
        }
      } catch (e) {
        if (state.hashtagQuery == query) {
          state = state.copyWith(isLoadingHashtags: false, error: e.toString());
        }
      }
    });
  }

  /// Clear suggestions
  void clearSuggestions() {
    state = state.copyWith(
      mentionSuggestions: [],
      hashtagSuggestions: [],
      mentionQuery: '',
      hashtagQuery: '',
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear current draft
  void clearDraft() {
    state = state.copyWith(currentDraft: null, mediaUploadProgress: {});
    _stopAutoSave();
  }

  // Private methods
  void _extractMentions(String content) {
    final mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(content);

    for (final match in matches) {
      final username = match.group(1);
      if (username != null && username.isNotEmpty) {
        searchMentions(username);
      }
    }
  }

  void _extractHashtags(String content) {
    final hashtagRegex = RegExp(r'#(\w+)');
    final matches = hashtagRegex.allMatches(content);

    for (final match in matches) {
      final hashtag = match.group(1);
      if (hashtag != null && hashtag.isNotEmpty) {
        searchHashtags(hashtag);
      }
    }
  }

  void _startAutoSave() {
    _draftAutoSaveTimer?.cancel();
    _draftAutoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) {
      if (state.currentDraft != null) {
        saveDraft();
      }
    });
  }

  void _stopAutoSave() {
    _draftAutoSaveTimer?.cancel();
  }

  Future<void> _uploadMedia(String mediaId, File file) async {
    // Simulate media upload with progress updates
    for (int progress = 0; progress <= 100; progress += 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      _updateMediaProgress(mediaId, progress: progress / 100);
    }

    // Mock successful upload
    final uploadedUrl = 'https://example.com/media/$mediaId';
    _updateMediaProgress(
      mediaId,
      progress: 1.0,
      isCompleted: true,
      uploadedUrl: uploadedUrl,
    );

    // Add to draft media URLs
    if (state.currentDraft != null) {
      final updatedMediaUrls = [...state.currentDraft!.mediaUrls, uploadedUrl];
      final updatedDraft = state.currentDraft!.copyWith(
        mediaUrls: updatedMediaUrls,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(currentDraft: updatedDraft);
    }
  }

  void _updateMediaProgress(
    String mediaId, {
    double? progress,
    bool? isCompleted,
    String? error,
    String? uploadedUrl,
  }) {
    final currentProgress = state.mediaUploadProgress[mediaId];
    if (currentProgress == null) return;

    final updatedProgress = currentProgress.copyWith(
      progress: progress,
      isCompleted: isCompleted,
      error: error,
      uploadedUrl: uploadedUrl,
    );

    final updatedProgressMap = Map<String, MediaUploadProgress>.from(
      state.mediaUploadProgress,
    );
    updatedProgressMap[mediaId] = updatedProgress;

    state = state.copyWith(mediaUploadProgress: updatedProgressMap);
  }

  // Mock data fetching methods
  Future<void> _loadDrafts() async {
    // Mock loading drafts from storage
    await Future.delayed(const Duration(milliseconds: 300));
    // state = state.copyWith(savedDrafts: loadedDrafts);
  }

  Future<void> _loadScheduledPosts() async {
    // Mock loading scheduled posts
    await Future.delayed(const Duration(milliseconds: 300));
    // state = state.copyWith(scheduledPosts: loadedScheduledPosts);
  }

  Future<void> _persistDraft(PostModel draft) async {
    // Mock persisting draft to storage
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _deleteDraftFromStorage(String draftId) async {
    // Mock deleting draft from storage
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _persistScheduledPost(PostModel post) async {
    // Mock persisting scheduled post
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _removeScheduledPostFromStorage(String postId) async {
    // Mock removing scheduled post
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<List<UserModel>> _fetchMentionSuggestions(String query) async {
    // Mock fetching mention suggestions
    await Future.delayed(const Duration(milliseconds: 300));

    return List.generate(
      5,
      (index) => UserModel(
        id: 'mention_user_$index',
        fullName: 'User $index',
        email: 'mention_user_$index@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<List<String>> _fetchHashtagSuggestions(String query) async {
    // Mock fetching hashtag suggestions
    await Future.delayed(const Duration(milliseconds: 300));

    return List.generate(
      5,
      (index) => '${query.toLowerCase()}suggestion$index',
    );
  }

  // Additional methods for create post screen
  void clearMentionSuggestions() {
    state = state.copyWith(mentionSuggestions: []);
  }

  PostModel? getDraft(String draftId) {
    return state.savedDrafts[draftId];
  }

  void addMedia(dynamic media) {
    final updatedMedia = [...state.selectedMedia, media];
    state = state.copyWith(selectedMedia: updatedMedia);
  }

  void removeMedia(int index) {
    final updatedMedia = List<dynamic>.from(state.selectedMedia);
    updatedMedia.removeAt(index);
    state = state.copyWith(selectedMedia: updatedMedia);
  }

  void updateSports(List<String> sports) {
    state = state.copyWith(selectedSports: sports);
  }

  void updateLocation(String? location) {
    state = state.copyWith(selectedLocation: location);
  }

  void updateVisibility(PostVisibility visibility) {
    state = state.copyWith(visibility: visibility);
  }

  void clearSchedule() {
    state = state.copyWith(scheduledTime: null);
  }

  // Wrapper methods for create post screen compatibility
  Future<void> saveDraftWithContent({
    required String draftId,
    required String content,
  }) async {
    // Create a new draft with the given content
    final draft = PostModel(
      id: draftId,
      authorId: 'current_user',
      authorName: 'Current User',
      authorAvatar: 'https://example.com/avatar.jpg',
      content: content,
      mediaUrls: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      visibility: PostVisibility.public,
    );

    final updatedDrafts = Map<String, PostModel>.from(state.savedDrafts);
    updatedDrafts[draftId] = draft;

    state = state.copyWith(
      savedDrafts: updatedDrafts,
      drafts: updatedDrafts.values.toList(),
    );

    await _persistDraft(draft);
  }

  void schedulePostSimple(DateTime scheduledTime) {
    state = state.copyWith(scheduledTime: scheduledTime);
  }

  Future<bool> createPostSimple({required String content}) async {
    if (state.isCreatingPost) return false;

    state = state.copyWith(isCreatingPost: true, error: null);

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 1000));

      // Clear current draft
      state = state.copyWith(
        currentDraft: null,
        selectedMedia: [],
        selectedSports: [],
        selectedLocation: null,
        scheduledTime: null,
        isCreatingPost: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isCreatingPost: false, error: e.toString());
      return false;
    }
  }
}
