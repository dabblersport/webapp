import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart' as core;
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/features/venue_submissions/providers.dart';
import 'package:dabbler/features/venue_submissions/presentation/widgets/venue_submission_status_badge.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

typedef Result<T> = core.Result<T, Failure>;

TextStyle _type(BuildContext context, DabblerTypeStyle style, Color color,
        {FontWeight? weight}) =>
    style
        .resolveForDirection(Directionality.of(context))
        .copyWith(color: color, fontWeight: weight);

/// The SnackBar messages, now DS toasts (same text).
void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  DabblerToastProvider.of(context).show(DabblerToastSpec(message: message));
}

/// No design frame: design-system defaults in the same structure.
class VenueSubmissionDetailScreen extends ConsumerWidget {
  final String submissionId;

  const VenueSubmissionDetailScreen({super.key, required this.submissionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionAsync = ref.watch(
      venueSubmissionByIdProvider(submissionId),
    );

    // One layout at every width (AdaptiveScaffold is not a DS component).
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Submission details',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: DabblerRefresh(
        onRefresh: () async {
          ref.invalidate(venueSubmissionByIdProvider(submissionId));
          await ref.read(venueSubmissionByIdProvider(submissionId).future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space6,
                  DabblerSpacing.space3,
                  DabblerSpacing.space6,
                  DabblerSpacing.space6,
                ),
                child: submissionAsync.when(
                  loading: () => const Center(child: DabblerSpinner()),
                  error: (e, _) => _ErrorState(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(
                      venueSubmissionByIdProvider(submissionId),
                    ),
                  ),
                  data: (Result<VenueSubmissionModel> result) => result.match(
                    (failure) => _ErrorState(
                      message: failure.message,
                      onRetry: () => ref.invalidate(
                        venueSubmissionByIdProvider(submissionId),
                      ),
                    ),
                    (submission) => _Details(submission: submission),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.submission});

  final VenueSubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final title =
        (submission.nameEn ?? submission.nameAr ?? 'Untitled venue').trim();
    final canEdit = submission.isEditable;
    final hasNote = submission.shouldShowAdminNote &&
        (submission.adminNote ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _type(context, DabblerType.title2,
                          colors.textPrimary,
                          weight: FontWeight.w800),
                    ),
                    const SizedBox(height: DabblerSpacing.space2),
                    VenueSubmissionStatusBadge(status: submission.status),
                    const SizedBox(height: DabblerSpacing.space3),
                    _Kv(
                      label: 'Location',
                      value: <String?>[
                        submission.city,
                        submission.district,
                        submission.area,
                      ].where((v) => (v ?? '').trim().isNotEmpty).join(', '),
                    ),
                  ],
                ),
              ),
              if (canEdit)
                DabblerButton.icon(
                  icon: 'edit-2',
                  semanticLabel: 'Edit submission',
                  onPressed: () => context.push(
                    RoutePaths.createVenueSubmission,
                    extra: submission,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: DabblerSpacing.space3),
        if (hasNote) ...[
          DabblerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin note',
                  style: _type(context, DabblerType.headline,
                      colors.textPrimary),
                ),
                const SizedBox(height: DabblerSpacing.space2),
                Text(
                  submission.adminNote!,
                  style: _type(context, DabblerType.body, colors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: DabblerSpacing.space3),
        ],
        DabblerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Details',
                style: _type(context, DabblerType.headline, colors.textPrimary),
              ),
              const SizedBox(height: DabblerSpacing.space3),
              _Kv(label: 'Name (EN)', value: submission.nameEn),
              _Kv(label: 'Name (AR)', value: submission.nameAr),
              _Kv(label: 'Description (EN)', value: submission.descriptionEn),
              _Kv(label: 'Description (AR)', value: submission.descriptionAr),
              _Kv(label: 'Address', value: submission.addressLine1),
              _Kv(label: 'Phone', value: submission.phone),
              _Kv(label: 'Website', value: submission.website),
              _Kv(label: 'Instagram', value: submission.instagram),
              _Kv(
                label: 'Indoor',
                value: submission.isIndoor == null
                    ? null
                    : (submission.isIndoor! ? 'Yes' : 'No'),
              ),
              _Kv(label: 'Surface type', value: submission.surfaceType),
              _Kv(
                label: 'Amenities',
                value: submission.amenities.isEmpty
                    ? null
                    : submission.amenities.join(', '),
              ),
            ],
          ),
        ),
        const SizedBox(height: DabblerSpacing.space3),
        _ActionBar(submission: submission),
      ],
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final v = (value ?? '').trim();
    if (v.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _type(context, DabblerType.footnote, colors.textSecondary,
                weight: FontWeight.w700),
          ),
          const SizedBox(height: DabblerSpacing.space1),
          Text(v, style: _type(context, DabblerType.body, colors.textPrimary)),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  final VenueSubmissionModel submission;

  const _ActionBar({required this.submission});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(venueSubmissionControllerProvider);
    final notifier = ref.read(venueSubmissionControllerProvider.notifier);

    final canSubmit = submission.canSubmitForReview;
    final busy = controller.isSaving;

    return DabblerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!submission.isEditable) ...[
            Text(
              'This submission is read-only while ${submission.status.name}.',
              style: _type(context, DabblerType.body,
                  DabblerColors.of(context).textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space3),
          ],
          DabblerButton(
            label: 'Submit for review',
            icon: 'send-2',
            fullWidth: true,
            disabled: !canSubmit || busy,
            onPressed: () async {
              final result = await notifier.submitForReview(
                submissionId: submission.id,
                existing: submission,
              );
              result.match(
                (failure) => _toast(context, failure.message),
                (_) {
                  ref.invalidate(myVenueSubmissionsProvider);
                  ref.invalidate(venueSubmissionByIdProvider(submission.id));
                  _toast(context, 'Submitted for review.');
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return DabblerEmptyState.error(
      title: 'Couldn\'t load submission',
      text: message,
      retryLabel: 'Retry',
      onRetry: onRetry,
    );
  }
}
