import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/news/news_comment.dart';

abstract class NewsRepository {
  Future<Result<List<FeedNewsItem>, Failure>> fetchNewsTab({
    int limit = 20,
    int offset = 0,
  });

  Future<Result<List<NewsComment>, Failure>> fetchComments(
    String newsId, {
    int limit = 50,
    int offset = 0,
  });

  Future<Result<NewsComment, Failure>> addComment(
    String newsId,
    String body,
    Map<String, String> newsTitleSnapshot,
  );
}
