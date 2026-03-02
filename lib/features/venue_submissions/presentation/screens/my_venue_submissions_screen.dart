import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/fp/result.dart' as core;
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/features/venue_submissions/providers.dart';
import 'package:dabbler/features/venue_submissions/presentation/widgets/venue_submission_status_badge.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

typedef Result<T> = core.Result<T, Failure>;

class MyVenueSubmissionsScreen extends ConsumerWidget {
  const MyVenueSubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(myVenueSubmissionsProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
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
                        'Venue submissions',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () =>
                          context.push(RoutePaths.createVenueSubmission),
                      icon: const Icon(Iconsax.add_copy),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: submissionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card.filled(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(Iconsax.info_circle_copy),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Drafts can be edited. Pending/approved are read-only.',
                                        style: textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: submissions.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final s = submissions[index];
                                final title =
                                    (s.nameEn ?? s.nameAr ?? 'Untitled venue')
                                        .trim();
                                final location = <String?>[s.city, s.district]
                                    .where((v) => (v ?? '').trim().isNotEmpty)
                                    .map((v) => v!.trim())
                                    .join(', ');

                                return Card.filled(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => context.push(
                                      RoutePaths.venueSubmissionDetail(s.id),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: textTheme.titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                                if (location.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    location,
                                                    style: textTheme.bodySmall,
                                                  ),
                                                ],
                                                if (s.shouldShowAdminNote &&
                                                    (s.adminNote ?? '')
                                                        .trim()
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Admin note: ${s.adminNote}',
                                                    style: textTheme.bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          VenueSubmissionStatusBadge(
                                            status: s.status,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => context.push(
                                RoutePaths.createVenueSubmission,
                              ),
                              icon: const Icon(Iconsax.add_copy),
                              label: const Text('Create new submission'),
                            ),
                          ],
                        );
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.building_4_copy, size: 56),
            const SizedBox(height: 16),
            Text(
              'No submissions yet',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a draft and submit it for review when ready.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onCreate,
              child: const Text('Create submission'),
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
              'Couldn\'t load submissions',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
