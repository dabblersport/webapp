import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/constants/adaptive_destinations.dart';
import 'package:dabbler/core/design_system/tokens/avatar_color_palette.dart';
import 'package:dabbler/core/design_system/widgets/ds_avatar.dart';
import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/search/comment_search_result.dart';
import 'package:dabbler/data/models/search/hashtag_search_result.dart';
import 'package:dabbler/data/models/search/meetup_search_result.dart';
import 'package:dabbler/data/models/search/post_search_result.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/providers/search_providers.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:dabbler/widgets/dynamic_background.dart';

// =============================================================================
// Accent palette — sport / category identity colors. Theme tokens (cs.*) are
// used for surfaces, borders, and text. Only these accents stay hardcoded.
// =============================================================================

const _kPink   = Color(0xFFFF3376);
const _kAmber  = Color(0xFFF4C430);
const _kOrange = Color(0xFFFF6D00);
const _kCyan   = Color(0xFF00BCD4);
const _kGreen  = Color(0xFF00C853);

Color _sportColor(String? key) {
  switch (key?.toLowerCase()) {
    case 'football':
    case 'soccer':
    case 'futsal':
      return _kGreen;
    case 'basketball':
      return _kOrange;
    case 'tennis':
      return _kAmber;
    case 'padel':
      return const Color(0xFF7328CE);
    case 'cricket':
      return const Color(0xFF8BC34A);
    case 'swimming':
      return _kCyan;
    case 'running':
      return const Color(0xFF00B0FF);
    case 'volleyball':
      return const Color(0xFFE040FB);
    default:
      return const Color(0xFF7328CE);
  }
}

// =============================================================================
// Search tabs — order MUST match SearchNotifier._tabIndexForMode.
//   0 → All, 1 → People, 2 → Posts, 3 → Games, 4 → Venues,
//   5 → Comments, 6 → Hashtags, 7 → Meetups
// =============================================================================

class SearchTab {
  final String key;
  final String label;
  final IconData icon;
  const SearchTab({required this.key, required this.label, required this.icon});
}

const List<SearchTab> _kSearchTabs = [
  SearchTab(key: 'all',      label: 'All',      icon: Iconsax.search_normal_copy),
  SearchTab(key: 'people',   label: 'People',   icon: Iconsax.people_copy),
  SearchTab(key: 'posts',    label: 'Posts',    icon: Iconsax.message_copy),
  SearchTab(key: 'games',    label: 'Games',    icon: Iconsax.game_copy),
  SearchTab(key: 'venues',   label: 'Venues',   icon: Iconsax.buildings_copy),
  SearchTab(key: 'comments', label: 'Comments', icon: Iconsax.messages_2_copy),
  SearchTab(key: 'hashtags', label: 'Hashtags', icon: Iconsax.hashtag_copy),
  SearchTab(key: 'meetups',  label: 'Meet-ups', icon: Iconsax.calendar_copy),
];

/// Social search screen — empty / results / view-all states.
class SocialSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? searchType;

  const SocialSearchScreen({super.key, this.initialQuery, this.searchType});

  @override
  ConsumerState<SocialSearchScreen> createState() => _SocialSearchScreenState();
}

