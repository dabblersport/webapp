import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/repositories/friends_repository.dart';
import 'package:dabbler/features/social/domain/usecases/friendship_usecases.dart';

/// Simple state for friendship management
class SimpleFriendsState {
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> incomingRequests;
  final List<Map<String, dynamic>> outgoingRequests;
  final List<Map<String, dynamic>> suggestions;
  final List<Map<String, dynamic>> searchResults;
  final Set<String> dismissedSuggestionIds;
  final bool isLoading;
  final bool isLoadingSuggestions;
  final bool isSearching;
  final String? error;
  final Map<String, bool> processingIds;

  const SimpleFriendsState({
    this.friends = const [],
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.suggestions = const [],
    this.searchResults = const [],
    this.dismissedSuggestionIds = const {},
    this.isLoading = false,
    this.isLoadingSuggestions = false,
    this.isSearching = false,
    this.error,
    this.processingIds = const {},
  });

  SimpleFriendsState copyWith({
    List<Map<String, dynamic>>? friends,
    List<Map<String, dynamic>>? incomingRequests,
    List<Map<String, dynamic>>? outgoingRequests,
    List<Map<String, dynamic>>? suggestions,
    List<Map<String, dynamic>>? searchResults,
    Set<String>? dismissedSuggestionIds,
    bool? isLoading,
    bool? isLoadingSuggestions,
    bool? isSearching,
    String? error,
    Map<String, bool>? processingIds,
  }) {
    return SimpleFriendsState(
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      suggestions: suggestions ?? this.suggestions,
      searchResults: searchResults ?? this.searchResults,
      dismissedSuggestionIds:
          dismissedSuggestionIds ?? this.dismissedSuggestionIds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
      isSearching: isSearching ?? this.isSearching,
      error: error,
      processingIds: processingIds ?? this.processingIds,
    );
  }

  int get totalFriendsCount => friends.length;
  int get incomingRequestsCount => incomingRequests.length;
  int get outgoingRequestsCount => outgoingRequests.length;
  int get suggestionsCount => suggestions.length;
}

/// Simplified controller for friendship management using real repository
class SimpleFriendsController extends StateNotifier<SimpleFriendsState> {
  final SendFriendRequestUseCase _sendFriendRequest;
  final AcceptFriendRequestUseCase _acceptFriendRequest;
  final RejectFriendRequestUseCase _rejectFriendRequest;
  final RemoveFriendUseCase _removeFriend;
  // NOTE: BlockUserUseCase/UnblockUserUseCase removed — use BlockRepository from block_providers.dart
  final FriendsRepository _repository;

