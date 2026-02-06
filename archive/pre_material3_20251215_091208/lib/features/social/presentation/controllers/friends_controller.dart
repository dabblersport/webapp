import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/add_friend_usecase.dart';
import '../../domain/usecases/block_user_usecase.dart';
import 'package:dabbler/data/models/authentication/user_model.dart';
import 'package:dabbler/data/models/social/friend_request_model.dart';
import 'package:dabbler/data/models/social/friend_request.dart';

/// State for friends management
class FriendsState {
  final Map<FriendStatus, List<UserModel>> friendsByStatus;
  final List<FriendRequestModel> incomingRequests;
  final List<FriendRequestModel> outgoingRequests;
  final Set<String> onlineUsers;
  final List<UserModel> blockedUsers;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final Map<String, DateTime> lastSeenTimes;
  final FriendFilter activeFilter;
  final Map<String, bool> requestProcessingStates;

  const FriendsState({
    this.friendsByStatus = const {},
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.onlineUsers = const {},
    this.blockedUsers = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.lastSeenTimes = const {},
    this.activeFilter = FriendFilter.all,
    this.requestProcessingStates = const {},
  });

  FriendsState copyWith({
    Map<FriendStatus, List<UserModel>>? friendsByStatus,
    List<FriendRequestModel>? incomingRequests,
    List<FriendRequestModel>? outgoingRequests,
    Set<String>? onlineUsers,
    List<UserModel>? blockedUsers,
    bool? isLoading,
    String? error,
    String? searchQuery,
    Map<String, DateTime>? lastSeenTimes,
    FriendFilter? activeFilter,
    Map<String, bool>? requestProcessingStates,
  }) {
    return FriendsState(
      friendsByStatus: friendsByStatus ?? this.friendsByStatus,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      onlineUsers: onlineUsers ?? this.onlineUsers,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      lastSeenTimes: lastSeenTimes ?? this.lastSeenTimes,
      activeFilter: activeFilter ?? this.activeFilter,
      requestProcessingStates:
          requestProcessingStates ?? this.requestProcessingStates,
    );
  }

  // Computed getters
  List<UserModel> get allFriends =>
      friendsByStatus.values.expand((list) => list).toList();

  List<UserModel> get onlineFriends =>
      allFriends.where((friend) => onlineUsers.contains(friend.id)).toList();