class _SocialSearchScreenState extends ConsumerState<SocialSearchScreen>
    with TickerProviderStateMixin {
  late TextEditingController _searchController;
  late TabController _tabController;
  late final String _previousCategory;

  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  final List<ScrollController> _scrollControllers =
      List.generate(_kSearchTabs.length, (_) => ScrollController());

  /// When non-null, the screen is in "View all" drilldown mode for that
  /// section. Tapping back clears it.
  SearchMode? _viewAllMode;

  @override
  void initState() {
    super.initState();
    _previousCategory = AppTheme.activeCategory;
    AppTheme.setActiveCategory('social');

    _searchController = TextEditingController(text: widget.initialQuery ?? '');

    final initialTabIndex = widget.searchType != null
        ? _kSearchTabs.indexWhere((t) => t.key == widget.searchType)
        : 0;

    _tabController = TabController(
      length: _kSearchTabs.length,
      vsync: this,
      initialIndex: initialTabIndex.clamp(0, _kSearchTabs.length - 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

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
    AppTheme.setActiveCategory(_previousCategory);
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _tabController.dispose();
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search helpers
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _triggerSearch(query.trim());
    });
  }

  void _triggerSearch(String query) {
    if (query.isEmpty) {
      ref.read(searchProvider.notifier).clear();
      return;
    }
    ref.read(searchProvider.notifier).search(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchProvider.notifier).clear();
    _searchFocus.requestFocus();
  }

  void _maybeAutoSwitchTab(SearchState state) {
    final idx = state.forcedTabIndex;
    if (idx >= 0 && idx < _kSearchTabs.length && _tabController.index != idx) {
      _tabController.animateTo(idx);
    }
  }

  void _openViewAll(SearchMode mode) {
    setState(() => _viewAllMode = mode);
  }

  void _closeViewAll() {
    setState(() => _viewAllMode = null);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    ref.listen<SearchState>(searchProvider, (_, next) {
      _maybeAutoSwitchTab(next);
    });

    final isWide =
        MediaQuery.sizeOf(context).width >= AdaptiveBreakpoints.compact;

    if (isWide) return _buildWideLayout(searchState);
    return _buildMobileLayout(searchState);
  }

  // ---------------------------------------------------------------------------
  // Mobile layout
  // ---------------------------------------------------------------------------

  Widget _buildMobileLayout(SearchState state) {
    final cs = Theme.of(context).colorScheme;

    if (_viewAllMode != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            DynamicBackground(scrollController: _scrollControllers[0]),
            SafeArea(
              child: _ViewAllScreen(
                mode: _viewAllMode!,
                query: state.query,
                state: state,
                onBack: _closeViewAll,
                onProfileTap: _navigateToSearchProfile,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          DynamicBackground(
            tabController: _tabController,
            scrollControllers: _scrollControllers,
          ),
          SafeArea(
            child: Column(
              children: [
                _SearchHeader(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  tabController: _tabController,
                  hasQuery: state.query.isNotEmpty,
                  onChanged: _onSearchChanged,
                  onSubmitted: _triggerSearch,
                  onClear: _clearSearch,
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: state.query.isEmpty
                      ? _EmptyState(
                          onPickRecent: (q) {
                            _searchController.text = q;
                            _triggerSearch(q);
                          },
                          onTapGrammar: (prefix) {
                            _searchController.text = prefix;
                            _searchController.selection =
                                TextSelection.collapsed(offset: prefix.length);
                            _searchFocus.requestFocus();
                          },
                          scrollController: _scrollControllers[0],
                        )
                      : _ResultsRouter(
                          state: state,
                          tabController: _tabController,
                          scrollControllers: _scrollControllers,
                          onViewAll: _openViewAll,
                          onProfileTap: _navigateToSearchProfile,
                        ),
                ),
              ],
            ),
          ),
          if (state.isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 110,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: cs.outlineVariant, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Searching…',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Wide layout
  // ---------------------------------------------------------------------------

  Widget _buildWideLayout(SearchState state) {
    final cs = Theme.of(context).colorScheme;
    return AdaptiveScaffold(
      currentIndex: 4,
      onDestinationSelected: (i) =>
          onAdaptiveDestinationSelected(context, i, activeIndex: 4),
      destinations: kAdaptiveDestinations,
      headerWidget: SvgPicture.asset(
        'assets/images/dabbler_text_logo.svg',
        width: 100,
        height: 18,
        colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
      ),
      background: DynamicBackground(
        tabController: _tabController,
        scrollControllers: _scrollControllers,
      ),
      body: _viewAllMode != null
          ? _ViewAllScreen(
              mode: _viewAllMode!,
              query: state.query,
              state: state,
              onBack: _closeViewAll,
              onProfileTap: _navigateToSearchProfile,
            )
          : Column(
              children: [
                _SearchHeader(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  tabController: _tabController,
                  hasQuery: state.query.isNotEmpty,
                  onChanged: _onSearchChanged,
                  onSubmitted: _triggerSearch,
                  onClear: _clearSearch,
                  showBack: false,
                ),
                Expanded(
                  child: state.query.isEmpty
                      ? _EmptyState(
                          onPickRecent: (q) {
                            _searchController.text = q;
                            _triggerSearch(q);
                          },
                          onTapGrammar: (prefix) {
                            _searchController.text = prefix;
                            _searchController.selection =
                                TextSelection.collapsed(offset: prefix.length);
                            _searchFocus.requestFocus();
                          },
                          scrollController: _scrollControllers[0],
                        )
                      : _ResultsRouter(
                          state: state,
                          tabController: _tabController,
                          scrollControllers: _scrollControllers,
                          onViewAll: _openViewAll,
                          onProfileTap: _navigateToSearchProfile,
                        ),
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile navigation
  // ---------------------------------------------------------------------------

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

// =============================================================================
// HEADER — search input + tab strip
// =============================================================================

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.tabController,
    required this.hasQuery,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.onBack,
    this.showBack = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TabController tabController;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tabIndex = tabController.index;
    final hint = tabIndex == 0
        ? 'Search people, games, posts…'
        : 'Search ${_kSearchTabs[tabIndex].label.toLowerCase()}…';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  onPressed: onBack,
                  icon: Icon(Iconsax.arrow_left_2_copy,
                      size: 22, color: cs.onSurface),
                  splashRadius: 22,
                ),
              Expanded(
                child: AnimatedBuilder(
                  animation: focusNode,
                  builder: (ctx, _) {
                    final focused = focusNode.hasFocus;
                    return Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: focused ? cs.primary : cs.outlineVariant,
                          width: focused ? 2 : 1.5,
                        ),
                        boxShadow: focused
                            ? [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.10),
                                  blurRadius: 0,
                                  spreadRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.search_normal_copy,
                            size: 18,
                            color: focused ? cs.primary : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: onChanged,
                              onSubmitted: onSubmitted,
                              cursorColor: cs.primary,
                              textAlignVertical: TextAlignVertical.center,
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                filled: true,
                                fillColor: cs.surface,
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: hint,
                                hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          if (hasQuery)
                            GestureDetector(
                              onTap: onClear,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.surfaceContainerLow,
                                ),
                                child: Icon(Icons.close,
                                    size: 12, color: cs.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (hasQuery) ...[
            const SizedBox(height: 6),
            _TabStrip(controller: tabController),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w600, letterSpacing: -0.1),
        unselectedLabelStyle:
            Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w500),
        indicatorWeight: 2.5,
        indicatorColor: cs.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: _kSearchTabs
            .map(
              (t) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 14),
                    const SizedBox(width: 6),
                    Text(t.label),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// =============================================================================
// EMPTY STATE — recent / shortcuts / trending / grammar / quick filters
// Static placeholders for trending + suggestions until backend RPCs land.
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onPickRecent,
    required this.onTapGrammar,
    required this.scrollController,
  });

  final ValueChanged<String> onPickRecent;
  final ValueChanged<String> onTapGrammar;
  final ScrollController scrollController;

  static const _recent = [
    '#football',
    '@ahmed_fc',
    'padel courts dubai',
    'sunday meetup',
    '#nbaplayoffs',
  ];

  static const _trendingTags = [
    (tag: '#worldcup2026',  posts: '48.2k', sport: 'football',   delta: '+212%'),
    (tag: '#padelnight',    posts: '12.4k', sport: 'padel',      delta: '+78%'),
    (tag: '#sundayrun',     posts: '8.1k',  sport: 'running',    delta: '+34%'),
    (tag: '#hoopsindubai',  posts: '5.6k',  sport: 'basketball', delta: '+22%'),
    (tag: '#cricketleague', posts: '4.9k',  sport: 'cricket',    delta: '+18%'),
  ];

  static const _grammar = [
    (tag: '@',  label: 'people',   accent: 'primary', icon: Iconsax.user_copy),
    (tag: '#',  label: 'hashtags', accent: 'pink',    icon: Iconsax.hashtag_copy),
    (tag: '/g', label: 'games',    accent: 'green',   icon: Iconsax.game_copy),
    (tag: '/v', label: 'venues',   accent: 'cyan',    icon: Iconsax.location_copy),
    (tag: '/p', label: 'posts',    accent: 'orange',  icon: Iconsax.document_text_copy),
    (tag: '/c', label: 'comments', accent: 'amber',   icon: Iconsax.message_copy),
    (tag: '/m', label: 'meetups',  accent: 'orange',  icon: Iconsax.calendar_copy),
  ];

  Color _accent(String key, ColorScheme cs) {
    switch (key) {
      case 'pink':   return _kPink;
      case 'green':  return _kGreen;
      case 'cyan':   return _kCyan;
      case 'orange': return _kOrange;
      case 'amber':  return _kAmber;
      default:       return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 6, bottom: 80),
      children: [
        _SectionLabel(
          icon: Iconsax.clock_copy,
          label: 'Recent',
          trailing: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: cs.primary,
            ),
            child: Text(
              'Clear',
              style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _recent
                .map((q) => _RecentChip(query: q, onTap: () => onPickRecent(q)))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Column(
            children: const [
              _QuickAccessCard(
                icon: Iconsax.people_copy,
                accentKey: 'green',
                title: 'People nearby',
                subtitle: '127 active in 5 km',
              ),
              SizedBox(height: 8),
              _QuickAccessCard(
                icon: Iconsax.game_copy,
                accentKey: 'primary',
                title: 'Popular games',
                subtitle: 'Open spots today',
              ),
              SizedBox(height: 8),
              _QuickAccessCard(
                icon: Iconsax.activity_copy,
                accentKey: 'pink',
                title: 'Trending posts',
                subtitle: 'What everyone’s on',
              ),
            ],
          ),
        ),
        _SectionLabel(
          icon: Icons.local_fire_department_outlined,
          iconColor: _kPink,
          label: 'Trending now',
          trailing: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: cs.primary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View all',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w700),
                ),
                Icon(Iconsax.arrow_right_3_copy, size: 14),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: List.generate(_trendingTags.length, (i) {
                final t = _trendingTags[i];
                final sc = _sportColor(t.sport);
                return _TrendingRow(
                  rank: i + 1,
                  tag: t.tag,
                  posts: t.posts,
                  delta: t.delta,
                  accent: sc,
                  showDivider: i > 0,
                  onTap: () => onPickRecent(t.tag),
                );
              }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'SEARCH SMARTER',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 4.4,
            children: _grammar.map((g) {
              final c = _accent(g.accent, cs);
              return _GrammarChip(
                icon: g.icon,
                label: 'Search ${g.label}',
                accent: c,
                onTap: () => onTapGrammar(
                    g.tag == '@' || g.tag == '#' ? g.tag : '${g.tag} '),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Icon(Iconsax.filter_copy,
                  size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'QUICK FILTERS',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              _FilterChip(label: 'Near me',
                  icon: Iconsax.location_copy, active: true),
              _FilterChip(label: 'Today', icon: Iconsax.clock_copy),
              _FilterChip(label: 'This week'),
              _FilterChip(label: 'Friends only'),
              _FilterChip(label: 'Popular'),
              _FilterChip(label: 'Free entry'),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.query, required this.onTap});
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Iconsax.clock_copy, size: 11, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            query,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.close,
              size: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.accentKey,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String accentKey;
  final String title;
  final String subtitle;

  Color _accent(ColorScheme cs) {
    switch (accentKey) {
      case 'pink':   return _kPink;
      case 'green':  return _kGreen;
      case 'cyan':   return _kCyan;
      case 'orange': return _kOrange;
      case 'amber':  return _kAmber;
      default:       return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accent(cs);
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.outlineVariant, width: 1),
            ),
            child: Icon(Iconsax.arrow_right_3_copy,
                size: 16, color: cs.onSurfaceVariant),
          ),
        ]),
    );
  }
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({
    required this.rank,
    required this.tag,
    required this.posts,
    required this.delta,
    required this.accent,
    required this.showDivider,
    required this.onTap,
  });
  final int rank;
  final String tag;
  final String posts;
  final String delta;
  final Color accent;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(top: BorderSide(color: cs.outlineVariant))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          SizedBox(
            width: 24,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('#',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.w900,
                      color: accent,
                      height: 1)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tag,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                const SizedBox(height: 2),
                Row(children: [
                  Text('$posts posts',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: cs.onSurfaceVariant)),
                  if (delta.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.trending_up, size: 11, color: _kGreen),
                    const SizedBox(width: 2),
                    Text(delta,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _kGreen)),
                  ],
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _GrammarChip extends StatelessWidget {
  const _GrammarChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.icon, this.active = false});
  final String label;
  final IconData? icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = active ? cs.primary : cs.surface;
    final fg = active ? cs.onPrimary : cs.onSurface;
    final border = active ? cs.primary : cs.outlineVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: fg,
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// SECTION HEAD — re-used across results state
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    this.iconColor,
    this.count,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final Color? iconColor;
  final String? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(children: [
        Icon(icon, size: 16, color: iconColor ?? cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.1,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '· $count',
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: cs.primary,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          'View all',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w700),
        ),
        Icon(Iconsax.arrow_right_3_copy, size: 14),
      ]),
    );
  }
}

// =============================================================================
// RESULTS ROUTER — All tab → sectioned scroll, specific tab → full list
// =============================================================================

class _ResultsRouter extends StatelessWidget {
  const _ResultsRouter({
    required this.state,
    required this.tabController,
    required this.scrollControllers,
    required this.onViewAll,
    required this.onProfileTap,
  });

  final SearchState state;
  final TabController tabController;
  final List<ScrollController> scrollControllers;
  final ValueChanged<SearchMode> onViewAll;
  final ValueChanged<Profile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (state.error != null && !state.hasResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(state.error!,
                style: TextStyle(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (!state.hasResults && !state.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No results for "${state.query}"',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _AllTabSections(
          state: state,
          scrollController: scrollControllers[0],
          onViewAll: onViewAll,
          onProfileTap: onProfileTap,
        ),
        _PeopleList(
          profiles: state.bundle.profiles,
          query: state.query,
          scrollController: scrollControllers[1],
          onTap: onProfileTap,
        ),
        _PostsList(
          posts: state.bundle.posts,
          query: state.query,
          scrollController: scrollControllers[2],
        ),
        _GamesList(
          games: state.bundle.games,
          query: state.query,
          scrollController: scrollControllers[3],
        ),
        _VenuesList(
          venues: state.bundle.venues,
          query: state.query,
          scrollController: scrollControllers[4],
        ),
        _CommentsList(
          comments: state.bundle.comments,
          query: state.query,
          scrollController: scrollControllers[5],
        ),
        _HashtagsList(
          hashtags: state.bundle.hashtags,
          query: state.query,
          scrollController: scrollControllers[6],
        ),
        _MeetupsList(
          meetups: state.bundle.meetups,
          query: state.query,
          scrollController: scrollControllers[7],
        ),
      ],
    );
  }
}

// =============================================================================
// ALL TAB — sectioned previews with View all chevrons
// =============================================================================

class _AllTabSections extends StatelessWidget {
  const _AllTabSections({
    required this.state,
    required this.scrollController,
    required this.onViewAll,
    required this.onProfileTap,
  });

  final SearchState state;
  final ScrollController scrollController;
  final ValueChanged<SearchMode> onViewAll;
  final ValueChanged<Profile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b  = state.bundle;
    final q  = state.query;
    final total = b.totalCount;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Iconsax.search_normal_copy, size: 16, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'Showing results for '),
                      TextSpan(
                        text: '"$q"',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                '~$total',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ),
        if (b.profiles.isNotEmpty) ...[
          _SectionLabel(
            icon: Iconsax.people_copy,
            iconColor: cs.primary,
            label: 'People',
            count: '@',
            trailing: _ViewAllButton(
                onTap: () => onViewAll(SearchMode.profiles)),
          ),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: b.profiles.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _PersonCard(
                profile: b.profiles[i],
                query: q,
                onTap: () => onProfileTap(b.profiles[i]),
              ),
            ),
          ),
        ],
        if (b.hashtags.isNotEmpty) ...[
          _SectionLabel(
            icon: Iconsax.hashtag_copy,
            iconColor: _kPink,
            label: 'Hashtags',
            count: '#',
            trailing: _ViewAllButton(
                onTap: () => onViewAll(SearchMode.hashtags)),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: b.hashtags.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) =>
                  _HashtagChip(hashtag: b.hashtags[i], query: q),
            ),
          ),
        ],
        if (b.games.isNotEmpty) ...[
          _SectionLabel(
            icon: Iconsax.game_copy,
            iconColor: _kGreen,
            label: 'Games',
            count: '/g',
            trailing: _ViewAllButton(
                onTap: () => onViewAll(SearchMode.games)),
          ),
          ...b.games.take(3).map(
                (g) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _GameTile(game: g, query: q),
                ),
              ),
        ],
        if (b.venues.isNotEmpty) ...[
          _SectionLabel(
            icon: Iconsax.buildings_copy,
            iconColor: _kCyan,
            label: 'Venues',
            count: '/v',
            trailing: _ViewAllButton(
                onTap: () => onViewAll(SearchMode.venues)),
          ),
          SizedBox(
            height: 158,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: b.venues.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) =>
                  _VenueCard(venue: b.venues[i], query: q),
            ),
          ),
        ],
        if (b.posts.isNotEmpty) ...[
          _SectionLabel(
            icon: Iconsax.message_copy,
            iconColor: _kOrange,
            label: 'Posts',
            count: '/p',
            trailing:
                _ViewAllButton(onTap: () => onViewAll(SearchMode.posts)),
          ),
          ...b.posts.take(3).map(
                (p) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _PostTile(post: p, query: q),
                ),
              ),
        ],
        if (b.comments.isNotEmpty) ...[
          _SectionLabel(
            icon: Iconsax.messages_2_copy,
            iconColor: _kAmber,
            label: 'Comments',
            count: '/c',
            trailing: _ViewAllButton(
                onTap: () => onViewAll(SearchMode.comments)),
          ),
          ...b.comments.take(3).map(
                (c) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _CommentTile(comment: c, query: q),
                ),
              ),
        ],
        if (b.meetups.isNotEmpty) ...[
          _SectionLabel(
            icon: Iconsax.calendar_copy,
            iconColor: _kOrange,
            label: 'Meet-ups',
            count: '/m',
            trailing: _ViewAllButton(
                onTap: () => onViewAll(SearchMode.meetups)),
          ),
          ...b.meetups.take(3).map(
                (m) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _MeetupTile(meetup: m, query: q),
                ),
              ),
        ],
      ],
    );
  }
}

