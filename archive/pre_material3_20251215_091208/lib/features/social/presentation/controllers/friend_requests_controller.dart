import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/add_friend_usecase.dart';
import 'package:dabbler/data/models/social/friend_request_model.dart';
import 'package:dabbler/data/models/authentication/user_model.dart' as core;
import 'package:dabbler/data/models/social/friend_request.dart';

/// State for friend requests management
class FriendRequestsState {
  final List<FriendRequestModel> incomingRequests;
  final List<FriendRequestModel> outgoingRequests;
  final Map<String, core.UserModel>
  requestUsers; // Cache user info for requests
  final Map<String, List<core.UserModel>>
  mutualFriends; // Mutual friends for each request
  final bool isLoading;
  final String? error;
  final Set<String> processingRequests; // Requests being processed
  final Map<String, RequestPreviewInfo> previewInfo;
  final bool hasUnreadNotifications;
  final int notificationCount;
  final FriendRequestFilter activeFilter;

  const FriendRequestsState({
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.requestUsers = const {},
    this.mutualFriends = const {},
    this.isLoading = false,
    this.error,
    this.processingRequests = const {},
    this.previewInfo = const {},
    this.hasUnreadNotifications = false,
    this.notificationCount = 0,
    this.activeFilter = FriendRequestFilter.all,
  });

