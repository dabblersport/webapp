import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart' as core;
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/features/venue_submissions/providers.dart';
import 'package:dabbler/features/venue_submissions/presentation/widgets/venue_submission_status_badge.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

typedef Result<T> = core.Result<T, Failure>;

class VenueSubmissionDetailScreen extends ConsumerWidget {
  final String submissionId;

  const VenueSubmissionDetailScreen({super.key, required this.submissionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionAsync = ref.watch(venueSubmissionByIdProvider(submissionId));
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
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
              child: SizedBox(
                height: isWide ? 16 : MediaQuery.of(context).padding.top + 8,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Iconsax.arrow_left_copy),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Submission details',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: submissionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(venueSubmissionByIdProvider(submissionId)),
          ),
          data: (Result<VenueSubmissionModel> result) => result.match(
            (failure) => _ErrorState(
              message: failure.message,
              onRetry: () => ref.invalidate(venueSubmissionByIdProvider(submissionId)),
            ),
            (submission) {
              final title = (submission.nameEn ?? submission.nameAr ?? 'Untitled venue').trim();
              final canEdit = submission.isEditable;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card.filled(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                VenueSubmissionStatusBadge(status: submission.status),
                                const SizedBox(height: 12),
                                _kv(
                                  context,
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
                            IconButton.filledTonal(
                              onPressed: () => context.push(
                                RoutePaths.createVenueSubmission,
                                extra: submission,
                              ),
                              icon: const Icon(Iconsax.edit_2_copy),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (submission.shouldShowAdminNote && (submission.adminNote ?? '').trim().isNotEmpty)
                    Card.filled(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin note',
                              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(submission.adminNote!, style: textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  if (submission.shouldShowAdminNote && (submission.adminNote ?? '').trim().isNotEmpty)
                    const SizedBox(height: 12),
                  Card.filled(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Details',
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          _kv(context, label: 'Name (EN)', value: submission.nameEn),
                          _kv(context, label: 'Name (AR)', value: submission.nameAr),
                          _kv(context, label: 'Description (EN)', value: submission.descriptionEn),
                          _kv(context, label: 'Description (AR)', value: submission.descriptionAr),
                          _kv(context, label: 'Address', value: submission.addressLine1),
                          _kv(context, label: 'Phone', value: submission.phone),
                          _kv(context, label: 'Website', value: submission.website),
                          _kv(context, label: 'Instagram', value: submission.instagram),
                          _kv(context, label: 'Indoor', value: submission.isIndoor == null ? null : (submission.isIndoor! ? 'Yes' : 'No')),
                          _kv(context, label: 'Surface type', value: submission.surfaceType),
                          _kv(
                            context,
                            label: 'Amenities',
                            value: submission.amenities.isEmpty ? null : submission.amenities.join(', '),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionBar(submission: submission),
                ],
              );
            },
          ),
        ),
      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, {required String label, String? value}) {
    final textTheme = Theme.of(context).textTheme;
    final v = (value ?? '').trim();
    if (v.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(v, style: textTheme.bodyMedium),
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

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!submission.isEditable)
              Text(
                'This submission is read-only while ${submission.status.name}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (!submission.isEditable) const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (!canSubmit || busy)
                  ? null
                  : () async {
                      final result = await notifier.submitForReview(
                        submissionId: submission.id,
                        existing: submission,
                      );

                      result.match(
                        (failure) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(failure.message)),
                          );
                        },
                        (_) {
                          ref.invalidate(myVenueSubmissionsProvider);
                          ref.invalidate(venueSubmissionByIdProvider(submission.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Submitted for review.')),
                          );
                        },
                      );
                    },
              icon: const Icon(Iconsax.send_2_copy),
              label: const Text('Submit for review'),
            ),
          ],
        ),
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
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.danger_copy, size: 56),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load submission',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, style: textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
