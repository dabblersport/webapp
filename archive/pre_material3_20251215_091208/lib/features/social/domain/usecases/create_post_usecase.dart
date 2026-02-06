import 'dart:io';
import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/logger.dart';
import '../../../../utils/enums/social_enums.dart';
import '../repositories/posts_repository.dart';
import 'package:dabbler/data/models/social/post_model.dart';

/// Parameters for creating a post
class CreatePostParams {
  final String userId;
  final String content;
  final List<File>? mediaFiles;
  final List<String>? existingMediaUrls;
  final PostVisibility visibility;
  final String? gameId;
  final String? cityName;
  final double? latitude;
  final double? longitude;
  final List<String>? tags;
  final List<String>? mentionedUsers;
  final String? replyToPostId;
  final String? shareOriginalId;
  final bool schedulePost;
  final DateTime? scheduledAt;
  final Map<String, dynamic>? metadata;

  const CreatePostParams({
    required this.userId,
    required this.content,
    this.mediaFiles,
    this.existingMediaUrls,
    this.visibility = PostVisibility.public,
    this.gameId,
    this.cityName,
    this.latitude,
    this.longitude,
    this.tags,
    this.mentionedUsers,
    this.replyToPostId,
    this.shareOriginalId,
    this.schedulePost = false,
    this.scheduledAt,
    this.metadata,
  });
}

/// Result of create post operation
class CreatePostResult {
  final PostModel post;
  final List<String> uploadedMediaUrls;
  final List<String> processedTags;
  final List<String> notifiedUsers;
  final bool queuedForOffline;
  final List<String> warnings;
  final Map<String, dynamic> processingMetadata;

  const CreatePostResult({
    required this.post,
    this.uploadedMediaUrls = const [],
    this.processedTags = const [],
    this.notifiedUsers = const [],
    this.queuedForOffline = false,
    this.warnings = const [],
    this.processingMetadata = const {},
  });
}

