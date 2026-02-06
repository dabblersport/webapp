import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import '../../../../utils/enums/social_enums.dart';
import '../widgets/trending/trending_filter_bar.dart';
import '../../services/social_service.dart';

/// State for social feed management
class SocialFeedState {
  final List<PostModel> posts;
  final List<PostModel> filteredPosts;
  final List<PostModel> trendingPosts;
  final bool isLoading;
  final bool hasMore;
  final bool hasMoreTrending;
  final String? error;
  final String filter;
  final Set<String> optimisticPosts;

  const SocialFeedState({
    this.posts = const [],
    this.filteredPosts = const [],
    this.trendingPosts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.hasMoreTrending = true,
    this.error,
    this.filter = 'all',
    this.optimisticPosts = const {},
  });

  bool get isEmpty => posts.isEmpty;
  bool get hasError => error != null;

  SocialFeedState copyWith({
    List<PostModel>? posts,
    List<PostModel>? filteredPosts,
    List<PostModel>? trendingPosts,
    bool? isLoading,
    bool? hasMore,
    bool? hasMoreTrending,
    String? error,
    String? filter,
    Set<String>? optimisticPosts,
  }) {
    return SocialFeedState(
      posts: posts ?? this.posts,
      filteredPosts: filteredPosts ?? this.filteredPosts,
      trendingPosts: trendingPosts ?? this.trendingPosts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      hasMoreTrending: hasMoreTrending ?? this.hasMoreTrending,
      error: error ?? this.error,
      filter: filter ?? this.filter,
      optimisticPosts: optimisticPosts ?? this.optimisticPosts,
    );
  }
}

/// Controller for managing social feed state and operations
class SocialFeedController extends StateNotifier<SocialFeedState> {
  int _currentPage = 1;
  static const int _pageSize = 20;
  final SocialService _socialService = SocialService();

  SocialFeedController() : super(const SocialFeedState());

  /// Load initial posts
  Future<void> loadPosts() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Mock posts for now
      final posts = _generateMockPosts(1, _pageSize);

      state = state.copyWith(
        posts: posts,
        filteredPosts: _applyFilter(posts, state.filter),
        isLoading: false,
        hasMore: posts.length >= _pageSize,
      );
      _currentPage = 1;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load more posts for pagination
  Future<void> loadMorePosts() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      final nextPage = _currentPage + 1;
      final morePosts = _generateMockPosts(nextPage, _pageSize);

