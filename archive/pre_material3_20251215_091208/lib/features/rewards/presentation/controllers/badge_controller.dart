import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/rewards/badge.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import '../../domain/repositories/rewards_repository.dart';

/// Badge collection sorting options
enum BadgeSortBy { name, rarity, tier, unlockMessage }

/// Badge filtering options
enum BadgeFilter {
  all,
  common,
  uncommon,
  rare,
  epic,
  legendary,
  showcased,
  limited,
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

/// State class for badge management
class BadgeState {
  final List<Badge> userBadges;
  final List<Badge> availableBadges;
  final List<String> showcasedBadgeIds;
  final BadgeFilter selectedFilter;
  final BadgeSortBy sortBy;
  final bool isAscending;
  final String searchQuery;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> stats;
  final DateTime? lastUpdated;

  const BadgeState({
    this.userBadges = const [],
    this.availableBadges = const [],
    this.showcasedBadgeIds = const [],
    this.selectedFilter = BadgeFilter.all,
    this.sortBy = BadgeSortBy.name,
    this.isAscending = true,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.stats = const {},
    this.lastUpdated,
  });

  BadgeState copyWith({
    List<Badge>? userBadges,
    List<Badge>? availableBadges,
    List<String>? showcasedBadgeIds,
    BadgeFilter? selectedFilter,
    BadgeSortBy? sortBy,
    bool? isAscending,
    String? searchQuery,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? stats,
    DateTime? lastUpdated,
  }) {
    return BadgeState(
      userBadges: userBadges ?? this.userBadges,
      availableBadges: availableBadges ?? this.availableBadges,
      showcasedBadgeIds: showcasedBadgeIds ?? this.showcasedBadgeIds,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      sortBy: sortBy ?? this.sortBy,
      isAscending: isAscending ?? this.isAscending,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stats: stats ?? this.stats,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Get filtered and sorted badges
  List<Badge> get filteredBadges {
    var filtered = userBadges.where((badge) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        if (!badge.name.toLowerCase().contains(searchQuery.toLowerCase()) &&
            !badge.unlockMessage.toLowerCase().contains(
              searchQuery.toLowerCase(),
            )) {
          return false;
        }
      }

      // Category filter
      switch (selectedFilter) {
        case BadgeFilter.all:
          return true;
        case BadgeFilter.common:
          return badge.getRarityLabel() == 'Common';
        case BadgeFilter.uncommon:
          return badge.getRarityLabel() == 'Uncommon';
        case BadgeFilter.rare:
          return badge.getRarityLabel() == 'Rare';
        case BadgeFilter.epic:
          return badge.getRarityLabel() == 'Epic';
        case BadgeFilter.legendary:
          return badge.getRarityLabel() == 'Legendary';
        case BadgeFilter.showcased:
          return showcasedBadgeIds.contains(badge.id);
        case BadgeFilter.limited:
          return badge.isLimitedEdition;
        case BadgeFilter.bronze:
          return badge.tier == BadgeTier.bronze;
        case BadgeFilter.silver:
          return badge.tier == BadgeTier.silver;
        case BadgeFilter.gold:
          return badge.tier == BadgeTier.gold;
        case BadgeFilter.platinum:
          return badge.tier == BadgeTier.platinum;
        case BadgeFilter.diamond:
          return badge.tier == BadgeTier.diamond;
      }
    }).toList();

    // Sort badges
    filtered.sort((a, b) {
      int comparison = 0;

      switch (sortBy) {
        case BadgeSortBy.name:
          comparison = a.name.compareTo(b.name);
          break;
        case BadgeSortBy.rarity:
          comparison = a.rarityScore.compareTo(b.rarityScore);
          break;
        case BadgeSortBy.tier:
          comparison = a.tier.index.compareTo(b.tier.index);
          break;
        case BadgeSortBy.unlockMessage:
          comparison = a.unlockMessage.compareTo(b.unlockMessage);
          break;
      }

      return isAscending ? comparison : -comparison;
    });

    return filtered;
  }

  /// Get showcase badges (limited to 6)
  List<Badge> get showcaseBadges {
    return userBadges
        .where((badge) => showcasedBadgeIds.contains(badge.id))
        .take(6)
        .toList();
  }

  /// Get collection stats
  Map<String, dynamic> get collectionStats {
    final total = userBadges.length;
    if (total == 0) {
      return {'total': 0, 'by_rarity': {}, 'completion_rate': 0.0};
    }

    final rarityCount = <String, int>{};
    for (final badge in userBadges) {
      final rarity = badge.getRarityLabel();
      rarityCount[rarity] = (rarityCount[rarity] ?? 0) + 1;
    }

    double totalValue = 0;
    for (final badge in userBadges) {
      totalValue += badge.rarityScore * 10; // Weight by rarity score
    }

    return {
      'total': total,
      'by_rarity': rarityCount,
      'total_value': totalValue.round(),
      'completion_rate': _calculateCompletionRate(),
      'rarest_badge': _getRarestBadge(),
      'most_recent': _getMostRecentBadge(),
    };
  }

  double _calculateCompletionRate() {
    if (availableBadges.isEmpty) return 0.0;
    return (userBadges.length / availableBadges.length) * 100;
  }

  Badge? _getRarestBadge() {
    if (userBadges.isEmpty) return null;

    return userBadges.reduce(
      (current, next) =>
          current.rarityScore > next.rarityScore ? current : next,
    );
  }