// =============================================================================
// PEOPLE — horizontal card + full list
// =============================================================================

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.profile,
    required this.query,
    required this.onTap,
  });
  final Profile profile;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        child: Column(
          children: [
            DSAvatar.medium(
              imageUrl: profile.avatarUrl,
              displayName: profile.displayName,
              context: AvatarContext.social,
            ),
            const SizedBox(height: 8),
            _HighlightedText(
              text: profile.displayName,
              query: query,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '@${profile.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  Theme.of(context).textTheme.labelSmall!.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Follow',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({
    required this.profiles,
    required this.query,
    required this.scrollController,
    required this.onTap,
  });
  final List<Profile> profiles;
  final String query;
  final ScrollController scrollController;
  final ValueChanged<Profile> onTap;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) return const _EmptyTab(message: 'No people found');
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 80),
      itemCount: profiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = profiles[i];
        return GestureDetector(
          onTap: () => onTap(p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant, width: 1),
            ),
            child: Row(children: [
              DSAvatar.small(
                imageUrl: p.avatarUrl,
                displayName: p.displayName,
                context: AvatarContext.social,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightedText(
                      text: p.displayName,
                      query: query,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface),
                    ),
                    Text('@${p.username}',
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Follow',
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// =============================================================================
// HASHTAGS — chip + full list
// =============================================================================

class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.hashtag, required this.query});
  final HashtagSearchResult hashtag;
  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.hashtagFeed,
        pathParameters: {'slug': hashtag.slug},
        queryParameters: {'postCount': '${hashtag.postCount}'},
      ),
      child: Container(
        constraints: const BoxConstraints(minWidth: 130, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.surface, _kPink.withValues(alpha: 0.10)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _kPink.withValues(alpha: 0.30), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _HighlightedText(
              text: '#${hashtag.slug}',
              query: query,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w800,
                color: _kPink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${hashtag.postCount} posts',
              style:
                  Theme.of(context).textTheme.labelSmall!.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HashtagsList extends StatelessWidget {
  const _HashtagsList({
    required this.hashtags,
    required this.query,
    required this.scrollController,
  });
  final List<HashtagSearchResult> hashtags;
  final String query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (hashtags.isEmpty) return const _EmptyTab(message: 'No hashtags found');
    final cs = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 80),
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant, width: 1.5),
          ),
          child: Column(
            children: List.generate(hashtags.length, (i) {
              final h = hashtags[i];
              return _TrendingRow(
                rank: i + 1,
                tag: '#${h.slug}',
                posts: '${h.postCount}',
                delta: '',
                accent: _kPink,
                showDivider: i > 0,
                onTap: () => context.pushNamed(
                  RouteNames.hashtagFeed,
                  pathParameters: {'slug': h.slug},
                  queryParameters: {'postCount': '${h.postCount}'},
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// GAMES — tile + full list
// =============================================================================

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, required this.query});
  final GameModel game;
  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = _sportColor(game.sport);
    final spotsText = game.maxPlayers > 0
        ? '${game.currentPlayers}/${game.maxPlayers}'
        : '—';
    final whenText = _formatGameWhen(game.scheduledDate);
    return GestureDetector(
      onTap: () => context.push('${RoutePaths.games}/${game.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: sc.withValues(alpha: 0.30), width: 1.5),
            ),
            child: Icon(Iconsax.game_copy, size: 22, color: sc),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HighlightedText(
                  text: game.title,
                  query: query,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      game.sport,
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: sc,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${game.venueName ?? ''} · $whenText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                spotsText,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: sc),
              ),
              Text('spots',
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: cs.onSurfaceVariant)),
            ],
          ),
        ]),
      ),
    );
  }
}

