import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/news/news_comment.dart';
import 'package:dabbler/features/news/data/news_repository.dart';
import 'package:dabbler/features/news/providers/news_comments_provider.dart';
import 'package:dabbler/features/news/providers/news_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewsActionsNotifier extends StateNotifier<AsyncValue<void>> {
  NewsActionsNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  NewsRepository get _repo => _ref.read(newsRepositoryProvider);

  Future<Result<NewsComment, dynamic>> addComment(
    String newsId,
    String body,
    Map<String, String> titleSnapshot,
  ) async {
    final result = await _repo.addComment(newsId, body, titleSnapshot);
    result.fold(
      (err) => debugPrint('[NewsActions] addComment FAILED: ${err.message}'),
      (_) => _ref.invalidate(newsCommentsProvider(newsId)),
    );
    return result;
  }
}

final newsActionsProvider =
    StateNotifierProvider<NewsActionsNotifier, AsyncValue<void>>((ref) {
  return NewsActionsNotifier(ref);
});