  FriendRequestsState copyWith({
    List<FriendRequestModel>? incomingRequests,
    List<FriendRequestModel>? outgoingRequests,
    Map<String, core.UserModel>? requestUsers,
    Map<String, List<core.UserModel>>? mutualFriends,
    bool? isLoading,
    String? error,
    Set<String>? processingRequests,
    Map<String, RequestPreviewInfo>? previewInfo,
    bool? hasUnreadNotifications,
    int? notificationCount,
    FriendRequestFilter? activeFilter,
  }) {
    return FriendRequestsState(
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      requestUsers: requestUsers ?? this.requestUsers,
      mutualFriends: mutualFriends ?? this.mutualFriends,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      processingRequests: processingRequests ?? this.processingRequests,
      previewInfo: previewInfo ?? this.previewInfo,
      hasUnreadNotifications:
          hasUnreadNotifications ?? this.hasUnreadNotifications,
      notificationCount: notificationCount ?? this.notificationCount,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  // Computed getters
  int get incomingRequestsCount => incomingRequests.length;
  int get outgoingRequestsCount => outgoingRequests.length;
  int get totalRequestsCount => incomingRequestsCount + outgoingRequestsCount;

  List<FriendRequestModel> get filteredIncomingRequests {
    switch (activeFilter) {
      case FriendRequestFilter.all:
        return incomingRequests;
      case FriendRequestFilter.recent:
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        return incomingRequests
            .where((req) => req.createdAt.isAfter(cutoff))
            .toList();
      case FriendRequestFilter.mutual:
        return incomingRequests
            .where((req) => mutualFriends[req.fromUserId]?.isNotEmpty ?? false)
            .toList();
    }
  }

  bool get hasPendingRequests => incomingRequestsCount > 0;
  bool get hasProcessingRequests => processingRequests.isNotEmpty;
}

/// Request preview information
class RequestPreviewInfo {
  final int mutualFriendsCount;
  final List<String> commonSports;
  final String? lastInteraction;
  final double compatibilityScore;
  final bool isFromSameLocation;

  const RequestPreviewInfo({
    this.mutualFriendsCount = 0,
    this.commonSports = const [],
    this.lastInteraction,
    this.compatibilityScore = 0.0,
    this.isFromSameLocation = false,
  });
}

/// Filter options for friend requests
enum FriendRequestFilter {
  all,
  recent,
  mutual, // Has mutual friends
}

/// Controller for managing friend requests
class FriendRequestsController extends StateNotifier<FriendRequestsState> {
  final AddFriendUseCase _addFriendUseCase;

  StreamSubscription? _requestUpdatesSubscription;
  Timer? _refreshTimer;

  FriendRequestsController(this._addFriendUseCase)
    : super(const FriendRequestsState()) {
    _setupRealtimeUpdates();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _requestUpdatesSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Load all friend requests
  Future<void> loadFriendRequests() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load incoming and outgoing requests in parallel
      final results = await Future.wait([
        _fetchIncomingRequests(),
        _fetchOutgoingRequests(),
      ]);

      final incomingRequests = results[0];
      final outgoingRequests = results[1];

      // Cache user information for all requests
      final userIds = <String>{};
      userIds.addAll(incomingRequests.map((req) => req.fromUserId));
      userIds.addAll(outgoingRequests.map((req) => req.toUserId));

      final requestUsers = await _fetchUsersInfo(userIds.toList());

      // Load mutual friends for incoming requests
      final mutualFriends = <String, List<core.UserModel>>{};
      for (final request in incomingRequests) {
        mutualFriends[request.fromUserId] = await _fetchMutualFriends(
          request.fromUserId,
        );
      }

      // Load preview info for incoming requests
      final previewInfo = <String, RequestPreviewInfo>{};
      for (final request in incomingRequests) {
        previewInfo[request.fromUserId] = await _generatePreviewInfo(
          request.fromUserId,
        );
      }

      state = state.copyWith(
        incomingRequests: incomingRequests,
        outgoingRequests: outgoingRequests,
        requestUsers: requestUsers,
        mutualFriends: mutualFriends,
        previewInfo: previewInfo,
        isLoading: false,
        hasUnreadNotifications: incomingRequests.isNotEmpty,
        notificationCount: incomingRequests.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    if (state.processingRequests.contains(requestId)) return;

    state = state.copyWith(
      processingRequests: {...state.processingRequests, requestId},
    );

    try {
      final request = state.incomingRequests.firstWhere(
        (req) => req.id == requestId,
      );

      final params = AddFriendParams(
        userId: 'current_user', // From auth state
        targetUserId: request.fromUserId,
        message: 'Accepted friend request',
      );

      final result = await _addFriendUseCase(params);

      result.fold(
        (failure) {
          state = state.copyWith(
            error: failure.message,
            processingRequests: state.processingRequests.difference({
              requestId,
            }),
          );
        },
        (success) {
          // Remove from incoming requests
          final updatedIncoming = state.incomingRequests
              .where((req) => req.id != requestId)
              .toList();

          // Update notification count
          final newCount = Math.max(0, state.notificationCount - 1);

          state = state.copyWith(
            incomingRequests: updatedIncoming,
            processingRequests: state.processingRequests.difference({
              requestId,
            }),
            notificationCount: newCount,
            hasUnreadNotifications: newCount > 0,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        processingRequests: state.processingRequests.difference({requestId}),
      );
    }
  }

  /// Decline friend request
  Future<void> declineFriendRequest(String requestId) async {
    if (state.processingRequests.contains(requestId)) return;

    state = state.copyWith(
      processingRequests: {...state.processingRequests, requestId},
    );

    try {
      final success = await _declineFriendRequest(requestId);

      if (success) {
        // Remove from incoming requests
        final updatedIncoming = state.incomingRequests
            .where((req) => req.id != requestId)
            .toList();

        // Update notification count
        final newCount = Math.max(0, state.notificationCount - 1);

        state = state.copyWith(
          incomingRequests: updatedIncoming,
          notificationCount: newCount,
          hasUnreadNotifications: newCount > 0,
        );
      }

      state = state.copyWith(
        processingRequests: state.processingRequests.difference({requestId}),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        processingRequests: state.processingRequests.difference({requestId}),
      );
    }
  }

  /// Cancel outgoing friend request
  Future<void> cancelFriendRequest(String requestId) async {
    if (state.processingRequests.contains(requestId)) return;

    state = state.copyWith(
      processingRequests: {...state.processingRequests, requestId},
    );

    try {
      final success = await _cancelFriendRequest(requestId);

      if (success) {
        // Remove from outgoing requests
        final updatedOutgoing = state.outgoingRequests
            .where((req) => req.id != requestId)
            .toList();

        state = state.copyWith(outgoingRequests: updatedOutgoing);
      }

      state = state.copyWith(
        processingRequests: state.processingRequests.difference({requestId}),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        processingRequests: state.processingRequests.difference({requestId}),
      );
    }
  }

  /// Accept multiple friend requests
  Future<void> acceptMultipleRequests(List<String> requestIds) async {
    if (requestIds.isEmpty) return;

    // Add all requests to processing state
    final processingIds = {...state.processingRequests, ...requestIds};
    state = state.copyWith(processingRequests: processingIds);

    final results = <String, bool>{};

    // Process requests in parallel (with some limit to avoid overwhelming the server)
    const batchSize = 3;
    for (int i = 0; i < requestIds.length; i += batchSize) {
      final batch = requestIds.skip(i).take(batchSize).toList();

      final batchResults = await Future.wait(
        batch.map((requestId) => _acceptSingleRequest(requestId)),
      );

      for (int j = 0; j < batch.length; j++) {
        results[batch[j]] = batchResults[j];
      }
    }

    // Update state based on results
    final successfulIds = results.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final updatedIncoming = state.incomingRequests
        .where((req) => !successfulIds.contains(req.id))
        .toList();

    final newCount = Math.max(
      0,
      state.notificationCount - successfulIds.length,
    );

    state = state.copyWith(
      incomingRequests: updatedIncoming,
      processingRequests: state.processingRequests.difference(
        requestIds.toSet(),
      ),
      notificationCount: newCount,
      hasUnreadNotifications: newCount > 0,
    );
  }

  /// Decline multiple friend requests
  Future<void> declineMultipleRequests(List<String> requestIds) async {
    if (requestIds.isEmpty) return;

    // Add all requests to processing state
    final processingIds = {...state.processingRequests, ...requestIds};
    state = state.copyWith(processingRequests: processingIds);

    final results = <String, bool>{};

    // Process requests in parallel (with batch limit)
    const batchSize = 5;
    for (int i = 0; i < requestIds.length; i += batchSize) {
      final batch = requestIds.skip(i).take(batchSize).toList();

      final batchResults = await Future.wait(
        batch.map((requestId) => _declineFriendRequest(requestId)),
      );

      for (int j = 0; j < batch.length; j++) {
        results[batch[j]] = batchResults[j];
      }
    }

    // Update state based on results
    final successfulIds = results.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final updatedIncoming = state.incomingRequests
        .where((req) => !successfulIds.contains(req.id))
        .toList();

    final newCount = Math.max(
      0,
      state.notificationCount - successfulIds.length,
    );

    state = state.copyWith(
      incomingRequests: updatedIncoming,
      processingRequests: state.processingRequests.difference(
        requestIds.toSet(),
      ),
      notificationCount: newCount,
      hasUnreadNotifications: newCount > 0,
    );
  }

  /// Mark notifications as read
  void markNotificationsAsRead() {
    state = state.copyWith(hasUnreadNotifications: false, notificationCount: 0);
  }

  /// Update filter
  void updateFilter(FriendRequestFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  /// Get user info for request
  core.UserModel? getUserForRequest(String userId) {
    return state.requestUsers[userId];
  }

  /// Get mutual friends for request
  List<core.UserModel> getMutualFriendsForRequest(String userId) {
    return state.mutualFriends[userId] ?? [];
  }

  /// Get preview info for request
  RequestPreviewInfo? getPreviewInfoForRequest(String userId) {
    return state.previewInfo[userId];
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Handle new friend request (from real-time updates)
  void _handleNewFriendRequest(FriendRequestModel request) {
    // Check if request already exists
    if (state.incomingRequests.any((req) => req.id == request.id)) return;

    // Add to incoming requests
    final updatedIncoming = [request, ...state.incomingRequests];

    state = state.copyWith(
      incomingRequests: updatedIncoming,
      notificationCount: state.notificationCount + 1,
      hasUnreadNotifications: true,
    );

    // Load additional info for the new request
    _loadRequestInfo(request);
  }

  /// Load additional info for a request
  Future<void> _loadRequestInfo(FriendRequestModel request) async {
    try {
      // Load user info
      final userInfo = await _fetchUserInfo(request.fromUserId);
      if (userInfo != null) {
        final updatedRequestUsers = Map<String, core.UserModel>.from(
          state.requestUsers,
        );
        updatedRequestUsers[request.fromUserId] = userInfo;

        state = state.copyWith(requestUsers: updatedRequestUsers);
      }

      // Load mutual friends
      final mutualFriendsList = await _fetchMutualFriends(request.fromUserId);
      final updatedMutualFriends = Map<String, List<core.UserModel>>.from(
        state.mutualFriends,
      );
      updatedMutualFriends[request.fromUserId] = mutualFriendsList;

      // Load preview info
      final preview = await _generatePreviewInfo(request.fromUserId);
      final updatedPreviewInfo = Map<String, RequestPreviewInfo>.from(
        state.previewInfo,
      );
      updatedPreviewInfo[request.fromUserId] = preview;

      state = state.copyWith(
        mutualFriends: updatedMutualFriends,
        previewInfo: updatedPreviewInfo,
      );
    } catch (e) {
      // Silently fail - this is additional info loading
    }
  }

  // Private helper methods (mock implementations)
  Future<List<FriendRequestModel>> _fetchIncomingRequests() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return List.generate(
      3,
      (index) => FriendRequestModel(
        id: 'incoming_request_$index',
        fromUserId: 'sender_user_$index',
        toUserId: 'current_user',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now().subtract(Duration(hours: index)),
        message: index % 2 == 0 ? 'Hi! I\'d like to connect with you.' : null,
      ),
    );
  }

  Future<List<FriendRequestModel>> _fetchOutgoingRequests() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return List.generate(
      2,
      (index) => FriendRequestModel(
        id: 'outgoing_request_$index',
        fromUserId: 'current_user',
        toUserId: 'recipient_user_$index',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now().subtract(Duration(hours: index)),
      ),
    );
  }

  Future<Map<String, core.UserModel>> _fetchUsersInfo(
    List<String> userIds,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final users = <String, core.UserModel>{};
    for (final userId in userIds) {
      users[userId] = core.UserModel(
        id: userId,
        fullName: 'User $userId',
        email: 'user_${userId.split('_').last}@example.com',
        avatarUrl: 'https://example.com/avatar_${userId.split('_').last}.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return users;
  }

  Future<core.UserModel?> _fetchUserInfo(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));

    return core.UserModel(
      id: userId,
      fullName: 'User $userId',
      email: 'user_${userId.split('_').last}@example.com',
      avatarUrl: 'https://example.com/avatar_${userId.split('_').last}.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<List<core.UserModel>> _fetchMutualFriends(String userId) async {
    await Future.delayed(const Duration(milliseconds: 150));

    final mutualCount = DateTime.now().millisecondsSinceEpoch % 5;
    return List.generate(
      mutualCount,
      (index) => core.UserModel(
        id: 'mutual_friend_${userId}_$index',
        fullName: 'Mutual Friend $index',
        email: 'mutual_friend_$index@example.com',
        avatarUrl: 'https://example.com/mutual_avatar_$index.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<RequestPreviewInfo> _generatePreviewInfo(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));

    return RequestPreviewInfo(
      mutualFriendsCount: DateTime.now().millisecondsSinceEpoch % 10,
      commonSports: [
        'Football',
        'Basketball',
      ].take(DateTime.now().millisecondsSinceEpoch % 3).toList(),
      compatibilityScore: (DateTime.now().millisecondsSinceEpoch % 100) / 100.0,
      isFromSameLocation: DateTime.now().millisecondsSinceEpoch % 2 == 0,
    );
  }

  Future<bool> _acceptSingleRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true; // Mock successful acceptance
  }

  Future<bool> _declineFriendRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true; // Mock successful decline
  }

  Future<bool> _cancelFriendRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true; // Mock successful cancellation
  }

  void _setupRealtimeUpdates() {
    // Mock real-time friend request updates
    _requestUpdatesSubscription = Stream.periodic(
      const Duration(minutes: 2),
      (index) => FriendRequestModel(
        id: 'realtime_request_$index',
        fromUserId: 'realtime_user_$index',
        toUserId: 'current_user',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now(),
        message: 'Real-time friend request $index',
      ),
    ).listen(_handleNewFriendRequest);
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) => loadFriendRequests(),
    );
  }
}

/// Helper class for math operations
class Math {
  static T max<T extends Comparable>(T a, T b) => a.compareTo(b) >= 0 ? a : b;
  static T min<T extends Comparable>(T a, T b) => a.compareTo(b) <= 0 ? a : b;
}