  List<UserModel> get filteredFriends {
    final friends = allFriends;

    // Apply search filter
    var filtered = searchQuery.isEmpty
        ? friends
        : friends.where((friend) {
            final name = (friend.fullName ?? '').toLowerCase();
            return name.contains(searchQuery.toLowerCase());
          }).toList();

    // Apply status filter
    switch (activeFilter) {
      case FriendFilter.all:
        return filtered;
      case FriendFilter.online:
        return filtered
            .where((friend) => onlineUsers.contains(friend.id))
            .toList();
      case FriendFilter.offline:
        return filtered
            .where((friend) => !onlineUsers.contains(friend.id))
            .toList();
      case FriendFilter.recent:
        filtered.sort((a, b) {
          final aTime =
              lastSeenTimes[a.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              lastSeenTimes[b.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return filtered.take(20).toList();
      case FriendFilter.close:
        return friendsByStatus[FriendStatus.close] ?? [];
    }
  }

  int get totalFriendsCount => allFriends.length;
  int get onlineFriendsCount => onlineFriends.length;
  int get incomingRequestsCount => incomingRequests.length;
  int get outgoingRequestsCount => outgoingRequests.length;
}

/// Friend status categories
enum FriendStatus {
  close, // Close friends
  regular, // Regular friends
  work, // Work/Professional friends
  sports, // Sports buddies
}

/// Filter options for friends list
enum FriendFilter { all, online, offline, recent, close }

/// Controller for managing friends and friend requests
class FriendsController extends StateNotifier<FriendsState> {
  final AddFriendUseCase _addFriendUseCase;
  final BlockUserUseCase _blockUserUseCase;

  StreamSubscription? _onlineStatusSubscription;
  StreamSubscription? _friendRequestSubscription;
  Timer? _presenceUpdateTimer;

  FriendsController(this._addFriendUseCase, this._blockUserUseCase)
    : super(const FriendsState()) {
    _setupOnlineStatusTracking();
    _setupFriendRequestUpdates();
    _startPresenceUpdates();
  }

  @override
  void dispose() {
    _onlineStatusSubscription?.cancel();
    _friendRequestSubscription?.cancel();
    _presenceUpdateTimer?.cancel();
    super.dispose();
  }

  /// Load friends data
  Future<void> loadFriends() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load friends by status
      final friendsByStatus = <FriendStatus, List<UserModel>>{};

      for (final status in FriendStatus.values) {
        final friends = await _fetchFriendsByStatus(status);
        friendsByStatus[status] = friends;
      }

      // Load friend requests
      final incomingRequests = await _fetchIncomingRequests();
      final outgoingRequests = await _fetchOutgoingRequests();

      // Load blocked users
      final blockedUsers = await _fetchBlockedUsers();

      state = state.copyWith(
        friendsByStatus: friendsByStatus,
        incomingRequests: incomingRequests,
        outgoingRequests: outgoingRequests,
        blockedUsers: blockedUsers,
        isLoading: false,
      );

      // Load online status for friends
      await _updateOnlineStatus();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send friend request
  Future<void> sendFriendRequest(String userId) async {
    if (state.requestProcessingStates[userId] == true) return;

    state = state.copyWith(
      requestProcessingStates: {...state.requestProcessingStates, userId: true},
    );

    try {
      final params = AddFriendParams(
        userId: 'current_user', // From auth state
        targetUserId: userId,
      );

      final result = await _addFriendUseCase(params);

      result.fold(
        (failure) {
          state = state.copyWith(
            error: failure.message,
            requestProcessingStates: {
              ...state.requestProcessingStates,
              userId: false,
            },
          );
        },
        (success) {
          // Add to outgoing requests
          final newRequest = FriendRequestModel(
            id: success.friendship.id,
            fromUserId: 'current_user',
            toUserId: userId,
            status: FriendRequestStatus.pending,
            createdAt: DateTime.now(),
            message: params.message,
          );

          state = state.copyWith(
            outgoingRequests: [...state.outgoingRequests, newRequest],
            requestProcessingStates: {
              ...state.requestProcessingStates,
              userId: false,
            },
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        requestProcessingStates: {
          ...state.requestProcessingStates,
          userId: false,
        },
      );
    }
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    if (state.requestProcessingStates[requestId] == true) return;

    state = state.copyWith(
      requestProcessingStates: {
        ...state.requestProcessingStates,
        requestId: true,
      },
    );

    try {
      final request = state.incomingRequests.firstWhere(
        (req) => req.id == requestId,
      );

      final result = await _acceptRequest(requestId);

      if (result) {
        // Remove from incoming requests
        final updatedIncoming = state.incomingRequests
            .where((req) => req.id != requestId)
            .toList();

        // Add to friends (default to regular status)
        final newFriend = await _fetchUserById(request.fromUserId);
        if (newFriend != null) {
          final regularFriends =
              state.friendsByStatus[FriendStatus.regular] ?? [];
          final updatedFriendsByStatus =
              Map<FriendStatus, List<UserModel>>.from(state.friendsByStatus);
          updatedFriendsByStatus[FriendStatus.regular] = [
            ...regularFriends,
            newFriend,
          ];

          state = state.copyWith(
            incomingRequests: updatedIncoming,
            friendsByStatus: updatedFriendsByStatus,
          );
        }
      }

      state = state.copyWith(
        requestProcessingStates: {
          ...state.requestProcessingStates,
          requestId: false,
        },
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        requestProcessingStates: {
          ...state.requestProcessingStates,
          requestId: false,
        },
      );
    }
  }

  /// Decline friend request
  Future<void> declineFriendRequest(String requestId) async {
    if (state.requestProcessingStates[requestId] == true) return;

    state = state.copyWith(
      requestProcessingStates: {
        ...state.requestProcessingStates,
        requestId: true,
      },
    );

    try {
      final result = await _declineRequest(requestId);

      if (result) {
        // Remove from incoming requests
        final updatedIncoming = state.incomingRequests
            .where((req) => req.id != requestId)
            .toList();

        state = state.copyWith(incomingRequests: updatedIncoming);
      }

      state = state.copyWith(
        requestProcessingStates: {
          ...state.requestProcessingStates,
          requestId: false,
        },
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        requestProcessingStates: {
          ...state.requestProcessingStates,
          requestId: false,
        },
      );
    }
  }

  /// Block user
  Future<void> blockUser(String userId) async {
    if (state.requestProcessingStates[userId] == true) return;

    state = state.copyWith(
      requestProcessingStates: {...state.requestProcessingStates, userId: true},
    );

    try {
      final params = BlockUserParams(
        blockingUserId: 'current_user', // From auth state
        blockedUserId: userId,
      );

      final result = await _blockUserUseCase(params);

      result.fold(
        (failure) {
          state = state.copyWith(
            error: failure.message,
            requestProcessingStates: {
              ...state.requestProcessingStates,
              userId: false,
            },
          );
        },
        (success) {
          // Remove from all friends lists
          final updatedFriendsByStatus = <FriendStatus, List<UserModel>>{};
          for (final entry in state.friendsByStatus.entries) {
            updatedFriendsByStatus[entry.key] = entry.value
                .where((friend) => friend.id != userId)
                .toList();
          }

          // Remove from requests
          final updatedIncoming = state.incomingRequests
              .where((req) => req.fromUserId != userId)
              .toList();
          final updatedOutgoing = state.outgoingRequests
              .where((req) => req.toUserId != userId)
              .toList();

          // Add to blocked users
          final blockedUser = UserModel(
            id: userId,
            fullName: 'Blocked User',
            email: 'blocked@example.com',
            avatarUrl: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          state = state.copyWith(
            friendsByStatus: updatedFriendsByStatus,
            incomingRequests: updatedIncoming,
            outgoingRequests: updatedOutgoing,
            blockedUsers: [...state.blockedUsers, blockedUser],
            requestProcessingStates: {
              ...state.requestProcessingStates,
              userId: false,
            },
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        requestProcessingStates: {
          ...state.requestProcessingStates,
          userId: false,
        },
      );
    }
  }

  /// Unblock user
  Future<void> unblockUser(String userId) async {
    if (state.requestProcessingStates[userId] == true) return;

    state = state.copyWith(
      requestProcessingStates: {...state.requestProcessingStates, userId: true},
    );

    try {
      final result = await _unblockUser(userId);

      if (result) {
        // Remove from blocked users
        final updatedBlocked = state.blockedUsers
            .where((user) => user.id != userId)
            .toList();

        state = state.copyWith(blockedUsers: updatedBlocked);
      }

      state = state.copyWith(
        requestProcessingStates: {
          ...state.requestProcessingStates,
          userId: false,
        },
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        requestProcessingStates: {
          ...state.requestProcessingStates,
          userId: false,
        },
      );
    }
  }

  /// Update friend status (close, regular, etc.)
  Future<void> updateFriendStatus(
    String friendId,
    FriendStatus newStatus,
  ) async {
    try {
      // Find and move friend between status lists
      UserModel? friend;
      FriendStatus? oldStatus;

      for (final entry in state.friendsByStatus.entries) {
        final foundFriend = entry.value.firstWhere(
          (f) => f.id == friendId,
          orElse: () => UserModel(
            id: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (foundFriend.id.isNotEmpty) {
          friend = foundFriend;
          oldStatus = entry.key;
          break;
        }
      }

      if (friend != null && oldStatus != null) {
        final updatedFriendsByStatus = Map<FriendStatus, List<UserModel>>.from(
          state.friendsByStatus,
        );

        // Remove from old status
        updatedFriendsByStatus[oldStatus] = updatedFriendsByStatus[oldStatus]!
            .where((f) => f.id != friendId)
            .toList();

        // Add to new status
        updatedFriendsByStatus[newStatus] = [
          ...updatedFriendsByStatus[newStatus] ?? [],
          friend,
        ];

        state = state.copyWith(friendsByStatus: updatedFriendsByStatus);

        // Update on server
        await _updateFriendStatusOnServer(friendId, newStatus);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Update search query
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Update active filter
  void updateFilter(FriendFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Handle online status update
  void _handleOnlineStatusUpdate(Map<String, bool> statusUpdates) {
    final onlineUsers = Set<String>.from(state.onlineUsers);
    final lastSeenTimes = Map<String, DateTime>.from(state.lastSeenTimes);

    statusUpdates.forEach((userId, isOnline) {
      if (isOnline) {
        onlineUsers.add(userId);
      } else {
        onlineUsers.remove(userId);
        lastSeenTimes[userId] = DateTime.now();
      }
    });

    state = state.copyWith(
      onlineUsers: onlineUsers,
      lastSeenTimes: lastSeenTimes,
    );
  }

  /// Handle new friend request
  void _handleNewFriendRequest(FriendRequestModel request) {
    if (!state.incomingRequests.any((r) => r.id == request.id)) {
      state = state.copyWith(
        incomingRequests: [...state.incomingRequests, request],
      );
    }
  }

  // Private methods for data fetching (mock implementations)
  Future<List<UserModel>> _fetchFriendsByStatus(FriendStatus status) async {
    // Mock implementation - replace with actual repository call
    await Future.delayed(const Duration(milliseconds: 100));

    return List.generate(
      5,
      (index) => UserModel(
        id: '${status.name}_friend_$index',
        fullName: '${status.name.toUpperCase()} Friend $index',
        email: '${status.name}_friend_$index@example.com',
        avatarUrl: 'https://example.com/avatar_$index.jpg',
        createdAt: DateTime.now().subtract(Duration(days: index)),
        updatedAt: DateTime.now().subtract(Duration(days: index)),
      ),
    );
  }

  Future<List<FriendRequestModel>> _fetchIncomingRequests() async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 100));

    return List.generate(
      3,
      (index) => FriendRequestModel(
        id: 'incoming_request_$index',
        fromUserId: 'user_$index',
        toUserId: 'current_user',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now().subtract(Duration(hours: index)),
      ),
    );
  }

  Future<List<FriendRequestModel>> _fetchOutgoingRequests() async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 100));

    return List.generate(
      2,
      (index) => FriendRequestModel(
        id: 'outgoing_request_$index',
        fromUserId: 'current_user',
        toUserId: 'target_user_$index',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now().subtract(Duration(hours: index)),
      ),
    );
  }

  Future<List<UserModel>> _fetchBlockedUsers() async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 100));
    return [];
  }

  Future<UserModel?> _fetchUserById(String userId) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 100));

    return UserModel(
      id: userId,
      fullName: 'User $userId',
      email: 'user_$userId@example.com',
      avatarUrl: 'https://example.com/avatar.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<bool> _acceptRequest(String requestId) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<bool> _declineRequest(String requestId) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<bool> _unblockUser(String userId) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<void> _updateFriendStatusOnServer(
    String friendId,
    FriendStatus status,
  ) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _updateOnlineStatus() async {
    // Mock implementation
    final mockStatus = <String, bool>{};
    for (final friends in state.friendsByStatus.values) {
      for (final friend in friends) {
        mockStatus[friend.id] = DateTime.now().millisecondsSinceEpoch % 2 == 0;
      }
    }
    _handleOnlineStatusUpdate(mockStatus);
  }

  void _setupOnlineStatusTracking() {
    // Setup WebSocket or real-time connection for online status
    _onlineStatusSubscription =
        Stream.periodic(
          const Duration(seconds: 30),
          (index) => <String, bool>{},
        ).listen((statusUpdates) {
          _updateOnlineStatus();
        });
  }

  void _setupFriendRequestUpdates() {
    // Setup real-time friend request notifications
    _friendRequestSubscription = Stream.periodic(const Duration(minutes: 1)).listen((
      _,
    ) async {
      // Check for new friend requests and handle any that are not yet in state
      try {
        final latestIncoming = await _fetchIncomingRequests();
        for (final request in latestIncoming) {
          _handleNewFriendRequest(request);
        }
      } catch (_) {
        // Swallow errors in background polling to avoid breaking subscription
      }
    });
  }

  void _startPresenceUpdates() {
    _presenceUpdateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) => _updateOnlineStatus(),
    );
  }
}