  Badge? _getMostRecentBadge() {
    if (userBadges.isEmpty) return null;

    return userBadges.reduce(
      (current, next) =>
          current.createdAt.isAfter(next.createdAt) ? current : next,
    );
  }
}

/// Badge controller for managing badge collection state
class BadgeController extends StateNotifier<BadgeState> {
  final RewardsRepository _repository;
  final String userId;

  BadgeController(this._repository, this.userId) : super(const BadgeState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    await _loadUserBadges();
    await _loadAvailableBadges();
  }

  Future<void> _loadUserBadges() async {
    final result = await _repository.getUserBadges(userId);

    result.fold(
      (failure) =>
          state = state.copyWith(error: failure.toString(), isLoading: false),
      (badges) {
        // Get showcased badges by filtering badges with showcaseOnly = true
        final showcaseResult = _repository.getUserBadges(
          userId,
          showcaseOnly: true,
        );
        showcaseResult.then((showcaseResult) {
          showcaseResult.fold(
            (failure) => {}, // Ignore showcase errors
            (showcaseBadges) {
              final showcasedIds = showcaseBadges
                  .map((badge) => badge.id)
                  .toList();
              state = state.copyWith(
                userBadges: badges,
                showcasedBadgeIds: showcasedIds,
                isLoading: false,
                lastUpdated: DateTime.now(),
              );
            },
          );
        });
      },
    );
  }

  Future<void> _loadAvailableBadges() async {
    // For available badges, we'll assume all user badges are available
    // In a real implementation, you'd have a specific method for this
    // For now, we'll just use empty list or the same as user badges
    state = state.copyWith(availableBadges: state.userBadges);
  }

  /// Updates the search query
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Updates the selected filter
  void updateFilter(BadgeFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  /// Updates the sort criteria
  void updateSort(BadgeSortBy sortBy, {bool? ascending}) {
    state = state.copyWith(
      sortBy: sortBy,
      isAscending: ascending ?? state.isAscending,
    );
  }

  /// Toggles sort direction
  void toggleSortDirection() {
    state = state.copyWith(isAscending: !state.isAscending);
  }

  /// Adds a badge to showcase (max 6)
  Future<void> addToShowcase(String badgeId) async {
    if (state.showcasedBadgeIds.length >= 6) {
      state = state.copyWith(error: 'Maximum 6 badges can be showcased');
      return;
    }

    if (state.showcasedBadgeIds.contains(badgeId)) {
      return; // Already showcased
    }

    final result = await _repository.updateBadgeShowcase(userId, badgeId, true);

    result.fold(
      (failure) => state = state.copyWith(error: failure.toString()),
      (_) {
        final updatedIds = [...state.showcasedBadgeIds, badgeId];
        state = state.copyWith(showcasedBadgeIds: updatedIds, error: null);
      },
    );
  }

  /// Removes a badge from showcase
  Future<void> removeFromShowcase(String badgeId) async {
    final result = await _repository.updateBadgeShowcase(
      userId,
      badgeId,
      false,
    );

    result.fold(
      (failure) => state = state.copyWith(error: failure.toString()),
      (_) {
        final updatedIds = state.showcasedBadgeIds
            .where((id) => id != badgeId)
            .toList();
        state = state.copyWith(showcasedBadgeIds: updatedIds, error: null);
      },
    );
  }

  /// Reorders showcase badges
  Future<void> reorderShowcase(List<String> newOrder) async {
    if (newOrder.length > 6) {
      state = state.copyWith(error: 'Maximum 6 badges can be showcased');
      return;
    }

    // Update each badge's showcase order
    for (int i = 0; i < newOrder.length; i++) {
      await _repository.updateBadgeShowcase(
        userId,
        newOrder[i],
        true,
        showcaseOrder: i,
      );
    }

    state = state.copyWith(showcasedBadgeIds: newOrder, error: null);
  }

  /// Refreshes badge data
  Future<void> refresh() async {
    await _initialize();
  }

  /// Gets badges by rarity level
  List<Badge> getBadgesByRarity(String rarity) {
    return state.userBadges
        .where((badge) => badge.getRarityLabel() == rarity)
        .toList();
  }

  /// Gets badges by tier
  List<Badge> getBadgesByTier(BadgeTier tier) {
    return state.userBadges.where((badge) => badge.tier == tier).toList();
  }

  /// Gets limited edition badges
  List<Badge> getLimitedEditionBadges() {
    return state.userBadges.where((badge) => badge.isLimitedEdition).toList();
  }

  /// Gets rarity distribution
  Map<String, double> getRarityDistribution() {
    final stats = state.collectionStats;
    final rarityCount = stats['by_rarity'] as Map<String, int>;
    final total = stats['total'] as int;

    if (total == 0) return {};

    return rarityCount.map(
      (rarity, count) => MapEntry(rarity, (count / total) * 100),
    );
  }

  /// Gets tier distribution
  Map<BadgeTier, int> getTierDistribution() {
    final distribution = <BadgeTier, int>{};
    for (final tier in BadgeTier.values) {
      distribution[tier] = state.userBadges
          .where((badge) => badge.tier == tier)
          .length;
    }
    return distribution;
  }

  /// Gets collection value (based on rarity scores)
  int getCollectionValue() {
    return state.userBadges.fold(
      0,
      (total, badge) => total + badge.rarityScore,
    );
  }

  /// Clears any error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}