class _GamesList extends StatelessWidget {
  const _GamesList({
    required this.games,
    required this.query,
    required this.scrollController,
  });
  final List<GameModel> games;
  final String query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const _EmptyTab(message: 'No games found');
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 80),
      itemCount: games.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _GameTile(game: games[i], query: query),
    );
  }
}

String _formatGameWhen(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = day.difference(today).inDays;
  final time = DateFormat('h:mm a').format(dt);
  if (diff == 0) return 'Today · $time';
  if (diff == 1) return 'Tomorrow · $time';
  if (diff > 0 && diff < 7) return '${DateFormat('EEE').format(dt)} · $time';
  return DateFormat('d MMM · h:mm a').format(dt);
}

// =============================================================================
// VENUES — card + full list
// =============================================================================

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.query});
  final Venue venue;
  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 184,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kCyan.withValues(alpha: 0.30),
                  cs.primary.withValues(alpha: 0.20),
                ],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(Iconsax.buildings_copy,
                      size: 36, color: _kCyan.withValues(alpha: 0.7)),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 11, color: _kAmber),
                        const SizedBox(width: 2),
                        Text(
                          '4.6',
                          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HighlightedText(
                  text: venue.name,
                  query: query,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    height: 1.3,
                  ),
                ),
                if (venue.address != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Iconsax.location_copy,
                        size: 10, color: cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        venue.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VenuesList extends StatelessWidget {
  const _VenuesList({
    required this.venues,
    required this.query,
    required this.scrollController,
  });
  final List<Venue> venues;
  final String query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const _EmptyTab(message: 'No venues found');
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: venues.length,
      itemBuilder: (_, i) => _VenueCard(venue: venues[i], query: query),
    );
  }
}

