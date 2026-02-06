import 'package:meta/meta.dart';
import 'package:dabbler/core/fp/failure.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/benefit.dart';
import 'base_repository.dart';
import 'organiser_benefits_repository.dart';

@immutable
class OrganiserBenefitsRepositoryImpl extends BaseRepository
    implements OrganiserBenefitsRepository {
  static const _table = 'organiser_benefits';

  const OrganiserBenefitsRepositoryImpl(super.svc);

  @override
  Future<Result<List<Benefit>, Failure>> listMine({
    bool onlyActive = true,
    int limit = 50,
    int offset = 0,
  }) {
    final uid = svc.authUserId();
    if (uid == null) {
      return Future.value(Err(const AuthFailure(message: 'Not signed in')));
    }

    return guard<List<Benefit>>(() async {
      dynamic q = svc.client.from(_table).select().eq('owner_user_id', uid);

      if (onlyActive) {
        q = q.eq('is_active', true);
      }

      q = q
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final rows = await q;
      return rows.map((m) => Benefit.fromMap(asMap(m))).toList();
    });
  }

  @override
  Future<Result<List<Benefit>, Failure>> listForVenue(
    String venueId, {
    bool onlyActive = true,
    int limit = 50,
    int offset = 0,
  }) {
    return guard<List<Benefit>>(() async {
      dynamic q = svc.client.from(_table).select().eq('venue_id', venueId);

      if (onlyActive) {
        q = q.eq('is_active', true);
      }

      q = q
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final rows = await q;
      return rows.map((m) => Benefit.fromMap(asMap(m))).toList();
    });
  }

  @override
  Future<Result<Benefit?, Failure>> getById(String id) {
    return guard<Benefit?>(() async {
      final row = await svc.client
          .from(_table)
          .select()
          .eq('id', id)
          .maybeSingle();

      return row == null ? null : Benefit.fromMap(asMap(row));
    });
  }

  @override
  Future<Result<Benefit, Failure>> create({
    required String title,
    String? description,
    String? venueId,
    bool isActive = true,
    DateTime? startsAt,
    DateTime? endsAt,
    String? imageUrl,
  }) {
    return guard<Benefit>(() async {
      final payload = Benefit(
        id: null,
        ownerUserId: null, // set by server defaults/RLS or triggers
        venueId: venueId,
        title: title,
        description: description,
        isActive: isActive,
        startsAt: startsAt,
        endsAt: endsAt,
        imageUrl: imageUrl,
        createdAt: null,
        updatedAt: null,
      ).toInsertMap();

      final row = await svc.client
          .from(_table)
          .insert(payload)
          .select()
          .single();

      return Benefit.fromMap(asMap(row));
    });
  }

  @override
  Future<Result<void, Failure>> update(
    String id, {
    String? title,
    String? description,
    String? venueId,
    bool? isActive,
    DateTime? startsAt,
    DateTime? endsAt,
    String? imageUrl,
  }) {
    return guard<void>(() async {
      final patch = Benefit(
        id: id,
        ownerUserId: null,
        venueId: venueId,
        title: title ?? '',
        description: description,
        isActive: isActive ?? true,
        startsAt: startsAt,
        endsAt: endsAt,
        imageUrl: imageUrl,
        createdAt: null,
        updatedAt: null,
      ).toPatchMap();

      if (patch.isEmpty) return;

      await svc.client.from(_table).update(patch).eq('id', id);
    });
  }

  @override
  Future<Result<void, Failure>> delete(String id) {
    return guard<void>(() async {
      await svc.client.from(_table).delete().eq('id', id);
    });
  }
}
