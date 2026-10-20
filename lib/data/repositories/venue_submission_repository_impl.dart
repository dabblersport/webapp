import 'package:meta/meta.dart';
import 'package:dabbler/core/config/supabase_config.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import 'package:dabbler/data/models/venue_submission_model.dart';

import 'base_repository.dart';
import 'venue_submission_repository.dart';

@immutable
class VenueSubmissionRepositoryImpl extends BaseRepository
    implements VenueSubmissionRepository {
  const VenueSubmissionRepositoryImpl(super.svc);

  @override
  Future<Result<VenueSubmissionModel, Failure>> upsertDraft({
    required String organiserProfileId,
    required VenueSubmissionDraft draft,
  }) async {
    final uid = svc.authUserId();
    if (uid == null || uid.isEmpty) {
      return Err(const UnauthenticatedFailure());
    }

    return guard<VenueSubmissionModel>(() async {
      if (draft.id == null || draft.id!.isEmpty) {
        final insert = <String, dynamic>{
          'organiser_profile_id': organiserProfileId,
          'submitted_by_user_id': uid,
          'status': VenueSubmissionStatus.draft.name,
          ...draft.toColumnsMap(includeNulls: false),
        };

        final row = await svc
            .from(SupabaseConfig.venueSubmissionsTable)
            .insert(insert)
            .select()
            .single();

        return VenueSubmissionModel.fromMap(asMap(row));
      }

      final update = <String, dynamic>{
        ...draft.toColumnsMap(includeNulls: true),
      };

      final row = await svc
          .from(SupabaseConfig.venueSubmissionsTable)
          .update(update)
          .eq('id', draft.id!)
          .select()
          .single();

      return VenueSubmissionModel.fromMap(asMap(row));
    });
  }

  @override
  Future<Result<VenueSubmissionModel, Failure>> submitForReview({
    required String submissionId,
  }) async {
    final uid = svc.authUserId();
    if (uid == null || uid.isEmpty) {
      return Err(const UnauthenticatedFailure());
    }

    return guard<VenueSubmissionModel>(() async {
      final row = await svc
          .from(SupabaseConfig.venueSubmissionsTable)
          .update({'status': VenueSubmissionStatus.pending.name})
          .eq('id', submissionId)
          .select()
          .single();

      return VenueSubmissionModel.fromMap(asMap(row));
    });
  }

  @override
  Future<Result<List<VenueSubmissionModel>, Failure>> listMine({
    required String organiserProfileId,
    int limit = 200,
  }) async {
    final uid = svc.authUserId();
    if (uid == null || uid.isEmpty) {
      return Err(const UnauthenticatedFailure());
    }

    return guard<List<VenueSubmissionModel>>(() async {
      final rows = await svc
          .from(SupabaseConfig.venueSubmissionsTable)
          .select()
          .eq('organiser_profile_id', organiserProfileId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((r) => VenueSubmissionModel.fromMap(asMap(r)))
          .toList(growable: false);
    });
  }

  @override
  Future<Result<VenueSubmissionModel, Failure>> getById(String id) async {
    final uid = svc.authUserId();
    if (uid == null || uid.isEmpty) {
      return Err(const UnauthenticatedFailure());
    }

    return guard<VenueSubmissionModel>(() async {
      final row = await svc.from(SupabaseConfig.venueSubmissionsTable).select().eq('id', id).single();
      return VenueSubmissionModel.fromMap(asMap(row));
    });
  }
}
