import 'package:dabbler/data/models/news/news_comment.dart';
import 'package:dabbler/features/news/data/news_repository.dart';
import 'package:dabbler/features/news/providers/news_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewsCommentsNotifier
    extends StateNotifier<AsyncValue<List<NewsComment>>> {
  NewsCommentsNotifier(this._repo, this._newsId)
      : super(const AsyncLoading()) {
    load();
  }

  final NewsRepository _repo;
  final String _newsId;

  Future<void> load() async {
    state = const AsyncLoading();
    final result = await _repo.fetchComments(_newsId, limit: 50);
    state = result.fold(
      (err) => AsyncError(err.message, StackTrace.current),
      (items) => AsyncData(items),
    );
  }

  void append(NewsComment comment) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, comment]);
  }
}

final newsCommentsProvider = StateNotifierProvider.family<
    NewsCommentsNotifier, AsyncValue<List<NewsComment>>, String>((ref, newsId) {
  final repo = ref.watch(newsRepositoryProvider);
  return NewsCommentsNotifier(repo, newsId);
});