/// Use case for creating posts with comprehensive validation and processing
class CreatePostUseCase {
  final PostsRepository _postsRepository;
  static const int maxContentLength = 5000;
  static const int maxMediaFiles = 10;
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const List<String> allowedVideoFormats = ['mp4', 'mov', 'avi', 'mkv'];
  static const List<String> allowedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];

  CreatePostUseCase(this._postsRepository);

  Future<Either<Failure, CreatePostResult>> call(
    CreatePostParams params,
  ) async {
    try {
      // Validate input parameters
      final validationResult = await _validateParams(params);
      if (validationResult.isLeft()) {
        return Left(
          validationResult.fold(
            (l) => l,
            (_) => ServerFailure(message: 'Validation failed'),
          ),
        );
      }

      // Check if user is allowed to post
      final userCheckResult = await _checkUserPermissions(params.userId);
      if (userCheckResult.isLeft()) {
        return Left(
          userCheckResult.fold(
            (l) => l,
            (_) => ServerFailure(message: 'Permission check failed'),
          ),
        );
      }

      // Validate and process content
      final contentResult = await _processContent(params);
      if (contentResult.isLeft()) {
        return Left(
          contentResult.fold(
            (l) => l,
            (_) => ServerFailure(message: 'Content processing failed'),
          ),
        );
      }
      final processedContent = contentResult.fold(
        (_) => throw StateError('unreachable'),
        (r) => r,
      );

      // Validate and upload media files
      final mediaResult = await _processMediaFiles(params);
      if (mediaResult.isLeft()) {
        return Left(
          mediaResult.fold(
            (l) => l,
            (_) => ServerFailure(message: 'Media processing failed'),
          ),
        );
      }
      final mediaUrls = mediaResult.fold(
        (_) => throw StateError('unreachable'),
        (r) => r,
      );

      // Process hashtags and extract mentions
      final tagsResult = _processTags(processedContent.content);
      final mentionsResult = _processMentions(
        processedContent.content,
        params.mentionedUsers,
      );

      // Apply content moderation
      final moderationResult = await _moderateContent(
        processedContent.content,
        mediaUrls,
        params.userId,
      );
      if (moderationResult.isLeft()) {
        return Left(
          moderationResult.fold(
            (l) => l,
            (_) => ServerFailure(message: 'Moderation failed'),
          ),
        );
      }

      // Check for duplicate posts
      final duplicateResult = await _checkDuplicatePost(params);
      if (duplicateResult.isLeft()) {
        return Left(
          duplicateResult.fold(
            (l) => l,
            (_) => ServerFailure(message: 'Duplicate check failed'),
          ),
        );
      }

      // Set appropriate visibility based on user settings and context
      final finalVisibility = await _determineVisibility(params);

      // Create the post model
      final postData = _buildPostData(
        params,
        processedContent.content,
        mediaUrls,
        tagsResult,
        mentionsResult.mentions,
        finalVisibility,
      );

      Either<Failure, PostModel> createResult;

      // Check if device is offline and queue if necessary
      final isOnline = await _checkConnectivity();
      if (!isOnline) {
        createResult = await _queuePostForLater(postData);
        if (createResult.isRight()) {
          return Right(
            CreatePostResult(
              post: createResult.fold(
                (_) => throw StateError('unreachable'),
                (r) => r,
              ),
              uploadedMediaUrls: mediaUrls,
              processedTags: tagsResult,
              notifiedUsers: [],
              queuedForOffline: true,
              warnings: ['Post queued for upload when online'],
              processingMetadata: processedContent.metadata,
            ),
          );
        }
      } else {
        // Create post online
        if (params.schedulePost && params.scheduledAt != null) {
          createResult = await _postsRepository.schedulePost(
            postData,
            params.scheduledAt!,
          );
        } else {
          // Use repository API with named parameters
          createResult = await _postsRepository.createPost(
            content: processedContent.content,
            mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
            visibility: finalVisibility,
            gameId: params.gameId,
            cityName: params.cityName,
            tags: tagsResult.isEmpty ? null : tagsResult,
            mentionedUsers: mentionsResult.mentions.isEmpty
                ? null
                : mentionsResult.mentions,
            replyToPostId: params.replyToPostId,
            shareOriginalId: params.shareOriginalId,
          );
        }
      }

      if (createResult.isLeft()) {
        return Left(
          createResult.fold(
            (l) => l,
            (_) => ServerFailure(message: 'Create post failed'),
          ),
        );
      }

      final createdPost = createResult.fold(
        (_) => throw StateError('unreachable'),
        (r) => r,
      );

      // Send notifications for mentions
      final notifiedUsers = await _notifyMentionedUsers(
        mentionsResult.mentions,
        createdPost,
      );

      // Update user activity metrics
      await _updateUserMetrics(params.userId, 'post_created', createdPost);

      // Log post creation for analytics
      await _logPostCreation(params, createdPost);

      return Right(
        CreatePostResult(
          post: createdPost,
          uploadedMediaUrls: mediaUrls,
          processedTags: tagsResult,
          notifiedUsers: notifiedUsers,
          queuedForOffline: false,
          warnings: processedContent.warnings,
          processingMetadata: processedContent.metadata,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to create post: ${e.toString()}',
          code: '500',
        ),
      );
    }
  }

  /// Validates input parameters
  Future<Either<Failure, void>> _validateParams(CreatePostParams params) async {
    // Validate content length
    if (params.content.trim().isEmpty) {
      return Left(
        ValidationFailure(
          message: 'Post content cannot be empty',
          details: {'field': 'content'},
        ),
      );
    }

    if (params.content.length > maxContentLength) {
      return Left(
        ValidationFailure(
          message: 'Post content cannot exceed $maxContentLength characters',
          details: {'field': 'content', 'maxLength': maxContentLength},
        ),
      );
    }

    // Validate media files count
    final totalMediaCount =
        (params.mediaFiles?.length ?? 0) +
        (params.existingMediaUrls?.length ?? 0);
    if (totalMediaCount > maxMediaFiles) {
      return Left(
        ValidationFailure(
          message: 'Cannot attach more than $maxMediaFiles media files',
          details: {'field': 'mediaFiles'},
        ),
      );
    }

    // Validate media files if provided
    if (params.mediaFiles != null) {
      for (int i = 0; i < params.mediaFiles!.length; i++) {
        final file = params.mediaFiles![i];

        // Check file size
        final fileSize = await file.length();
        if (fileSize > maxFileSize) {
          return Left(
            ValidationFailure(
              message:
                  'File ${file.path.split('/').last} exceeds maximum size of ${maxFileSize ~/ (1024 * 1024)}MB',
              details: {'field': 'mediaFiles'},
            ),
          );
        }

        // Check file format
        final extension = file.path.split('.').last.toLowerCase();
        if (!allowedImageFormats.contains(extension) &&
            !allowedVideoFormats.contains(extension)) {
          return Left(
            ValidationFailure(
              message: 'File format .$extension is not supported',
              details: {'field': 'mediaFiles'},
            ),
          );
        }
      }
    }

    // Validate scheduled post
    if (params.schedulePost) {
      if (params.scheduledAt == null) {
        return Left(
          ValidationFailure(
            message: 'Scheduled time is required for scheduled posts',
            details: {'field': 'scheduledAt'},
          ),
        );
      }

      if (params.scheduledAt!.isBefore(DateTime.now())) {
        return Left(
          ValidationFailure(
            message: 'Scheduled time must be in the future',
            details: {'field': 'scheduledAt'},
          ),
        );
      }

      // Don't allow scheduling more than 1 year in advance
      if (params.scheduledAt!.isAfter(
        DateTime.now().add(const Duration(days: 365)),
      )) {
        return Left(
          ValidationFailure(
            message: 'Cannot schedule posts more than 1 year in advance',
            details: {'field': 'scheduledAt'},
          ),
        );
      }
    }

    // Validate location coordinates
    if (params.latitude != null || params.longitude != null) {
      if (params.latitude == null || params.longitude == null) {
        return Left(
          ValidationFailure(
            message: 'Both latitude and longitude must be provided',
            details: {'field': 'location'},
          ),
        );
      }

      if (params.latitude! < -90 || params.latitude! > 90) {
        return Left(
          ValidationFailure(
            message: 'Invalid latitude value',
            details: {'field': 'latitude'},
          ),
        );
      }

      if (params.longitude! < -180 || params.longitude! > 180) {
        return Left(
          ValidationFailure(
            message: 'Invalid longitude value',
            details: {'field': 'longitude'},
          ),
        );
      }
    }

    return const Right(null);
  }

  /// Checks user permissions to create posts
  Future<Either<Failure, void>> _checkUserPermissions(String userId) async {
    try {
      final userStatus = await _postsRepository.getUserPostingPermissions(
        userId,
      );

      if (userStatus.isLeft()) {
        return Left(
          userStatus.fold(
            (l) => l,
            (_) => ServerFailure(message: 'User status failed'),
          ),
        );
      }

      final permissions = userStatus.fold(
        (_) => throw StateError('unreachable'),
        (r) => r,
      );

      if (!permissions.canCreatePosts) {
        return Left(
          ForbiddenFailure(
            message: 'User does not have permission to create posts',
          ),
        );
      }

      if (permissions.isTemporarilyRestricted) {
        return Left(
          ForbiddenFailure(
            message: 'Account is temporarily restricted from posting',
          ),
        );
      }

      // Check rate limiting
      if (permissions.rateLimitExceeded) {
        return Left(
          BusinessLogicFailure(
            message: 'Post creation rate limit exceeded',
            details: {
              'retry_after_seconds': permissions.rateLimitResetAt != null
                  ? permissions.rateLimitResetAt!
                        .difference(DateTime.now())
                        .inSeconds
                  : const Duration(hours: 1).inSeconds,
            },
          ),
        );
      }

      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to check user permissions: ${e.toString()}',
        ),
      );
    }
  }

  /// Processes and validates content
  Future<Either<Failure, ProcessedContent>> _processContent(
    CreatePostParams params,
  ) async {
    try {
      String processedContent = params.content.trim();
      final warnings = <String>[];
      final metadata = <String, dynamic>{};

      // Remove excessive whitespace
      processedContent = processedContent.replaceAll(RegExp(r'\s+'), ' ');

      // Check for potentially inappropriate content patterns
      final inappropriatePatterns = [
        RegExp(r'(https?://[^\s]+)', caseSensitive: false), // URLs
        RegExp(
          r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
          caseSensitive: false,
        ), // Emails
      ];

      // Extract and validate URLs
      final urlMatches = inappropriatePatterns[0].allMatches(processedContent);
      if (urlMatches.isNotEmpty) {
        metadata['urls'] = urlMatches.map((match) => match.group(0)).toList();
      }

      // Extract and validate emails
      final emailMatches = inappropriatePatterns[1].allMatches(
        processedContent,
      );
      if (emailMatches.isNotEmpty) {
        metadata['emails'] = emailMatches
            .map((match) => match.group(0))
            .toList();
      }

      // Check for excessive caps (more than 70% caps)
      final capsCount = processedContent
          .split('')
          .where(
            (char) =>
                char == char.toUpperCase() &&
                char.toLowerCase() != char.toUpperCase(),
          )
          .length;
      final capsPercentage = capsCount / processedContent.length;

      if (capsPercentage > 0.7) {
        warnings.add('Post contains excessive capital letters');
      }

      return Right(
        ProcessedContent(
          content: processedContent,
          warnings: warnings,
          metadata: metadata,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to process content: ${e.toString()}'),
      );
    }
  }

  /// Processes and uploads media files
  Future<Either<Failure, List<String>>> _processMediaFiles(
    CreatePostParams params,
  ) async {
    try {
      final allMediaUrls = <String>[];

      // Add existing media URLs if provided
      if (params.existingMediaUrls != null) {
        allMediaUrls.addAll(params.existingMediaUrls!);
      }

      // Upload new media files if provided
      if (params.mediaFiles != null && params.mediaFiles!.isNotEmpty) {
        final uploadResult = await _postsRepository.uploadMediaFiles(
          params.mediaFiles!,
          params.userId,
        );

        if (uploadResult.isLeft()) {
          return Left(
            uploadResult.fold(
              (l) => l,
              (_) => ServerFailure(message: 'Upload failed'),
            ),
          );
        }

        final uploadedUrls = uploadResult.fold(
          (_) => throw StateError('unreachable'),
          (r) => r,
        );
        allMediaUrls.addAll(uploadedUrls);
      }

      return Right(allMediaUrls);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to process media files: ${e.toString()}',
        ),
      );
    }
  }

  /// Processes hashtags from content
  List<String> _processTags(String content) {
    final hashtagRegex = RegExp(r'#([a-zA-Z0-9_]+)');
    final matches = hashtagRegex.allMatches(content);

    return matches
        .map((match) => match.group(1)?.toLowerCase())
        .where((tag) => tag != null && tag.length >= 2)
        .cast<String>()
        .toSet()
        .take(20) // Limit to 20 hashtags
        .toList();
  }

  /// Processes mentions from content
  ProcessedMentions _processMentions(
    String content,
    List<String>? explicitMentions,
  ) {
    final mentionRegex = RegExp(r'@([a-zA-Z0-9_]+)');
    final matches = mentionRegex.allMatches(content);

    final contentMentions = matches
        .map((match) => match.group(1)?.toLowerCase())
        .where((mention) => mention != null)
        .cast<String>()
        .toSet()
        .toList();

    final allMentions = <String>{};
    allMentions.addAll(contentMentions);

    if (explicitMentions != null) {
      allMentions.addAll(explicitMentions);
    }

    return ProcessedMentions(
      mentions: allMentions.take(50).toList(), // Limit to 50 mentions
      fromContent: contentMentions,
      explicit: explicitMentions ?? [],
    );
  }

  /// Applies content moderation
  Future<Either<Failure, void>> _moderateContent(
    String content,
    List<String> mediaUrls,
    String userId,
  ) async {
    try {
      // This would typically call a content moderation service
      final moderationResult = await _postsRepository.moderateContent(
        content: content,
        mediaUrls: mediaUrls,
        userId: userId,
      );

      if (moderationResult.isLeft()) {
        return Left(
          moderationResult.fold(
            (l) => l,
            (_) => ServerFailure(message: 'Moderation call failed'),
          ),
        );
      }

      final moderation = moderationResult.fold(
        (_) => throw StateError('unreachable'),
        (r) => r,
      );

      if (moderation.isBlocked) {
        return Left(
          ValidationFailure(
            message:
                moderation.reason ?? 'Content violates community guidelines',
            details: {'field': 'content'},
          ),
        );
      }

      if (moderation.requiresReview) {
        return Left(
          ValidationFailure(
            message: 'Content requires manual review before posting',
            details: {'field': 'content'},
          ),
        );
      }

      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(message: 'Content moderation failed: ${e.toString()}'),
      );
    }
  }

  /// Checks for duplicate posts
  Future<Either<Failure, void>> _checkDuplicatePost(
    CreatePostParams params,
  ) async {
    try {
      final duplicateCheck = await _postsRepository.checkDuplicatePost(
        userId: params.userId,
        content: params.content,
        timeWindow: const Duration(minutes: 5),
      );

      if (duplicateCheck.isRight() &&
          duplicateCheck.fold((_) => false, (r) => r == true)) {
        return Left(
          ConflictFailure(
            message:
                'Duplicate post detected. Please wait before posting similar content.',
          ),
        );
      }

      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to check for duplicate post: ${e.toString()}',
        ),
      );
    }
  }

  /// Determines final post visibility
  Future<PostVisibility> _determineVisibility(CreatePostParams params) async {
    try {
      // Get user's default visibility settings
      final userSettings = await _postsRepository.getUserDefaultVisibility(
        params.userId,
      );

      if (userSettings.isRight()) {
        // final defaultVisibility = userSettings.fold((_) => null, (r) => r);
        // Use provided visibility or fall back to user default
        return params.visibility;
      }

      return params.visibility;
    } catch (e) {
      return params.visibility;
    }
  }

  /// Builds post data for creation
  Map<String, dynamic> _buildPostData(
    CreatePostParams params,
    String processedContent,
    List<String> mediaUrls,
    List<String> tags,
    List<String> mentions,
    PostVisibility visibility,
  ) {
    return {
      'user_id': params.userId,
      'content': processedContent,
      'media_urls': mediaUrls,
      'visibility': visibility.name,
      'game_id': params.gameId,
      'location_name': params.cityName,
      'latitude': params.latitude,
      'longitude': params.longitude,
      'tags': tags,
      'mentioned_users': mentions,
      'reply_to_post_id': params.replyToPostId,
      'share_original_id': params.shareOriginalId,
      'metadata': params.metadata ?? {},
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Checks device connectivity
  Future<bool> _checkConnectivity() async {
    try {
      // This would typically use a connectivity package
      // For now, simulate online status
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Queues post for later upload when offline
  Future<Either<Failure, PostModel>> _queuePostForLater(
    Map<String, dynamic> postData,
  ) async {
    try {
      return await _postsRepository.queuePostForOffline(postData);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to queue post for offline: ${e.toString()}',
        ),
      );
    }
  }

  /// Sends notifications to mentioned users
  Future<List<String>> _notifyMentionedUsers(
    List<String> mentions,
    PostModel post,
  ) async {
    final notifiedUsers = <String>[];

    try {
      for (final mention in mentions) {
        final notificationSent = await _sendMentionNotification(mention, post);
        if (notificationSent) {
          notifiedUsers.add(mention);
        }
      }
    } catch (e) {
      Logger.error('Failed to send mention notifications: $e');
    }

    return notifiedUsers;
  }

  /// Sends notification for a mention
  Future<bool> _sendMentionNotification(
    String mentionedUser,
    PostModel post,
  ) async {
    try {
      // This would typically call a notification service
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Updates user activity metrics
  Future<void> _updateUserMetrics(
    String userId,
    String actionType,
    PostModel post,
  ) async {
    try {
      // This would typically update user activity metrics
    } catch (e) {
      Logger.error('Failed to update user metrics: $e');
    }
  }

  /// Logs post creation for analytics
  Future<void> _logPostCreation(CreatePostParams params, PostModel post) async {
    try {
      final _ = {
        'action': 'post_created',
        'user_id': params.userId,
        'post_id': post.id,
        'has_media': post.mediaUrls.isNotEmpty,
        'media_count': post.mediaUrls.length,
        'content_length': params.content.length,
        'visibility': params.visibility.name,
        'has_game': params.gameId != null,
        'has_location': params.cityName != null,
        'tags_count': post.tags.length,
        'mentions_count': post.mentionedUsers.length,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // In a real implementation, this would call:
      // await _analyticsService.logEvent('post_created', logData);
    } catch (e) {
      Logger.error('Failed to log post creation: $e');
    }
  }
}

/// Processed content result
class ProcessedContent {
  final String content;
  final List<String> warnings;
  final Map<String, dynamic> metadata;

  const ProcessedContent({
    required this.content,
    required this.warnings,
    required this.metadata,
  });
}

/// Processed mentions result
class ProcessedMentions {
  final List<String> mentions;
  final List<String> fromContent;
  final List<String> explicit;

  const ProcessedMentions({
    required this.mentions,
    required this.fromContent,
    required this.explicit,
  });
}

/// User posting permissions model
class UserPostingPermissions {
  final bool canCreatePosts;
  final bool isTemporarilyRestricted;
  final bool rateLimitExceeded;
  final DateTime? rateLimitResetAt;
  final String? restrictionReason;

  const UserPostingPermissions({
    required this.canCreatePosts,
    required this.isTemporarilyRestricted,
    required this.rateLimitExceeded,
    this.rateLimitResetAt,
    this.restrictionReason,
  });
}

/// Content moderation result model
class ContentModerationResult {
  final bool isBlocked;
  final bool requiresReview;
  final String? reason;
  final double? confidenceScore;
  final Map<String, dynamic>? details;

  const ContentModerationResult({
    required this.isBlocked,
    required this.requiresReview,
    this.reason,
    this.confidenceScore,
    this.details,
  });
}

/// Extended methods for PostsRepository
extension CreatePostRepositoryMethods on PostsRepository {
  Future<Either<Failure, UserPostingPermissions>> getUserPostingPermissions(
    String userId,
  ) {
    throw UnimplementedError('getUserPostingPermissions not implemented');
  }

  Future<Either<Failure, List<String>>> uploadMediaFiles(
    List<File> files,
    String userId,
  ) {
    throw UnimplementedError('uploadMediaFiles not implemented');
  }

  Future<Either<Failure, ContentModerationResult>> moderateContent({
    required String content,
    required List<String> mediaUrls,
    required String userId,
  }) {
    throw UnimplementedError('moderateContent not implemented');
  }

  Future<Either<Failure, bool>> checkDuplicatePost({
    required String userId,
    required String content,
    required Duration timeWindow,
  }) {
    throw UnimplementedError('checkDuplicatePost not implemented');
  }

  Future<Either<Failure, PostVisibility>> getUserDefaultVisibility(
    String userId,
  ) {
    throw UnimplementedError('getUserDefaultVisibility not implemented');
  }

  Future<Either<Failure, PostModel>> schedulePost(
    Map<String, dynamic> postData,
    DateTime scheduledAt,
  ) {
    throw UnimplementedError('schedulePost not implemented');
  }

  Future<Either<Failure, PostModel>> queuePostForOffline(
    Map<String, dynamic> postData,
  ) {
    throw UnimplementedError('queuePostForOffline not implemented');
  }

  Future<Either<Failure, PostModel>> createPost(Map<String, dynamic> postData) {
    throw UnimplementedError('createPost not implemented');
  }
}
