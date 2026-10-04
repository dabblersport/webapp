import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/core/feed/post_layout_resolver.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// Shows posts that contain a specific hashtag (design X04, "Hashtag result").
class HashtagFeedScreen extends ConsumerStatefulWidget {
  const HashtagFeedScreen({
    super.key,
    required this.hashtagSlug,
    this.initialPostCount,
  });

  final String hashtagSlug;
  final int? initialPostCount;

  @override
  ConsumerState<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends ConsumerState<HashtagFeedScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();

  final List<Post> _posts = <Post>[];
  int _page = 0;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _error = null;
      _page = 0;
      _hasMore = true;
      _posts.clear();
    });

    await _loadPage(page: 0, append: false);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isInitialLoading) return;
    await _loadPage(page: _page + 1, append: true);
  }

  Future<void> _loadPage({required int page, required bool append}) async {
    if (append) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    final repo = ref.read(postRepositoryProvider);
    final offset = page * _pageSize;
    final result = await repo.getHashtagFeed(
      hashtag: widget.hashtagSlug,
      limit: _pageSize,
      offset: offset,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      },
      (newPosts) {
        setState(() {
          if (append) {
            final existingIds = _posts.map((p) => p.id).toSet();
            _posts.addAll(
              newPosts.where((post) => !existingIds.contains(post.id)),
            );
            _page = page;
          } else {
            _posts
              ..clear()
              ..addAll(newPosts);
            _page = 0;
          }

          _hasMore = newPosts.length >= _pageSize;
          _error = null;
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      },
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 280;
    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  /// The tag, isolated as left-to-right so `#` stays in front of it in RTL.
  String get _tag => '\u2066#${widget.hashtagSlug}\u2069';

  @override
  Widget build(BuildContext context) {
    final totalLabel = widget.initialPostCount != null
        ? '${widget.initialPostCount} posts'
        : '${_posts.length} posts';

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: _tag,
        border: true,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: _isInitialLoading
          ? const _HashtagSkeleton()
          : _buildBody(totalLabel),
    );
  }

  Widget _buildBody(String totalLabel) {
    if (_error != null && _posts.isEmpty) {
      return DabblerEmptyState.error(
        title: _error!,
        onRetry: _loadInitial,
        retryLabel: 'Retry',
      );
    }

    if (_posts.isEmpty) {
      return DabblerRefresh(
        onRefresh: _loadInitial,
        child: ListView(
          padding: const EdgeInsets.all(DabblerSpacing.space6),
          children: [
            DabblerEmptyState(
              icon: 'hashtag',
              title: 'No posts found for #${widget.hashtagSlug}',
            ),
          ],
        ),
      );
    }

    return DabblerRefresh(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _posts.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader(totalLabel);

          if (index == _posts.length + 1) {
            if (!_isLoadingMore) {
              return const SizedBox(height: DabblerSpacing.space8);
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: DabblerSpacing.space5),
              child: Center(child: DabblerSpinner(size: DabblerSpinnerSize.sm)),
            );
          }

          return resolvePostLayout(_posts[index - 1]);
        },
      ),
    );
  }

  Widget _buildHeader(String totalLabel) {
    final count = widget.initialPostCount ?? _posts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space6,
            vertical: DabblerSpacing.space5,
          ),
          child: Row(
            spacing: DabblerSpacing.space4,
            children: [
              const DabblerIconTile.named(
                'hashtag',
                weight: DabblerIconWeight.bold,
              ),
              Expanded(
                child: Semantics(
                  label: totalLabel,
                  child: DabblerText.rich([
                    DabblerTextSpan(
                      '$count',
                      weight: DabblerTextWeight.semibold,
                    ),
                    const DabblerTextSpan(' posts'),
                  ], style: DabblerType.headline),
                ),
              ),
            ],
          ),
        ),
        const DabblerDivider(),
      ],
    );
  }
}

/// The first-load placeholder: three post-shaped skeleton rows.
class _HashtagSkeleton extends StatelessWidget {
  const _HashtagSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(DabblerSpacing.space6),
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: DabblerSpacing.space6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DabblerSkeleton.circle(),
                SizedBox(width: DabblerSpacing.space4),
                Expanded(child: DabblerSkeleton.text(lines: 3)),
              ],
            ),
          ),
      ],
    );
  }
}
