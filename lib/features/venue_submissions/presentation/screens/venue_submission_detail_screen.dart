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

/// The snack messages, now DS toasts (same text).
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

    // One layout at every width (a wide-screen shell is not a DS component).
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
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: DabblerInsets.screen,
          children: [
            submissionAsync.when(
              loading: () => const Center(child: DabblerSpinner()),
              error: (e, _) => _ErrorState(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(venueSubmissionByIdProvider(submissionId)),
              ),
              data: (Result<VenueSubmissionModel> result) => result.match(
                (failure) => _ErrorState(
                  message: failure.message,
                  onRetry: () =>
                      ref.invalidate(venueSubmissionByIdProvider(submissionId)),
                ),
                (submission) => _Details(submission: submission),
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

  /// One label/value line; empty values are left out.
  List<Widget> _kv(String label, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return const <Widget>[];
    return [
      DabblerInputRow(
        flat: true,
        showDivider: false,
        title: label,
        subtitle: v,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = (submission.nameEn ?? submission.nameAr ?? 'Untitled venue')
        .trim();
    final canEdit = submission.isEditable;
    final hasNote =
        submission.shouldShowAdminNote &&
        (submission.adminNote ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerCard(
          header: Row(
            children: [
              Expanded(
                child: DabblerText(
                  title,
                  style: DabblerType.title2,
                  weight: DabblerTextWeight.heavy,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VenueSubmissionStatusBadge(status: submission.status),
              ..._kv(
                'Location',
                <String?>[
                  submission.city,
                  submission.district,
                  submission.area,
                ].where((v) => (v ?? '').trim().isNotEmpty).join(', '),
              ),
            ],
          ),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        if (hasNote) ...[
          DabblerCard(
            header: const DabblerText(
              'Admin note',
              style: DabblerType.headline,
            ),
            child: DabblerText(submission.adminNote!, style: DabblerType.body),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
        ],
        DabblerCard(
          header: const DabblerText('Details', style: DabblerType.headline),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._kv('Name (EN)', submission.nameEn),
              ..._kv('Name (AR)', submission.nameAr),
              ..._kv('Description (EN)', submission.descriptionEn),
              ..._kv('Description (AR)', submission.descriptionAr),
              ..._kv('Address', submission.addressLine1),
              ..._kv('Phone', submission.phone),
              ..._kv('Website', submission.website),
              ..._kv('Instagram', submission.instagram),
              ..._kv(
                'Indoor',
                submission.isIndoor == null
                    ? null
                    : (submission.isIndoor! ? 'Yes' : 'No'),
              ),
              ..._kv('Surface type', submission.surfaceType),
              ..._kv(
                'Amenities',
                submission.amenities.isEmpty
                    ? null
                    : submission.amenities.join(', '),
              ),
            ],
          ),
        ),
        const DabblerGap.v(DabblerSpacing.space3),
        _ActionBar(submission: submission),
      ],
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
            DabblerText(
              'This submission is read-only while ${submission.status.name}.',
              style: DabblerType.body,
            ),
            const DabblerGap.v(DabblerSpacing.space3),
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
              result.match((failure) => _toast(context, failure.message), (_) {
                ref.invalidate(myVenueSubmissionsProvider);
                ref.invalidate(venueSubmissionByIdProvider(submission.id));
                _toast(context, 'Submitted for review.');
              });
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
