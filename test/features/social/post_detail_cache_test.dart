import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/news_item_codec.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements PostRepository {
  _Repo(this.post);
  Post? post;

  @override
  Future<Result<Post, Failure>> getPost(String postId) async =>
      post == null ? Err(const Failure(message: 'no internet')) : Ok(post!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// KAN-605: a post or news story the viewer opened opens again offline.
void main() {
  test('a post opened online opens again offline, intact', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = OfflineCache(prefs: await SharedPreferences.getInstance());
    final post = Post(
      id: 'p1',
      authorProfileId: 'prof-a',
      authorUserId: 'user-a',
      authorDisplayName: 'Sam',
      kind: PostKind.original,
      visibility: PostVisibility.public,
      body: 'Football night on Sunday',
      sport: 'Football',
      tags: const ['dabblersport'],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final repo = _Repo(post);
    ProviderContainer open(String account) => ProviderContainer(
      overrides: [
        offlineCacheProvider.overrideWithValue(cache),
        cacheAccountIdProvider.overrideWith(
          (ref) => CacheAccountNotifier.fixed(account),
        ),
        postRepositoryProvider.overrideWithValue(repo),
      ],
    );

    final online = open('A');
    addTearDown(online.dispose);
    expect(
      (await online.read(postDetailProvider('p1').future)).body,
      post.body,
    );

    repo.post = null; // the connection is gone
    final offline = open('A');
    addTearDown(offline.dispose);
    final back = await offline.read(postDetailProvider('p1').future);
    expect(back.body, 'Football night on Sunday');
    expect(back.tags, ['dabblersport']);

    // Another account never reads it.
    final other = open('B');
    addTearDown(other.dispose);
    await expectLater(
      other.read(postDetailProvider('p1').future),
      throwsA(isA<Exception>()),
    );
  });

  test('a cached news story keeps its full body for the detail screen', () {
    final news = FeedNewsItem(
      newsId: 'n1',
      id: 'n1',
      title: const {'en': 'Title', 'ar': 'عنوان'},
      body: const {'en': 'Long body', 'ar': 'نص طويل'},
      likeCount: 1,
      commentCount: 2,
      viewCount: 3,
      tags: const ['t'],
      isPinned: false,
      priorityScore: 0,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final back = FeedNewsItem.fromJson(news.toCacheJson());
    expect(back.localizedBody('ar'), 'نص طويل');
    expect(back.localizedTitle('en'), 'Title');
    expect(back.commentCount, 2);
  });
}