  SimpleFriendsController({
    required SendFriendRequestUseCase sendFriendRequest,
    required AcceptFriendRequestUseCase acceptFriendRequest,
    required RejectFriendRequestUseCase rejectFriendRequest,
    required RemoveFriendUseCase removeFriend,
    required FriendsRepository repository,
  }) : _sendFriendRequest = sendFriendRequest,
       _acceptFriendRequest = acceptFriendRequest,
       _rejectFriendRequest = rejectFriendRequest,
       _removeFriend = removeFriend,
       _repository = repository,
       super(const SimpleFriendsState());

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }

  /// Load all friends data
  Future<void> loadFriends() async {
    state = state.copyWith(isLoading: true, error: null);

    final friendsResult = await _repository.getFriends();
    final inboxResult = await _repository.inbox();
    final outboxResult = await _repository.outbox();

    friendsResult.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load friends: ${failure.message}',
        );
      },
      (friends) {
        inboxResult.fold(
          (failure) {
            state = state.copyWith(
              isLoading: false,
              error: 'Failed to load incoming requests: ${failure.message}',
            );
          },
          (inbox) {
            outboxResult.fold(
              (failure) {
                state = state.copyWith(
                  isLoading: false,
                  error: 'Failed to load outgoing requests: ${failure.message}',
                );
              },
              (outbox) {
                state = state.copyWith(
                  friends: friends,
                  incomingRequests: inbox,
                  outgoingRequests: outbox,
                  isLoading: false,
                );
              },
            );
          },
        );
      },
    );
  }

  /// Send friend request
  Future<void> sendRequest(String peerUserId) async {
    if (state.processingIds[peerUserId] == true) return;

    state = state.copyWith(
      processingIds: {...state.processingIds, peerUserId: true},
    );

    final result = await _sendFriendRequest(peerUserId);

    result.fold(
      (failure) {
        state = state.copyWith(
          error: failure.message,
          processingIds: {...state.processingIds, peerUserId: false},
        );
      },
      (_) {
        state = state.copyWith(
          processingIds: {...state.processingIds, peerUserId: false},
        );
        // Reload data to get updated state
        loadFriends();
      },
    );
  }

  /// Accept friend request
  Future<void> acceptRequest(String peerUserId) async {
    if (state.processingIds[peerUserId] == true) return;

    state = state.copyWith(
      processingIds: {...state.processingIds, peerUserId: true},
    );

    final result = await _acceptFriendRequest(peerUserId);

    result.fold(
      (failure) {
        state = state.copyWith(
          error: failure.message,
          processingIds: {...state.processingIds, peerUserId: false},
        );
      },
      (_) {
        state = state.copyWith(
          processingIds: {...state.processingIds, peerUserId: false},
        );
        // Reload data to get updated state
        loadFriends();
      },
    );
  }

  /// Reject friend request
  Future<void> rejectRequest(String peerUserId) async {
    if (state.processingIds[peerUserId] == true) return;

    state = state.copyWith(
      processingIds: {...state.processingIds, peerUserId: true},
    );

    final result = await _rejectFriendRequest(peerUserId);

    result.fold(
      (failure) {
        state = state.copyWith(
          error: failure.message,
          processingIds: {...state.processingIds, peerUserId: false},
        );
      },
      (_) {
        state = state.copyWith(
          processingIds: {...state.processingIds, peerUserId: false},
        );
        // Reload data to get updated state
        loadFriends();
      },
    );
  }

  /// Remove friend
  Future<void> removeFriend(String peerUserId) async {
    if (state.processingIds[peerUserId] == true) return;

    state = state.copyWith(
      processingIds: {...state.processingIds, peerUserId: true},
    );

    final result = await _removeFriend(peerUserId);

    result.fold(
      (failure) {
        state = state.copyWith(
          error: failure.message,
          processingIds: {...state.processingIds, peerUserId: false},
        );
      },
      (_) {
        state = state.copyWith(
          processingIds: {...state.processingIds, peerUserId: false},
        );
        // Reload data to get updated state
        loadFriends();
      },
    );
  }

  /// Block user — deprecated, use BlockRepository from block_providers.dart
  Future<void> blockUser(String peerUserId) async {
    // Blocking is now handled by BlockRepository. This method is a no-op stub.
  }

  /// Unblock user — deprecated, use BlockRepository from block_providers.dart
  Future<void> unblockUser(String peerUserId) async {
    // Unblocking is now handled by BlockRepository. This method is a no-op stub.
  }

  /// Load friend suggestions
  Future<void> loadSuggestions() async {
    state = state.copyWith(isLoadingSuggestions: true);

    // Show all available profiles in Suggestions.
    final result = await _repository.listProfiles(limit: 200);

    result.fold(
      (failure) {
        // Suggestions are non-critical. Avoid promoting transient backend
        // failures to a full-screen error state.
        state = state.copyWith(isLoadingSuggestions: false);
      },
      (suggestions) {
        state = state.copyWith(
          suggestions: suggestions,
          isLoadingSuggestions: false,
        );
      },
    );
  }

  /// Search for users
  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: [], isSearching: false);
      return;
    }

    state = state.copyWith(isSearching: true);

    final result = await _repository.searchUsers(query);

    result.fold(
      (failure) {
        state = state.copyWith(
          isSearching: false,
          error: 'Search failed: ${failure.message}',
        );
      },
      (results) {
        state = state.copyWith(searchResults: results, isSearching: false);
      },
    );
  }

  /// Clear search results
  void clearSearch() {
    state = state.copyWith(searchResults: [], isSearching: false);
  }

  void dismissSuggestion(String peerUserId) {
    final trimmed = peerUserId.trim();
    if (trimmed.isEmpty) return;
    if (state.dismissedSuggestionIds.contains(trimmed)) return;

    state = state.copyWith(
      dismissedSuggestionIds: {...state.dismissedSuggestionIds, trimmed},
    );
  }
}