      if (morePosts.isNotEmpty) {
        final allPosts = [...state.posts, ...morePosts];
        state = state.copyWith(
          posts: allPosts,
          filteredPosts: _applyFilter(allPosts, state.filter),
          isLoading: false,
          hasMore: morePosts.length >= _pageSize,
        );
        _currentPage = nextPage;
      } else {
        state = state.copyWith(isLoading: false, hasMore: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh the feed
  Future<void> refreshFeed() async {
    _currentPage = 1;
    await loadPosts();
  }

  /// Change the current filter
  void changeFilter(String filter) {
    state = state.copyWith(
      filter: filter,
      filteredPosts: _applyFilter(state.posts, filter),
    );
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Add a post optimistically (before server confirmation)
  void addOptimisticPost(PostModel post) {
    final newPosts = [post, ...state.posts];
    state = state.copyWith(
      posts: newPosts,
      filteredPosts: _applyFilter(newPosts, state.filter),
      optimisticPosts: {...state.optimisticPosts, post.id},
    );
  }

  /// Remove optimistic post and add confirmed post
  void confirmPost(String postId, PostModel confirmedPost) {
    final newPosts = state.posts.map((post) {
      if (post.id == postId) return confirmedPost;
      return post;
    }).toList();

    final newOptimisticPosts = {...state.optimisticPosts}..remove(postId);

    state = state.copyWith(
      posts: newPosts,
      filteredPosts: _applyFilter(newPosts, state.filter),
      optimisticPosts: newOptimisticPosts,
    );
  }

  /// Remove optimistic post on failure
  void removeOptimisticPost(String postId) {
    final newPosts = state.posts.where((post) => post.id != postId).toList();
    final newOptimisticPosts = {...state.optimisticPosts}..remove(postId);

    state = state.copyWith(
      posts: newPosts,
      filteredPosts: _applyFilter(newPosts, state.filter),
      optimisticPosts: newOptimisticPosts,
    );
  }

  /// React to a post (like, unlike, etc.)
  Future<void> reactToPost(String postId, String reactionType) async {
    try {
      // Find the post
      final postIndex = state.posts.indexWhere((post) => post.id == postId);
      if (postIndex == -1) return;

      final post = state.posts[postIndex];

      // Update post optimistically
      final updatedPost = post.copyWith(
        isLiked: !post.isLiked,
        likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
      );

      final updatedPosts = List<PostModel>.from(state.posts);
      updatedPosts[postIndex] = updatedPost;

      state = state.copyWith(
        posts: updatedPosts,
        filteredPosts: _applyFilter(updatedPosts, state.filter),
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate API call
    } catch (e) {
      // Revert optimistic update on failure
      state = state.copyWith(error: e.toString());
    }
  }

  /// Apply filter to posts
  List<PostModel> _applyFilter(List<PostModel> posts, String filter) {
    switch (filter) {
      case 'all':
        return posts;
      case 'friends':
        return posts
            .where((post) => post.visibility == PostVisibility.friends)
            .toList();
      case 'public':
        return posts
            .where((post) => post.visibility == PostVisibility.public)
            .toList();
      case 'game':
        return posts.where((post) => post.gameId != null).toList();
      default:
        return posts;
    }
  }

  /// Generate mock posts for testing
  List<PostModel> _generateMockPosts(int page, int limit) {
    return List.generate(limit, (index) {
      final postId = 'post_${page}_$index';
      return PostModel(
        id: postId,
        authorId: 'user_${index % 5}',
        authorName: 'User ${index % 5}',
        authorAvatar: 'https://example.com/avatar_${index % 5}.jpg',
        content:
            'This is post content for post $postId. It contains some sample text to demonstrate the feed functionality.',
        mediaUrls: index % 3 == 0
            ? ['https://example.com/image_$index.jpg']
            : [],
        createdAt: DateTime.now().subtract(Duration(hours: index)),
        updatedAt: DateTime.now().subtract(Duration(hours: index)),
        likesCount: index * 2,
        commentsCount: index,
        sharesCount: index ~/ 2,
        visibility: index % 2 == 0
            ? PostVisibility.friends
            : PostVisibility.public,
        tags: index % 4 == 0 ? ['football', 'basketball'] : [],
        gameId: index % 5 == 0 ? 'game_$index' : null,
      );
    });
  }

  /// Toggle like status of a post
  Future<void> togglePostLike(String postId) async {
    try {
      final postIndex = state.posts.indexWhere((post) => post.id == postId);
      if (postIndex == -1) return;

      final post = state.posts[postIndex];
      final updatedPost = post.copyWith(
        isLiked: !post.isLiked,
        likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
      );

      final updatedPosts = List<PostModel>.from(state.posts);
      updatedPosts[postIndex] = updatedPost;

      state = state.copyWith(
        posts: updatedPosts,
        filteredPosts: _applyFilter(updatedPosts, state.filter),
      );

      // await postRepository.toggleLike(postId);
    } catch (e) {
      // Handle error
    }
  }

  /// Toggle bookmark status of a post
  Future<void> togglePostBookmark(String postId) async {
    try {
      final postIndex = state.posts.indexWhere((post) => post.id == postId);
      if (postIndex == -1) return;

      final post = state.posts[postIndex];
      final updatedPost = post.copyWith(isBookmarked: !post.isBookmarked);

      final updatedPosts = List<PostModel>.from(state.posts);
      updatedPosts[postIndex] = updatedPost;

      state = state.copyWith(
        posts: updatedPosts,
        filteredPosts: _applyFilter(updatedPosts, state.filter),
      );

      // await postRepository.toggleBookmark(postId);
    } catch (e) {
      // Handle error
    }
  }

  /// Hide a post from the feed
  Future<void> hidePost(String postId) async {
    try {
      final updatedPosts = state.posts
          .where((post) => post.id != postId)
          .toList();

      state = state.copyWith(
        posts: updatedPosts,
        filteredPosts: _applyFilter(updatedPosts, state.filter),
      );

      // await postRepository.hidePost(postId);
    } catch (e) {
      // Handle error
    }
  }

  /// Load post details
  Future<void> loadPostDetails(String postId) async {
    // This method is called when viewing post details
    // In a real implementation, this would fetch detailed post data
    // For now, we'll just ensure the post is in our state
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 300));

      // Check if post exists in current state
      final postExists = state.posts.any((post) => post.id == postId);
      if (!postExists) {
        // If post doesn't exist in current state, we could fetch it here
        // For now, just log that we're loading details
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Add comment to a post
  Future<bool> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      // Call the social service to add the comment
      await _socialService.addComment(
        postId: postId,
        body: content,
        parentCommentId: parentCommentId,
      );

      // Update the post's comment count in local state
      final postIndex = state.posts.indexWhere((post) => post.id == postId);
      if (postIndex != -1) {
        final post = state.posts[postIndex];
        final updatedPost = post.copyWith(
          commentsCount: post.commentsCount + 1,
        );

        final updatedPosts = List<PostModel>.from(state.posts);
        updatedPosts[postIndex] = updatedPost;

        state = state.copyWith(
          posts: updatedPosts,
          filteredPosts: _applyFilter(updatedPosts, state.filter),
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Delete a post
  Future<bool> deletePost(String postId) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Remove post from state
      final newPosts = state.posts.where((post) => post.id != postId).toList();

      state = state.copyWith(
        posts: newPosts,
        filteredPosts: _applyFilter(newPosts, state.filter),
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Load trending posts with filters
  Future<void> loadTrendingPosts({
    TrendingCategory category = TrendingCategory.all,
    TrendingTimeRange timeRange = TrendingTimeRange.today,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // For now, return the same posts as trending
      // In a real implementation, this would call a service to get trending posts
      final trendingPosts = <PostModel>[];

      state = state.copyWith(
        trendingPosts: trendingPosts,
        isLoading: false,
        hasMoreTrending: trendingPosts.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Load more trending posts
  Future<void> loadMoreTrendingPosts() async {
    if (!state.hasMoreTrending || state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // For now, just return empty list
      // In a real implementation, this would call a service to get more trending posts
      final morePosts = <PostModel>[];

      state = state.copyWith(
        trendingPosts: [...state.trendingPosts, ...morePosts],
        isLoading: false,
        hasMoreTrending: morePosts.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Refresh trending posts
  Future<void> refreshTrendingPosts() async {
    state = state.copyWith(trendingPosts: [], hasMoreTrending: true);
    await loadTrendingPosts();
  }

  /// Create a new post
  Future<bool> createPost({
    required String content,
    List<String> mediaUrls = const [],
    PostVisibility visibility = PostVisibility.public,
    List<String> tags = const [],
    String? gameId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 1000));

      // Create new post
      final newPost = PostModel(
        id: 'post_${DateTime.now().millisecondsSinceEpoch}',
        authorId: 'current_user',
        authorName: 'Current User',
        authorAvatar: '',
        content: content,
        mediaUrls: mediaUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        likesCount: 0,
        commentsCount: 0,
        sharesCount: 0,
        visibility: visibility,
        tags: tags,
        gameId: gameId,
      );

      // Add to feed
      addOptimisticPost(newPost);

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Save post as draft
  Future<bool> saveDraft({
    required String content,
    List<String> mediaUrls = const [],
    PostVisibility visibility = PostVisibility.public,
    List<String> tags = const [],
    String? gameId,
  }) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // For now, just return success
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Get saved drafts
  Future<List<PostModel>> getDrafts() async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 300));

      // For now, return empty list
      return [];
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  /// Delete a draft
  Future<bool> deleteDraft(String draftId) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 300));

      // For now, just return success
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Upload media files
  Future<List<String>> uploadMedia(List<String> filePaths) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 2000));

      // For now, return mock URLs
      return filePaths
          .map((path) => 'https://example.com/media/${path.split('/').last}')
          .toList();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }
}
