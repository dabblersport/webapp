import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/games/game.dart' as domain;
import 'base_repository.dart';
import 'games_repository.dart';

class GamesRepositoryImpl extends BaseRepository implements GamesRepository {
  GamesRepositoryImpl(super.service);

  static const String table = 'games';

  @override
  Future<Result<domain.Game, Failure>> createGame({
    required String gameType,
    required String sport,
    String? title,
    required String hostProfileId,
    String? venueSpaceId,
    required DateTime startAt,
    required DateTime endAt,
    required int capacity,
    required String listingVisibility,
    required String joinPolicy,
    bool allowSpectators = false,
    int? minSkill,
    int? maxSkill,
    Map<String, dynamic> rules = const {},
    String? squadId,
  }) async {
    final uid = svc.authUserId();
    if (uid == null) {
      return Err(const AuthFailure(message: 'Not signed in'));
    }

    if (capacity < 2 || capacity > 64) {
      return Err(
        const ValidationFailure(message: 'Capacity must be between 2 and 64'),
      );
    }
    if (minSkill != null && (minSkill < 1 || minSkill > 10)) {
      return Err(
        const ValidationFailure(
          message: 'Minimum skill must be between 1 and 10',
        ),
      );
    }
    if (maxSkill != null && (maxSkill < 1 || maxSkill > 10)) {
      return Err(
        const ValidationFailure(
          message: 'Maximum skill must be between 1 and 10',
        ),
      );
    }
    if (minSkill != null && maxSkill != null && minSkill > maxSkill) {
      return Err(
        const ValidationFailure(
          message: 'Minimum skill cannot exceed maximum skill',
        ),
      );
    }

    final payload = <String, dynamic>{
      'game_type': gameType,
      'sport': sport,
      if (title != null) 'title': title,
      'host_profile_id': hostProfileId,
      'host_user_id': uid,
      if (venueSpaceId != null) 'venue_space_id': venueSpaceId,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'capacity': capacity,
      'listing_visibility': listingVisibility,
      'join_policy': joinPolicy,
      'allow_spectators': allowSpectators,
      if (minSkill != null) 'min_skill': minSkill,
      if (maxSkill != null) 'max_skill': maxSkill,
      'rules': Map<String, dynamic>.from(rules),
      'is_cancelled': false,
      if (squadId != null) 'squad_id': squadId,
    };

    try {
      final response = await svc
          .from(table)
          .insert(payload)
          .select()
          .maybeSingle();

      if (response == null) {
        return Err(const UnexpectedFailure(message: 'Failed to create game'));
      }

      return Ok(GameModel.fromJson(response));
    } catch (error, stackTrace) {
      return Err(svc.mapGeneric(error, stackTrace));
    }
  }

  @override
  Future<Result<void, Failure>> updateGame(
    String gameId, {
    String? title,
    String? venueSpaceId,
    DateTime? startAt,
    DateTime? endAt,
    int? capacity,
    String? listingVisibility,
    String? joinPolicy,
    bool? allowSpectators,
    int? minSkill,
    int? maxSkill,
    Map<String, dynamic>? rules,
  }) async {
    final uid = svc.authUserId();
    if (uid == null) {
      return Err(const AuthFailure(message: 'Not signed in'));
    }

    if (capacity != null && (capacity < 2 || capacity > 64)) {
      return Err(
        const ValidationFailure(message: 'Capacity must be between 2 and 64'),
      );
    }
    if (minSkill != null && (minSkill < 1 || minSkill > 10)) {
      return Err(
        const ValidationFailure(
          message: 'Minimum skill must be between 1 and 10',
        ),
      );
    }
    if (maxSkill != null && (maxSkill < 1 || maxSkill > 10)) {
      return Err(
        const ValidationFailure(
          message: 'Maximum skill must be between 1 and 10',
        ),
      );
    }
    if (minSkill != null && maxSkill != null && minSkill > maxSkill) {
      return Err(
        const ValidationFailure(
          message: 'Minimum skill cannot exceed maximum skill',
        ),
      );
    }

    final patch = <String, dynamic>{};
    if (title != null) {
      patch['title'] = title;
    }
    if (venueSpaceId != null) {
      patch['venue_space_id'] = venueSpaceId;
    }
    if (startAt != null) {
      patch['start_at'] = startAt.toIso8601String();
    }
    if (endAt != null) {
      patch['end_at'] = endAt.toIso8601String();
    }
    if (capacity != null) {
      patch['capacity'] = capacity;
    }
    if (listingVisibility != null) {
      patch['listing_visibility'] = listingVisibility;
    }
    if (joinPolicy != null) {
      patch['join_policy'] = joinPolicy;
    }
    if (allowSpectators != null) {
      patch['allow_spectators'] = allowSpectators;
    }
    if (minSkill != null) {
      patch['min_skill'] = minSkill;
    }
    if (maxSkill != null) {
      patch['max_skill'] = maxSkill;
    }
    if (rules != null) {
      patch['rules'] = Map<String, dynamic>.from(rules);
    }

    if (patch.isEmpty) {
      return Ok(null);
    }

    try {
      await svc
          .from(table)
          .update(patch)
          .eq('id', gameId)
          .eq('host_user_id', uid);

      return Ok(null);
    } catch (error, stackTrace) {
      return Err(svc.mapGeneric(error, stackTrace));
    }
  }

