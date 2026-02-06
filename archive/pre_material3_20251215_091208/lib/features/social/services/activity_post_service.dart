import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import '../../../utils/enums/social_enums.dart';
import '../domain/repositories/posts_repository.dart';

/// Service for creating and managing unified activity posts
/// All user actions (comments, ratings, game creation, etc.) become activity posts
class ActivityPostService {
  final PostsRepository _postRepository;

  ActivityPostService(this._postRepository);

  /// Create a comment activity post when user comments on something
  Future<PostModel?> createCommentPost({
    required String commentContent,
    required String originalPostId,
    ActivityPrivacyLevel privacy = ActivityPrivacyLevel.thread,
  }) async {
    try {
      final activityContent = PostActivityType.comment.getContentTemplate({
        'content': commentContent,
      });

      final result = await _postRepository.createPost(
        content: activityContent,
        visibility: privacy.toPostVisibility(),
        replyToPostId: originalPostId,
      );

      return result.fold((failure) => null, (postModel) => postModel);
    } catch (e) {
      // Log error
      return null;
    }
  }

  /// Create a venue rating activity post when user rates a venue
  Future<PostModel?> createVenueRatingPost({
    required String venueName,
    required double rating,
    String? review,
    List<String> mediaUrls = const [],
    ActivityPrivacyLevel privacy = ActivityPrivacyLevel.public,
  }) async {
    try {
      final activityContent = PostActivityType.venueRating.getContentTemplate({
        'venueName': venueName,
        'rating': rating.toString(),
        'review': review ?? '',
      });

      final result = await _postRepository.createPost(
        content: activityContent,
        mediaUrls: mediaUrls,
        visibility: privacy.toPostVisibility(),
        cityName: venueName,
        tags: [venueName],
      );

      return result.fold((failure) => null, (postModel) => postModel);
    } catch (e) {
      return null;
    }
  }

  /// Create a game creation activity post when user creates a game
  Future<PostModel?> createGameCreationPost({
    required String gameType,
    required String gameId,
    required String venueName,
    ActivityPrivacyLevel privacy = ActivityPrivacyLevel.public,
  }) async {
    try {
      final activityContent = PostActivityType.gameCreation.getContentTemplate({
        'gameType': gameType,
        'venueName': venueName,
      });

      final result = await _postRepository.createPost(
        content: activityContent,
        visibility: privacy.toPostVisibility(),
        gameId: gameId,
        cityName: venueName,
        tags: [gameType, venueName],
      );

      return result.fold((failure) => null, (postModel) => postModel);
    } catch (e) {
      return null;
    }
  }

  /// Create a check-in activity post when user checks in at a venue
  Future<PostModel?> createCheckInPost({
    required String venueName,
    String? note,
    List<String> mediaUrls = const [],
    List<String> taggedFriends = const [],
    ActivityPrivacyLevel privacy = ActivityPrivacyLevel.public,
  }) async {
    try {
      final activityContent = PostActivityType.checkIn.getContentTemplate({
        'venueName': venueName,
        'note': note ?? '',
      });

      final result = await _postRepository.createPost(
        content: activityContent,
        mediaUrls: mediaUrls,
        visibility: privacy.toPostVisibility(),
        cityName: venueName,
        tags: [venueName],
        mentionedUsers: taggedFriends,
      );

      return result.fold((failure) => null, (postModel) => postModel);
    } catch (e) {
      return null;
    }
  }

  /// Create a venue booking activity post when user books a venue
  Future<PostModel?> createVenueBookingPost({
    required String venueName,
    required DateTime bookingDate,
    ActivityPrivacyLevel privacy = ActivityPrivacyLevel.friends,
  }) async {
    try {
      final activityContent = PostActivityType.venueBooking.getContentTemplate({
        'venueName': venueName,
        'date': bookingDate.toLocal().toString().split(
          ' ',
        )[0], // Just date part
      });

      final result = await _postRepository.createPost(
        content: activityContent,
        visibility: privacy.toPostVisibility(),
        cityName: venueName,
        tags: [venueName],
      );

      return result.fold((failure) => null, (postModel) => postModel);
    } catch (e) {
      return null;
    }
  }

  /// Create a game join activity post when user joins a game
  Future<PostModel?> createGameJoinPost({
    required String gameType,
    required String gameId,
    required String venueName,
    ActivityPrivacyLevel privacy = ActivityPrivacyLevel.public,
  }) async {
    try {
      final activityContent = PostActivityType.gameJoin.getContentTemplate({
        'gameType': gameType,
        'venueName': venueName,
      });

      final result = await _postRepository.createPost(
        content: activityContent,
        visibility: privacy.toPostVisibility(),
        gameId: gameId,
        cityName: venueName,
        tags: [gameType, venueName],
      );

      return result.fold((failure) => null, (postModel) => postModel);
    } catch (e) {
      return null;
    }
  }

  /// Create an achievement activity post when user earns an achievement
  Future<PostModel?> createAchievementPost({
    required String achievementName,
    String? achievementDescription,
    List<String> mediaUrls = const [],
    ActivityPrivacyLevel privacy = ActivityPrivacyLevel.public,
  }) async {
    try {
      final activityContent = PostActivityType.achievement.getContentTemplate({
        'achievementName': achievementName,
      });

      final result = await _postRepository.createPost(
        content: activityContent,
        mediaUrls: mediaUrls,
        visibility: privacy.toPostVisibility(),
        tags: ['achievement', achievementName],
      );

      return result.fold((failure) => null, (postModel) => postModel);
    } catch (e) {
      return null;
    }
  }

  /// Check if a user can perform a specific activity type
  bool canPerformActivity(PostActivityType activityType) {
    // Add business logic here for permissions, limits, etc.
    // For now, all activities are allowed
    return true;
  }
}

/// Provider for ActivityPostService
final activityPostServiceProvider = Provider<ActivityPostService>((ref) {
  final postRepository = ref.watch(postsRepositoryProvider);
  return ActivityPostService(postRepository);
});

/// Placeholder for posts repository provider - should be defined in the repository layer
final postsRepositoryProvider = Provider<PostsRepository>((ref) {
  throw UnimplementedError('PostsRepository provider not implemented');
});
