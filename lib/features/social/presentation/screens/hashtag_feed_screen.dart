import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/presentation/widgets/feed_post_card.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// Shows posts that contain a specific hashtag.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalLabel = widget.initialPostCount != null
        ? '${widget.initialPostCount} posts'
        : '${_posts.length} posts';

    return Scaffold(
      appBar: AppBar(
        title: Text('#${widget.hashtagSlug}'),
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(theme, totalLabel),
    );
  }

  Widget _buildBody(ThemeData theme, String totalLabel) {
    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadInitial,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.tag, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    'No posts found for #${widget.hashtagSlug}',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _posts.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader(theme, totalLabel);
          }

          if (index == _posts.length + 1) {
            if (!_isLoadingMore) return const SizedBox(height: 24);
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = _posts[index - 1];
          return FeedPostCard(post: post);
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, String totalLabel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.tertiaryContainer,
              child: Icon(Icons.tag, color: theme.colorScheme.onTertiaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${widget.hashtagSlug}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    totalLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
