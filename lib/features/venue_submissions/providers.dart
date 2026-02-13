import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart' as core;
import 'package:dabbler/core/fp/result.dart' show Err, Ok;
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/data/repositories/venue_submission_repository.dart';
import 'package:dabbler/data/repositories/venue_submission_repository_impl.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show myProfileProvider;
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

import 'domain/usecases/create_venue_submission_usecase.dart';
import 'domain/usecases/get_my_venue_submissions_usecase.dart';
import 'domain/usecases/get_venue_submission_by_id_usecase.dart';
import 'domain/usecases/submit_venue_for_review_usecase.dart';
import 'presentation/controllers/venue_submission_controller.dart';

typedef Result<T> = core.Result<T, Failure>;

final venueSubmissionRepositoryProvider = Provider<VenueSubmissionRepository>((
  ref,
) {
  final svc = ref.watch(supabaseServiceProvider);
  return VenueSubmissionRepositoryImpl(svc);
});

final createVenueSubmissionUseCaseProvider =
    Provider<CreateVenueSubmissionUseCase>(
      (ref) => CreateVenueSubmissionUseCase(
        ref.watch(venueSubmissionRepositoryProvider),
      ),
    );

final submitVenueForReviewUseCaseProvider =
    Provider<SubmitVenueForReviewUseCase>(
      (ref) => SubmitVenueForReviewUseCase(
        ref.watch(venueSubmissionRepositoryProvider),
      ),
    );

final getMyVenueSubmissionsUseCaseProvider =
    Provider<GetMyVenueSubmissionsUseCase>(
      (ref) => GetMyVenueSubmissionsUseCase(
        ref.watch(venueSubmissionRepositoryProvider),
      ),
    );

final getVenueSubmissionByIdUseCaseProvider =
    Provider<GetVenueSubmissionByIdUseCase>(
      (ref) => GetVenueSubmissionByIdUseCase(
        ref.watch(venueSubmissionRepositoryProvider),
      ),
    );

/// Resolves the current user's organiser profile id (`organiser.id`).
///
/// Note: `venue_submissions.organiser_profile_id` is a FK to `organiser`.
final organiserProfileIdProvider = FutureProvider<Result<String>>((ref) async {
  final profileResult = await ref.watch(myProfileProvider.future);

  if (profileResult is Err<Profile, Failure>) {
    return Err(profileResult.error);
  }

  final profile = (profileResult as Ok<Profile, Failure>).value;

  if (profile.profileType.toLowerCase() != 'organiser') {
    return Err(
      const ForbiddenFailure(
        message: 'Only organiser accounts can submit venues.',
      ),
    );
  }

  final svc = ref.watch(supabaseServiceProvider);

  try {
    final preferredSport = profile.preferredSport?.toLowerCase().trim();

    Map<String, dynamic>? row;

    // Prefer matching the organiser row for the preferred sport.
    if (preferredSport != null && preferredSport.isNotEmpty) {
      row = await svc
          .from('organiser')
          .select('id')
          .eq('profile_id', profile.id)
          .eq('sport', preferredSport)
          .eq('is_active', true)
          .maybeSingle();
    }

    // Fallback to the first active organiser record for this profile.
    row ??= await svc
        .from('organiser')
        .select('id')
        .eq('profile_id', profile.id)
        .eq('is_active', true)
        .maybeSingle();

    // Final fallback: any organiser row for this profile.
    row ??= await svc
        .from('organiser')
        .select('id')
        .eq('profile_id', profile.id)
        .maybeSingle();

    if (row == null || row['id'] == null) {
      return Err(
        const ValidationFailure(
          message:
              'No organiser profile found. Please complete organiser setup before submitting venues.',
        ),
      );
    }

    return Ok(row['id'] as String);
  } catch (e, st) {
    return Err(
      svc.mapPostgrestError(
        e,
        stackTrace: st,
        overrideMessage: 'Failed to resolve organiser profile.',
      ),
    );
  }
});

final myVenueSubmissionsProvider =
    FutureProvider.autoDispose<Result<List<VenueSubmissionModel>>>((ref) async {
      final organiserIdResult = await ref.watch(
        organiserProfileIdProvider.future,
      );

      return organiserIdResult.match(
        (failure) => Err(failure),
        (organiserProfileId) => ref
            .watch(getMyVenueSubmissionsUseCaseProvider)
            .call(organiserProfileId: organiserProfileId),
      );
    });

final venueSubmissionByIdProvider = FutureProvider.family
    .autoDispose<Result<VenueSubmissionModel>, String>((ref, id) async {
      return ref.watch(getVenueSubmissionByIdUseCaseProvider).call(id);
    });

final venueSubmissionControllerProvider =
    StateNotifierProvider<
      VenueSubmissionController,
      VenueSubmissionControllerState
    >((ref) {
      return VenueSubmissionController(
        createUseCase: ref.watch(createVenueSubmissionUseCaseProvider),
        submitUseCase: ref.watch(submitVenueForReviewUseCaseProvider),
        getByIdUseCase: ref.watch(getVenueSubmissionByIdUseCaseProvider),
      );
    });
