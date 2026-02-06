import 'post_model.dart';
import '../../../../utils/enums/social_enums.dart'; // For PostVisibility enum

/// Data model for social feed responses with pagination and filtering
class SocialFeedModel {
  final List<PostModel> posts;
  final List<FeedAuthor> authors;
  final PaginationMeta pagination;
  final FeedFilter filter;
  final FeedSort sort;
  final DateTime cacheTimestamp;
  final Map<String, dynamic>? metadata;

  const SocialFeedModel({
    required this.posts,
    required this.authors,
    required this.pagination,
    required this.filter,
    required this.sort,
    required this.cacheTimestamp,
    this.metadata,
  });

  /// Create SocialFeedModel from Supabase JSON response
  factory SocialFeedModel.fromJson(Map<String, dynamic> json) {
    // Parse posts array
    List<PostModel> posts = [];
    if (json['posts'] != null && json['posts'] is List) {
      posts = (json['posts'] as List)
          .map((post) => PostModel.fromJson(post))
          .toList();
    } else if (json['data'] != null && json['data'] is List) {
      // Alternative response format
      posts = (json['data'] as List)
          .map((post) => PostModel.fromJson(post))
          .toList();
    }

    // Parse authors array (deduplicated user info)
    List<FeedAuthor> authors = [];
    if (json['authors'] != null && json['authors'] is List) {
      authors = (json['authors'] as List)
          .map((author) => FeedAuthor.fromJson(author))
          .toList();
    } else if (json['profiles'] != null && json['profiles'] is List) {
      // Alternative format
      authors = (json['profiles'] as List)
          .map((profile) => FeedAuthor.fromJson(profile))
          .toList();
    } else {
      // Extract unique authors from posts
      final uniqueAuthors = <String, Map<String, dynamic>>{};
      for (final post in posts) {
        if (post.authorId.isNotEmpty &&
            !uniqueAuthors.containsKey(post.authorId)) {
          uniqueAuthors[post.authorId] = {
            'id': post.authorId,
            'name': post.authorName,
            'avatar_url': post.authorAvatar,
            'verified': post.authorVerified,
          };
        }
      }
      authors = uniqueAuthors.values
          .map((author) => FeedAuthor.fromJson(author))
          .toList();
    }

    // Parse pagination metadata
    PaginationMeta pagination = PaginationMeta.fromJson(
      json['pagination'] ?? json['meta'] ?? {},
    );

    // Parse filter information
    FeedFilter filter = FeedFilter.fromJson(
      json['filter'] ?? json['filters'] ?? {},
    );

    // Parse sort information
    FeedSort sort = FeedSort.fromJson(json['sort'] ?? json['sorting'] ?? {});

    return SocialFeedModel(
      posts: posts,
      authors: authors,
      pagination: pagination,
      filter: filter,
      sort: sort,
      cacheTimestamp: json['cache_timestamp'] != null
          ? _parseDateTime(json['cache_timestamp'])
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'posts': posts.map((post) => post.toJson()).toList(),
      'authors': authors.map((author) => author.toJson()).toList(),
      'pagination': pagination.toJson(),
      'filter': filter.toJson(),
      'sort': sort.toJson(),
      'cache_timestamp': cacheTimestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create JSON for API request
  Map<String, dynamic> toRequestJson() {
    final json = <String, dynamic>{};

    // Add pagination parameters
    if (pagination.page != null) json['page'] = pagination.page;
    if (pagination.limit != null) json['limit'] = pagination.limit;
    if (pagination.offset != null) json['offset'] = pagination.offset;

    // Add filter parameters
    if (filter.feedType != FeedType.home) {
      json['feed_type'] = _feedTypeToString(filter.feedType);
    }
    if (filter.gameId != null) json['game_id'] = filter.gameId;
    if (filter.authorId != null) json['author_id'] = filter.authorId;
    if (filter.visibility != null) {
      json['visibility'] = _visibilityToString(filter.visibility!);
    }
    if (filter.includeComments != null) {
      json['include_comments'] = filter.includeComments;
    }
    if (filter.includeReactions != null) {
      json['include_reactions'] = filter.includeReactions;
    }
    if (filter.maxAge != null) {
      json['max_age_hours'] = filter.maxAge!.inHours;
    }

    // Add sort parameters
    if (sort.field != SortField.createdAt) {
      json['sort_by'] = _sortFieldToString(sort.field);
    }
    if (sort.direction != SortDirection.desc) {
      json['sort_direction'] = sort.direction == SortDirection.asc
          ? 'asc'
          : 'desc';
    }

    return json;
  }

  /// Create a copy with updated fields
  SocialFeedModel copyWith({
    List<PostModel>? posts,
    List<FeedAuthor>? authors,
    PaginationMeta? pagination,
    FeedFilter? filter,
    FeedSort? sort,
    DateTime? cacheTimestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SocialFeedModel(
      posts: posts ?? this.posts,
      authors: authors ?? this.authors,
      pagination: pagination ?? this.pagination,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      cacheTimestamp: cacheTimestamp ?? this.cacheTimestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Append new posts (for pagination)
  SocialFeedModel appendPosts(
    List<PostModel> newPosts,
    PaginationMeta newPagination,
  ) {
    final allPosts = [...posts, ...newPosts];

    // Update authors list with new unique authors
    final existingAuthorIds = authors.map((a) => a.id).toSet();
    final newAuthors = <FeedAuthor>[];

    for (final post in newPosts) {
      if (!existingAuthorIds.contains(post.authorId)) {
        newAuthors.add(
          FeedAuthor(
            id: post.authorId,
            name: post.authorName,
            avatar: post.authorAvatar,
            verified: post.authorVerified,
          ),
        );
        existingAuthorIds.add(post.authorId);
      }
    }

    return copyWith(
      posts: allPosts,
      authors: [...authors, ...newAuthors],
      pagination: newPagination,
      cacheTimestamp: DateTime.now(),
    );
  }

  /// Check if feed is cached and valid
  bool isCacheValid({Duration maxAge = const Duration(minutes: 5)}) {
    return DateTime.now().difference(cacheTimestamp) <= maxAge;
  }

  /// Check if there are more posts to load
  bool get hasMore => pagination.hasMore;

  /// Get next page number for pagination
  int? get nextPage => pagination.nextPage;

  /// Get total number of posts in feed
  int get totalPosts => pagination.total ?? posts.length;

  /// Check if feed is empty
  bool get isEmpty => posts.isEmpty;

  /// Get unique game IDs from posts
  Set<String> get gameIds => posts
      .where((post) => post.gameId != null)
      .map((post) => post.gameId!)
      .toSet();

  /// Get author by ID
  FeedAuthor? getAuthor(String authorId) {
    try {
      return authors.firstWhere((author) => author.id == authorId);
    } catch (e) {
      return null;
    }
  }

  // Helper methods
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static String _feedTypeToString(FeedType type) {
    switch (type) {
      case FeedType.home:
        return 'home';
      case FeedType.following:
        return 'following';
      case FeedType.discover:
        return 'discover';
      case FeedType.game:
        return 'game';
      case FeedType.profile:
        return 'profile';
    }
  }

  static String _visibilityToString(PostVisibility visibility) {
    return visibility.value;
  }

  static String _sortFieldToString(SortField field) {
    switch (field) {
      case SortField.createdAt:
        return 'created_at';
      case SortField.popularity:
        return 'popularity';
      case SortField.reactions:
        return 'reactions';
      case SortField.comments:
        return 'comments';
    }
  }

  @override
  String toString() {
    return 'SocialFeedModel{posts: ${posts.length}, authors: ${authors.length}, hasMore: $hasMore}';
  }
}

/// Model for feed authors (deduplicated user information)
class FeedAuthor {
  final String id;
  final String name;
  final String avatar;
  final bool verified;
  final Map<String, dynamic>? profile;

  const FeedAuthor({
    required this.id,
    required this.name,
    this.avatar = '',
    this.verified = false,
    this.profile,
  });

  factory FeedAuthor.fromJson(Map<String, dynamic> json) {
    return FeedAuthor(
      id: json['id'] ?? json['user_id'] ?? '',
      name:
          json['name'] ??
          json['full_name'] ??
          json['username'] ??
          'Unknown User',
      avatar:
          json['avatar'] ?? json['avatar_url'] ?? json['profile_picture'] ?? '',
      verified: json['verified'] == true || json['is_verified'] == true,
      profile: json['profile'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'verified': verified,
    };

    if (avatar.isNotEmpty) json['avatar'] = avatar;
    if (profile != null) json['profile'] = profile;

    return json;
  }
}

/// Model for pagination metadata
class PaginationMeta {
  final int? page;
  final int? limit;
  final int? offset;
  final int? total;
  final bool hasMore;
  final int? nextPage;
  final String? nextCursor;

  const PaginationMeta({
    this.page,
    this.limit,
    this.offset,
    this.total,
    this.hasMore = false,
    this.nextPage,
    this.nextCursor,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    final page = json['page'] ?? json['current_page'];
    final limit = json['limit'] ?? json['per_page'] ?? json['page_size'];
    final total = json['total'] ?? json['total_count'];
    final hasMore =
        json['has_more'] ??
        json['has_next_page'] ??
        (page != null && limit != null && total != null
            ? (page * limit) < total
            : false);

    return PaginationMeta(
      page: page,
      limit: limit,
      offset: json['offset'],
      total: total,
      hasMore: hasMore,
      nextPage: hasMore && page != null ? page + 1 : null,
      nextCursor: json['next_cursor'],
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'has_more': hasMore};

    if (page != null) json['page'] = page;
    if (limit != null) json['limit'] = limit;
    if (offset != null) json['offset'] = offset;
    if (total != null) json['total'] = total;
    if (nextPage != null) json['next_page'] = nextPage;
    if (nextCursor != null) json['next_cursor'] = nextCursor;

    return json;
  }

  /// Create pagination for first page
  static PaginationMeta firstPage({int limit = 20}) {
    return PaginationMeta(page: 1, limit: limit, offset: 0, hasMore: true);
  }

  /// Create pagination for next page
  PaginationMeta nextPageMeta() {
    if (!hasMore || nextPage == null) {
      return this;
    }

    return PaginationMeta(
      page: nextPage,
      limit: limit,
      offset: limit != null ? (nextPage! - 1) * limit! : null,
      total: total,
      hasMore: true,
      nextCursor: nextCursor,
    );
  }
}

/// Model for feed filtering options
class FeedFilter {
  final FeedType feedType;
  final String? gameId;
  final String? authorId;
  final PostVisibility? visibility;
  final bool? includeComments;
  final bool? includeReactions;
  final Duration? maxAge;
  final Set<String>? excludeAuthors;

  const FeedFilter({
    this.feedType = FeedType.home,
    this.gameId,
    this.authorId,
    this.visibility,
    this.includeComments,
    this.includeReactions,
    this.maxAge,
    this.excludeAuthors,
  });

  factory FeedFilter.fromJson(Map<String, dynamic> json) {
    FeedType feedType = FeedType.home;
    final typeStr = json['feed_type']?.toString().toLowerCase() ?? 'home';
    switch (typeStr) {
      case 'home':
        feedType = FeedType.home;
        break;
      case 'following':
        feedType = FeedType.following;
        break;
      case 'discover':
        feedType = FeedType.discover;
        break;
      case 'game':
        feedType = FeedType.game;
        break;
      case 'profile':
        feedType = FeedType.profile;
        break;
    }

    PostVisibility? visibility;
    final visibilityStr = json['visibility']?.toString().toLowerCase();
    if (visibilityStr != null) {
      switch (visibilityStr) {
        case 'public':
          visibility = PostVisibility.public;
          break;
        case 'friends':
          visibility = PostVisibility.friends;
          break;
        case 'private':
          visibility = PostVisibility.private;
          break;
        case 'game_participants':
          visibility = PostVisibility.gameParticipants;
          break;
      }
    }

    Duration? maxAge;
    if (json['max_age_hours'] != null) {
      maxAge = Duration(hours: json['max_age_hours']);
    } else if (json['max_age_minutes'] != null) {
      maxAge = Duration(minutes: json['max_age_minutes']);
    }

    Set<String>? excludeAuthors;
    if (json['exclude_authors'] != null && json['exclude_authors'] is List) {
      excludeAuthors = (json['exclude_authors'] as List)
          .map((id) => id.toString())
          .toSet();
    }

    return FeedFilter(
      feedType: feedType,
      gameId: json['game_id'],
      authorId: json['author_id'],
      visibility: visibility,
      includeComments: json['include_comments'],
      includeReactions: json['include_reactions'],
      maxAge: maxAge,
      excludeAuthors: excludeAuthors,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'feed_type': _feedTypeToString(feedType)};

    if (gameId != null) json['game_id'] = gameId;
    if (authorId != null) json['author_id'] = authorId;
    if (visibility != null) {
      json['visibility'] = _visibilityToString(visibility!);
    }
    if (includeComments != null) json['include_comments'] = includeComments;
    if (includeReactions != null) json['include_reactions'] = includeReactions;
    if (maxAge != null) json['max_age_hours'] = maxAge!.inHours;
    if (excludeAuthors != null) {
      json['exclude_authors'] = excludeAuthors!.toList();
    }

    return json;
  }

  String _feedTypeToString(FeedType type) {
    switch (type) {
      case FeedType.home:
        return 'home';
      case FeedType.following:
        return 'following';
      case FeedType.discover:
        return 'discover';
      case FeedType.game:
        return 'game';
      case FeedType.profile:
        return 'profile';
    }
  }

  String _visibilityToString(PostVisibility visibility) {
    return visibility.value;
  }
}

/// Model for feed sorting options
class FeedSort {
  final SortField field;
  final SortDirection direction;

  const FeedSort({
    this.field = SortField.createdAt,
    this.direction = SortDirection.desc,
  });

  factory FeedSort.fromJson(Map<String, dynamic> json) {
    SortField field = SortField.createdAt;
    final fieldStr = json['sort_by']?.toString().toLowerCase() ?? 'created_at';
    switch (fieldStr) {
      case 'created_at':
      case 'date':
      case 'time':
        field = SortField.createdAt;
        break;
      case 'popularity':
      case 'popular':
        field = SortField.popularity;
        break;
      case 'reactions':
      case 'likes':
        field = SortField.reactions;
        break;
      case 'comments':
        field = SortField.comments;
        break;
    }

    SortDirection direction = SortDirection.desc;
    final directionStr =
        json['sort_direction']?.toString().toLowerCase() ??
        json['direction']?.toString().toLowerCase() ??
        'desc';
    direction = directionStr == 'asc' ? SortDirection.asc : SortDirection.desc;

    return FeedSort(field: field, direction: direction);
  }

  Map<String, dynamic> toJson() {
    return {
      'sort_by': _fieldToString(field),
      'sort_direction': direction == SortDirection.asc ? 'asc' : 'desc',
    };
  }

  String _fieldToString(SortField field) {
    switch (field) {
      case SortField.createdAt:
        return 'created_at';
      case SortField.popularity:
        return 'popularity';
      case SortField.reactions:
        return 'reactions';
      case SortField.comments:
        return 'comments';
    }
  }
}

/// Enums for feed types and sorting
enum FeedType { home, following, discover, game, profile }

enum SortField { createdAt, popularity, reactions, comments }

enum SortDirection { asc, desc }
