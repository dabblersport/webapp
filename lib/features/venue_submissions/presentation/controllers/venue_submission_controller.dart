import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart' as core;
import 'package:dabbler/core/fp/result.dart' show Err, Ok;
import 'package:dabbler/data/models/venue_submission_model.dart';

import '../../domain/usecases/create_venue_submission_usecase.dart';
import '../../domain/usecases/get_venue_submission_by_id_usecase.dart';
import '../../domain/usecases/submit_venue_for_review_usecase.dart';

typedef Result<T> = core.Result<T, Failure>;

class VenueSubmissionControllerState {
  final bool isSaving;
  final Failure? failure;
  final VenueSubmissionModel? lastSaved;

  const VenueSubmissionControllerState({
    this.isSaving = false,
    this.failure,
    this.lastSaved,
  });

  VenueSubmissionControllerState copyWith({
    bool? isSaving,
    Failure? failure,
    VenueSubmissionModel? lastSaved,
    bool clearFailure = false,
  }) {
    return VenueSubmissionControllerState(
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : (failure ?? this.failure),
      lastSaved: lastSaved ?? this.lastSaved,
    );
  }
}

class VenueSubmissionController
    extends StateNotifier<VenueSubmissionControllerState> {
  VenueSubmissionController({
    required CreateVenueSubmissionUseCase createUseCase,
    required SubmitVenueForReviewUseCase submitUseCase,
    required GetVenueSubmissionByIdUseCase getByIdUseCase,
  }) : _createUseCase = createUseCase,
       _submitUseCase = submitUseCase,
       _getByIdUseCase = getByIdUseCase,
       super(const VenueSubmissionControllerState());

  final CreateVenueSubmissionUseCase _createUseCase;
  final SubmitVenueForReviewUseCase _submitUseCase;
  final GetVenueSubmissionByIdUseCase _getByIdUseCase;

  Future<Result<VenueSubmissionModel>> saveDraft({
    required String organiserProfileId,
    required VenueSubmissionDraft draft,
    VenueSubmissionModel? existing,
  }) async {
    state = state.copyWith(isSaving: true, clearFailure: true);

    try {
      VenueSubmissionModel? resolvedExisting = existing;

      if (resolvedExisting == null && draft.id != null && draft.id!.isNotEmpty) {
        final existingResult = await _getByIdUseCase(draft.id!);
        resolvedExisting = existingResult.fold((_) => null, (s) => s);
      }

      if (resolvedExisting != null && !resolvedExisting.isEditable) {
        final failure = ValidationFailure(
          message: 'This submission cannot be edited while ${resolvedExisting.status.name}.',
        );
        state = state.copyWith(isSaving: false, failure: failure);
        return Err(failure);
      }

      final result = await _createUseCase(
        organiserProfileId: organiserProfileId,
        draft: draft,
      );

      return await result.fold(
        (failure) {
          state = state.copyWith(isSaving: false, failure: failure);
          return Err(failure);
        },
        (submission) {
          state = state.copyWith(isSaving: false, lastSaved: submission);
          return Ok(submission);
        },
      );
    } catch (e, st) {
      final failure = Failure.from(e, st);
      state = state.copyWith(isSaving: false, failure: failure);
      return Err(failure);
    }
  }

  Future<Result<VenueSubmissionModel>> submitForReview({
    required String submissionId,
    VenueSubmissionModel? existing,
  }) async {
    state = state.copyWith(isSaving: true, clearFailure: true);

    try {
      VenueSubmissionModel? resolvedExisting = existing;
      if (resolvedExisting == null) {
        final existingResult = await _getByIdUseCase(submissionId);
        resolvedExisting = existingResult.fold((_) => null, (s) => s);
      }

      if (resolvedExisting != null && !resolvedExisting.canSubmitForReview) {
        final failure = ValidationFailure(
          message: 'You can only submit drafts or returned submissions for review.',
        );
        state = state.copyWith(isSaving: false, failure: failure);
        return Err(failure);
      }

      final result = await _submitUseCase(submissionId: submissionId);

      return await result.fold(
        (failure) {
          state = state.copyWith(isSaving: false, failure: failure);
          return Err(failure);
        },
        (submission) {
          state = state.copyWith(isSaving: false, lastSaved: submission);
          return Ok(submission);
        },
      );
    } catch (e, st) {
      final failure = Failure.from(e, st);
      state = state.copyWith(isSaving: false, failure: failure);
      return Err(failure);
    }
  }
}
