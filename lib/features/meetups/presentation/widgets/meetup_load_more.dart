import 'package:dabbler/features/explore/presentation/widgets/listing_parts.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "Load more" row at the end of the meetups list (KAN-932): adds one
/// page to [meetupListPagesProvider] for [sportId]. Draws nothing once the
/// last loaded page came back short (no more upcoming meetups).
class MeetupLoadMore extends ConsumerWidget {
  const MeetupLoadMore({super.key, required this.sportId});

  final String? sportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(meetupListProvider(sportId));
    final pages = ref.watch(meetupListPagesProvider(sportId));
    final items = list.valueOrNull;
    if (items == null || !meetupListHasMore(items, pages)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: ListingLayout.cardGap,
        start: ListingLayout.gutter,
        end: ListingLayout.gutter,
      ),
      child: DabblerButton(
        label: AppLocalizations.of(context).meetups_load_more,
        tone: DabblerButtonTone.neutral,
        fullWidth: true,
        loading: list.isLoading,
        onPressed: list.isLoading
            ? null
            : () => ref
                  .read(meetupListPagesProvider(sportId).notifier)
                  .update((p) => p + 1),
      ),
    );
  }
}
