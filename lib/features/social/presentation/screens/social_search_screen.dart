import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/providers/search_history_provider.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/search_default_view.dart';
import 'package:dabbler/features/social/presentation/widgets/search_results_view.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// The `searchType` route parameter's keys, mapped to the result section they
/// open on.
const Map<String, SearchMode> _kSearchTypes = {
  'people': SearchMode.profiles,
  'posts': SearchMode.posts,
  'games': SearchMode.games,
  'venues': SearchMode.venues,
  'comments': SearchMode.comments,
  'hashtags': SearchMode.hashtags,
  'meetups': SearchMode.meetups,
};

/// Social search screen — empty / results / view-all states
/// (`Search.dc.html`: Search_default, Search_results, View_all_*).
class SocialSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? searchType;

  const SocialSearchScreen({super.key, this.initialQuery, this.searchType});

  @override
  ConsumerState<SocialSearchScreen> createState() => _SocialSearchScreenState();
}

class _SocialSearchScreenState extends ConsumerState<SocialSearchScreen> {
  late TextEditingController _searchController;
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  /// The section the route asked to open on.
  late final SearchMode _initialMode;

  /// When non-null, the screen shows that section as a full list. Back clears
  /// it.
  SearchMode? _viewAllMode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _initialMode = _kSearchTypes[widget.searchType] ?? SearchMode.all;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _triggerSearch(widget.initialQuery!);
      } else {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(DabblerMotion.debounceSearch, () {
      _triggerSearch(query.trim());
    });
  }

  void _triggerSearch(String query) {
    if (query.isEmpty) {
      ref.read(searchProvider.notifier).clear();
      return;
    }
    ref.read(recentSearchHistoryProvider.notifier).add(query);
    ref.read(searchProvider.notifier).search(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchProvider.notifier).clear();
    setState(() => _viewAllMode = null);
    _searchFocus.requestFocus();
  }

  void _onBack() {
    if (_viewAllMode != null) {
      setState(() => _viewAllMode = null);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final recentSearches = ref.watch(recentSearchHistoryProvider);
    final hasQuery = searchState.query.isNotEmpty;
    final mode =
        _viewAllMode ??
        (searchState.mode != SearchMode.all ? searchState.mode : _initialMode);

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        onBack: _onBack,
        border: !hasQuery,
        titleWidget: DabblerSearchField(
          controller: _searchController,
          focusNode: _searchFocus,
          placeholder: 'Search people, games, posts…',
          loading: searchState.isLoading,
          onChanged: _onSearchChanged,
          onSubmitted: _triggerSearch,
          onCleared: _clearSearch,
        ),
      ),
      body: hasQuery
          ? SearchResultsView(
              state: searchState,
              mode: mode,
              onViewAll: (m) => setState(() => _viewAllMode = m),
              onProfileTap: _navigateToSearchProfile,
            )
          : SearchDefaultView(
              recentSearches: recentSearches,
              onPickRecent: (q) {
                _searchController.text = q;
                _triggerSearch(q);
              },
              onRemoveRecent: (q) =>
                  ref.read(recentSearchHistoryProvider.notifier).remove(q),
              onClearRecent: () =>
                  ref.read(recentSearchHistoryProvider.notifier).clear(),
            ),
    );
  }

  Future<void> _navigateToSearchProfile(Profile profile) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final myProfileId = await ref.read(myProfileIdProvider.future);
    if (!mounted) return;
    if (profile.userId == currentUserId && profile.id == myProfileId) {
      context.go(RoutePaths.profile);
    } else {
      context.push(
        '${RoutePaths.userProfile}/${profile.userId}?profileId=${profile.id}',
      );
    }
  }
}