// =============================================================================
// POSTS / COMMENTS / MEETUPS — tiles + full lists
// =============================================================================

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.query});
  final PostSearchResult post;
  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () =>
          context.push('${RoutePaths.socialPostDetail}/${post.id}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.message_copy,
                    size: 16, color: _kOrange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorDisplayName ?? 'Post',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface),
                    ),
                    if (post.createdAt != null)
                      Text(
                        _relativeTime(post.createdAt!),
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Icon(Iconsax.heart_copy,
                  size: 14, color: cs.onSurfaceVariant),
            ]),
            const SizedBox(height: 8),
            _HighlightedText(
              text: post.body,
              query: query,
              maxLines: 3,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostsList extends StatelessWidget {
  const _PostsList({
    required this.posts,
    required this.query,
    required this.scrollController,
  });
  final List<PostSearchResult> posts;
  final String query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const _EmptyTab(message: 'No posts found');
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 80),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _PostTile(post: posts[i], query: query),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.query});
  final CommentSearchResult comment;
  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () =>
          context.push('${RoutePaths.socialPostDetail}/${comment.postId}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
          ),
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 1.5),
            right: BorderSide(color: cs.outlineVariant, width: 1.5),
            bottom: BorderSide(color: cs.outlineVariant, width: 1.5),
            left: const BorderSide(color: _kAmber, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comment.postTitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: cs.onSurfaceVariant),
                    children: [
                      const TextSpan(text: 'on '),
                      TextSpan(
                        text: comment.postTitle!,
                        style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            _HighlightedText(
              text: comment.snippet,
              query: query,
              maxLines: 3,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsList extends StatelessWidget {
  const _CommentsList({
    required this.comments,
    required this.query,
    required this.scrollController,
  });
  final List<CommentSearchResult> comments;
  final String query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const _EmptyTab(message: 'No comments found');
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 80),
      itemCount: comments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) =>
          _CommentTile(comment: comments[i], query: query),
    );
  }
}

