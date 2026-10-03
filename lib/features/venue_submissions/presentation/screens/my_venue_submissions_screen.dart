import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/fp/result.dart' as core;
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/features/venue_submissions/providers.dart';
import 'package:dabbler/features/venue_submissions/presentation/widgets/venue_submission_status_badge.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

typedef Result<T> = core.Result<T, Failure>;

/// No design frame: design-system defaults in the same structure.
class MyVenueSubmissionsScreen extends ConsumerWidget {
  const MyVenueSubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(myVenueSubmissionsProvider);

    // One layout at every width (AdaptiveScaffold is not a DS component).
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Venue submissions',
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          DabblerNavigationAction(
            icon: 'add',
            label: 'Create submission',
            onPressed: () => context.push(RoutePaths.createVenueSubmission),
          ),
        ],
      ),
      body: DabblerRefresh(
        onRefresh: () async {
          ref.invalidate(myVenueSubmissionsProvider);
          await ref.read(myVenueSubmissionsProvider.future);
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
                child: submissionsAsync.when(
                  loading: () => const Center(child: DabblerSpinner()),
                  error: (e, _) => _ErrorState(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(myVenueSubmissionsProvider),
                  ),
                  data: (Result<List<VenueSubmissionModel>> result) {
                    return result.match(
                      (failure) => _ErrorState(
                        message: failure.message,
                        onRetry: () =>
                            ref.invalidate(myVenueSubmissionsProvider),
                      ),
                      (submissions) {
                        if (submissions.isEmpty) {
                          return _EmptyState(
                            onCreate: () =>
                                context.push(RoutePaths.createVenueSubmission),
                          );
                        }
                        return _SubmissionList(submissions: submissions);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionList extends StatelessWidget {
  const _SubmissionList({required this.submissions});

  final List<VenueSubmissionModel> submissions;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final dir = Directionality.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DabblerBanner(
          message: 'Drafts can be edited. Pending/approved are read-only.',
          icon: DabblerIcon('info-circle'),
        ),
        const SizedBox(height: DabblerSpacing.space3),
        for (var i = 0; i < submissions.length; i++) ...[
          if (i > 0) const SizedBox(height: DabblerSpacing.space2),
          Builder(
            builder: (context) {
              final s = submissions[i];
              final title = (s.nameEn ?? s.nameAr ?? 'Untitled venue').trim();
              final location = <String?>[s.city, s.district]
                  .where((v) => (v ?? '').trim().isNotEmpty)
                  .map((v) => v!.trim())
                  .join(', ');
              final hasNote =
                  s.shouldShowAdminNote &&
                  (s.adminNote ?? '').trim().isNotEmpty;

              return DabblerCard(
                onTap: () =>
                    context.push(RoutePaths.venueSubmissionDetail(s.id)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: DabblerType.headline
                                .resolveForDirection(dir)
                                .copyWith(color: colors.textPrimary),
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: DabblerSpacing.space1),
                            Text(
                              location,
                              style: DabblerType.footnote
                                  .resolveForDirection(dir)
                                  .copyWith(color: colors.textSecondary),
                            ),
                          ],
                          if (hasNote) ...[
                            const SizedBox(height: DabblerSpacing.space2),
                            Text(
                              'Admin note: ${s.adminNote}',
                              style: DabblerType.footnote
                                  .resolveForDirection(dir)
                                  .copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: DabblerSpacing.space3),
                    VenueSubmissionStatusBadge(status: s.status),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: DabblerSpacing.space4),
        DabblerButton(
          label: 'Create new submission',
          icon: 'add',
          fullWidth: true,
          onPressed: () => context.push(RoutePaths.createVenueSubmission),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return DabblerEmptyState(
      icon: 'building-4',
      title: 'No submissions yet',
      text: 'Create a draft and submit it for review when ready.',
      size: DabblerEmptyStateSize.page,
      action: DabblerButton(label: 'Create submission', onPressed: onCreate),
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
      title: 'Couldn\'t load submissions',
      text: message,
      retryLabel: 'Retry',
      onRetry: onRetry,
    );
  }
}