  @override
  Future<Result<void, Failure>> cancelGame(
    String gameId, {
    String? reason,
  }) async {
    final uid = svc.authUserId();
    if (uid == null) {
      return Err(const AuthFailure(message: 'Not signed in'));
    }

    final payload = <String, dynamic>{
      'is_cancelled': true,
      'cancelled_at': DateTime.now().toIso8601String(),
      'cancelled_reason': reason,
    };

    try {
      await svc
          .from(table)
          .update(payload)
          .eq('id', gameId)
          .eq('host_user_id', uid);

      return Ok(null);
    } catch (error, stackTrace) {
      return Err(svc.mapGeneric(error, stackTrace));
    }
  }

  @override
  Future<Result<domain.Game, Failure>> getGameById(String gameId) async {
    try {
      final response = await svc
          .from(table)
          .select()
          .eq('id', gameId)
          .maybeSingle();

      if (response == null) {
        return Err(const NotFoundFailure(message: 'Game not found'));
      }

      return Ok(GameModel.fromJson(response));
    } catch (error, stackTrace) {
      return Err(svc.mapGeneric(error, stackTrace));
    }
  }

  @override
  Future<Result<List<domain.Game>, Failure>> listDiscoverableGames({
    String? sport,
    DateTime? from,
    DateTime? to,
    String? visibility,
    bool includeCancelled = false,
    String? q,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      dynamic query = svc.from(table).select();

      if (sport != null) {
        query = query.eq('sport', sport);
      }
      if (from != null) {
        query = query.gte('start_at', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('start_at', to.toIso8601String());
      }
      if (visibility != null) {
        query = query.eq('listing_visibility', visibility);
      }
      if (!includeCancelled) {
        query = query.eq('is_cancelled', false);
      }
      if (q != null && q.isNotEmpty) {
        query = query.ilike('title', '%$q%');
      }

      final rows = await svc.getList(
        query
            .order('start_at', ascending: true)
            .range(offset, offset + limit - 1),
      );

      final games = rows
          .map((row) => GameModel.fromJson(row) as domain.Game)
          .toList();
      return Ok(games);
    } catch (error, stackTrace) {
      return Err(svc.mapGeneric(error, stackTrace));
    }
  }

  @override
  Future<Result<List<domain.Game>, Failure>> listMyHostedGames({
    DateTime? from,
    DateTime? to,
    bool includeCancelled = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final uid = svc.authUserId();
    if (uid == null) {
      return Err(const AuthFailure(message: 'Not signed in'));
    }

    try {
      dynamic query = svc.from(table).select().eq('host_user_id', uid);

      if (from != null) {
        query = query.gte('start_at', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('end_at', to.toIso8601String());
      }
      if (!includeCancelled) {
        query = query.eq('is_cancelled', false);
      }

      final rows = await svc.getList(
        query
            .order('start_at', ascending: false)
            .range(offset, offset + limit - 1),
      );

      final games = rows
          .map((row) => GameModel.fromJson(row) as domain.Game)
          .toList();
      return Ok(games);
    } catch (error, stackTrace) {
      return Err(svc.mapGeneric(error, stackTrace));
    }
  }

  @override
  Stream<Result<domain.Game, Failure>> watchGame(String gameId) {
    final controller =
        StreamController<Result<domain.Game, Failure>>.broadcast();
    RealtimeChannel? channel;

    Future<void> emitCurrent() async {
      final result = await getGameById(gameId);
      controller.add(result);
    }

    void emitError(Object error, [StackTrace? stackTrace]) {
      controller.add(
        Err(svc.mapGeneric(error, stackTrace ?? StackTrace.current)),
      );
    }

    controller.onListen = () {
      try {
        channel = svc.client
            .channel('public:games')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: gameId,
              ),
              callback: (payload) async {
                try {
                  await emitCurrent();
                } catch (error, stackTrace) {
                  emitError(error, stackTrace);
                }
              },
            )
            .subscribe();

        unawaited(emitCurrent());
      } catch (error, stackTrace) {
        emitError(error, stackTrace);
      }
    };

    controller.onCancel = () async {
      if (channel != null) {
        await channel!.unsubscribe();
      }
    };

    return controller.stream;
  }
}