class _MeetupTile extends StatelessWidget {
  const _MeetupTile({required this.meetup, required this.query});
  final MeetupSearchResult meetup;
  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kOrange.withValues(alpha: 0.10), cs.surface],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _kOrange.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Iconsax.calendar_copy,
              size: 22, color: _kOrange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HighlightedText(
                text: meetup.title,
                query: query,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface),
              ),
              if (meetup.startAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  _formatGameWhen(meetup.startAt!),
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _kOrange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'RSVP',
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ]),
    );
  }
}

class _MeetupsList extends StatelessWidget {
  const _MeetupsList({
    required this.meetups,
    required this.query,
    required this.scrollController,
  });
  final List<MeetupSearchResult> meetups;
  final String query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (meetups.isEmpty) {
      return const _EmptyTab(message: 'No meetups found');
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 80),
      itemCount: meetups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _MeetupTile(meetup: meetups[i], query: query),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(dt);
}

// =============================================================================
// HIGHLIGHTED TEXT — bolds matched query inside a string
// =============================================================================

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines,
  });
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (query.trim().isEmpty) {
      return Text(text,
          style: style,
          maxLines: maxLines,
          overflow:
              maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip);
    }

    final cleaned = query
        .replaceAll(RegExp(r'^[@#]'), '')
        .replaceAll(RegExp(r'^/[a-z]\s*'), '')
        .trim();

    if (cleaned.isEmpty) {
      return Text(text,
          style: style,
          maxLines: maxLines,
          overflow:
              maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip);
    }

    final lower = text.toLowerCase();
    final needle = cleaned.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      final hit = lower.indexOf(needle, i);
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (hit > i) spans.add(TextSpan(text: text.substring(i, hit)));
      spans.add(TextSpan(
        text: text.substring(hit, hit + needle.length),
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w800,
          backgroundColor: cs.primary.withValues(alpha: 0.15),
        ),
      ));
      i = hit + needle.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow:
          maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      text: TextSpan(style: style, children: spans),
    );
  }
}

