import 'package:dabbler/core/fp/failure.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/fp/result.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/circle_contact.dart';
import '../../data/repositories/circle_repository.dart';
import '../../data/repositories/circle_repository_impl.dart';

typedef ViewArgs = ({int? limit, int? offset});
typedef FeedArgs = ({int limit, int offset});
typedef SquadCardsArgs = ({String? squadId, int? limit, int? offset});

final circleRepositoryProvider = Provider.autoDispose<CircleRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return CircleRepositoryImpl(svc);
});

/// Typed list from RPC (friend_profile_id, friend_user_id)
final circleListProvider =
    FutureProvider.autoDispose<Result<List<CircleContact>, Failure>>((ref) {
      final repo = ref.watch(circleRepositoryProvider);
      return repo.circleList();
    });

/// Raw circle view rows (unknown shape → Map)
final circleViewProvider = FutureProvider.autoDispose
    .family<Result<List<Map<String, dynamic>>, Failure>, ViewArgs>((ref, args) {
      final repo = ref.watch(circleRepositoryProvider);
      return repo.circleView(limit: args.limit, offset: args.offset);
    });

/// Feed (one-shot)
final circleFeedProvider = FutureProvider.autoDispose
    .family<Result<List<Map<String, dynamic>>, Failure>, FeedArgs>((ref, args) {
      final repo = ref.watch(circleRepositoryProvider);
      return repo.circleFeed(limit: args.limit, offset: args.offset);
    });

/// Feed (reactive via friend_edges change)
final circleFeedStreamProvider = StreamProvider.autoDispose
    .family<Result<List<Map<String, dynamic>>, Failure>, FeedArgs>((ref, args) {
      final repo = ref.watch(circleRepositoryProvider);
      return repo.circleFeedStream(limit: args.limit, offset: args.offset);
    });

final friendInboxProvider =
    FutureProvider.autoDispose<Result<List<Map<String, dynamic>>, Failure>>((
      ref,
    ) {
      final repo = ref.watch(circleRepositoryProvider);
      return repo.friendRequestsInbox();
    });

final friendOutboxProvider =
    FutureProvider.autoDispose<Result<List<Map<String, dynamic>>, Failure>>((
      ref,
    ) {
      final repo = ref.watch(circleRepositoryProvider);
      return repo.friendRequestsOutbox();
    });

final squadCardsProvider = FutureProvider.autoDispose
    .family<Result<List<Map<String, dynamic>>, Failure>, SquadCardsArgs>((
      ref,
      args,
    ) {
      final repo = ref.watch(circleRepositoryProvider);
      return repo.squadCards(
        squadId: args.squadId,
        limit: args.limit,
        offset: args.offset,
      );
    });

final squadDetailProvider = FutureProvider.autoDispose
    .family<Result<List<Map<String, dynamic>>, Failure>, String>((
      ref,
      squadId,
    ) {
      final repo = ref.watch(circleRepositoryProvider);
      return repo.squadDetail(squadId);
    });