// =============================================================================
// VIEW ALL — drilled-in single-section screen with sort sub-tabs
// =============================================================================

class _ViewAllScreen extends StatefulWidget {
  const _ViewAllScreen({
    required this.mode,
    required this.query,
    required this.state,
    required this.onBack,
    required this.onProfileTap,
  });
  final SearchMode mode;
  final String query;
  final SearchState state;
  final VoidCallback onBack;
  final ValueChanged<Profile> onProfileTap;

  @override
  State<_ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<_ViewAllScreen> {
  String _sort = 'top';

  static const _sorts = ['top', 'recent', 'popular'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = _modeInfo(widget.mode);
    final count = _itemCount();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 0),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 1)),
          ),
          child: Column(
            children: [
              Row(children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: Icon(Iconsax.arrow_left_2_copy,
                      size: 22, color: cs.onSurface),
                  splashRadius: 22,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALL ${info.label.toUpperCase()} FOR',
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(info.icon, size: 16, color: info.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '"${widget.query}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surface,
                    border: Border.all(color: cs.outlineVariant, width: 1.5),
                  ),
                  child: Icon(Iconsax.filter_copy,
                      size: 16, color: cs.onSurface),
                ),
              ]),
              const SizedBox(height: 6),
              SizedBox(
                height: 38,
                child: Row(
                  children: _sorts.map((k) {
                    final active = _sort == k;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _sort = k),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: active ? cs.primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Text(
                            k[0].toUpperCase() + k.substring(1),
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active ? cs.primary : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(
            children: [
              RichText(
                text: TextSpan(
                  style:
                      Theme.of(context).textTheme.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                  children: [
                    TextSpan(
                      text: '$count ',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: '${info.label} · sorted by $_sort'),
                  ],
                ),
              ),
              const Spacer(),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department_outlined,
                    size: 12, color: _kPink),
                const SizedBox(width: 4),
                Text(
                  'Trending only',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ]),
            ],
          ),
        ),
        Expanded(child: _buildList(cs)),
      ],
    );
  }

  int _itemCount() {
    final b = widget.state.bundle;
    switch (widget.mode) {
      case SearchMode.profiles: return b.profiles.length;
      case SearchMode.posts:    return b.posts.length;
      case SearchMode.games:    return b.games.length;
      case SearchMode.venues:   return b.venues.length;
      case SearchMode.comments: return b.comments.length;
      case SearchMode.hashtags: return b.hashtags.length;
      case SearchMode.meetups:  return b.meetups.length;
      case SearchMode.all:      return b.totalCount;
    }
  }

  Widget _buildList(ColorScheme cs) {
    final b = widget.state.bundle;
    final q = widget.query;
    switch (widget.mode) {
      case SearchMode.hashtags:
        if (b.hashtags.isEmpty) {
          return const _EmptyTab(message: 'No hashtags found');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          children: [
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant, width: 1.5),
              ),
              child: Column(
                children: List.generate(b.hashtags.length, (i) {
                  final h = b.hashtags[i];
                  return _TrendingRow(
                    rank: i + 1,
                    tag: '#${h.slug}',
                    posts: '${h.postCount}',
                    delta: '',
                    accent: _kPink,
                    showDivider: i > 0,
                    onTap: () => context.pushNamed(
                      RouteNames.hashtagFeed,
                      pathParameters: {'slug': h.slug},
                      queryParameters: {'postCount': '${h.postCount}'},
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),
            const _LoadMoreButton(),
          ],
        );

      case SearchMode.profiles:
        if (b.profiles.isEmpty) {
          return const _EmptyTab(message: 'No people found');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          itemCount: b.profiles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final p = b.profiles[i];
            return GestureDetector(
              onTap: () => widget.onProfileTap(p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant, width: 1.5),
                ),
                child: Row(children: [
                  DSAvatar.small(
                    imageUrl: p.avatarUrl,
                    displayName: p.displayName,
                    context: AvatarContext.social,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedText(
                          text: p.displayName,
                          query: q,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '@${p.username}',
                          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                              color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Follow',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ]),
              ),
            );
          },
        );

      case SearchMode.games:
        if (b.games.isEmpty) {
          return const _EmptyTab(message: 'No games found');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          itemCount: b.games.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) =>
              _GameTile(game: b.games[i], query: q),
        );

      case SearchMode.venues:
        if (b.venues.isEmpty) {
          return const _EmptyTab(message: 'No venues found');
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: b.venues.length,
          itemBuilder: (_, i) =>
              _VenueCard(venue: b.venues[i], query: q),
        );

      case SearchMode.posts:
        if (b.posts.isEmpty) {
          return const _EmptyTab(message: 'No posts found');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          itemCount: b.posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) =>
              _PostTile(post: b.posts[i], query: q),
        );

      case SearchMode.comments:
        if (b.comments.isEmpty) {
          return const _EmptyTab(message: 'No comments found');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          itemCount: b.comments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) =>
              _CommentTile(comment: b.comments[i], query: q),
        );

      case SearchMode.meetups:
        if (b.meetups.isEmpty) {
          return const _EmptyTab(message: 'No meetups found');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          itemCount: b.meetups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) =>
              _MeetupTile(meetup: b.meetups[i], query: q),
        );

      case SearchMode.all:
        return const SizedBox.shrink();
    }
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Text(
        'Load more',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.primary,
        ),
      ),
    );
  }
}

class _ModeInfo {
  final String label;
  final IconData icon;
  final Color accent;
  const _ModeInfo(this.label, this.icon, this.accent);
}

_ModeInfo _modeInfo(SearchMode mode) {
  switch (mode) {
    case SearchMode.profiles:
      return const _ModeInfo('people', Iconsax.people_copy, Color(0xFF7328CE));
    case SearchMode.hashtags:
      return const _ModeInfo('hashtags', Iconsax.hashtag_copy, _kPink);
    case SearchMode.games:
      return const _ModeInfo('games', Iconsax.game_copy, _kGreen);
    case SearchMode.venues:
      return const _ModeInfo('venues', Iconsax.buildings_copy, _kCyan);
    case SearchMode.posts:
      return const _ModeInfo('posts', Iconsax.message_copy, _kOrange);
    case SearchMode.comments:
      return const _ModeInfo('comments', Iconsax.messages_2_copy, _kAmber);
    case SearchMode.meetups:
      return const _ModeInfo('meet-ups', Iconsax.calendar_copy, _kOrange);
    case SearchMode.all:
      return const _ModeInfo(
          'results', Iconsax.search_normal_copy, Color(0xFF7328CE));
  }
}
