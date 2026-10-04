import 'package:dabbler/core/feed/post_layout_resolver.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/presentation/widgets/public_activity_card.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show
        userPostsProvider,
        userLikedPostsProvider,
        userCommentedPostsProvider,
        userRepostedPostsProvider;
import 'package:dabbler/features/social/providers/public_activity_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The profile's feed: the five tabs and the posts, replies, likes, reposts
/// and activity of [profileId], each with the design's empty state.
class OwnProfileFeed extends ConsumerStatefulWidget {
  const OwnProfileFeed({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<OwnProfileFeed> createState() => _OwnProfileFeedState();
}

class _OwnProfileFeedState extends ConsumerState<OwnProfileFeed> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DabblerSpacing.space6,
          ),
          child: DabblerTabs(
            scrollable: true,
            value: '$_tab',
            onChanged: (String id) => setState(() => _tab = int.parse(id)),
            items: <DabblerTabItem>[
              DabblerTabItem(id: '0', label: l10n.profile_tab_posts),
              DabblerTabItem(id: '1', label: l10n.profile_tab_replies),
              DabblerTabItem(id: '2', label: l10n.profile_tab_liked),
              DabblerTabItem(id: '3', label: l10n.profile_tab_reposts),
              DabblerTabItem(id: '4', label: l10n.profile_tab_activity),
            ],
          ),
        ),
        _content(l10n),
      ],
    );
  }

  Widget _content(AppLocalizations l10n) {
    final String id = widget.profileId;
    final ({String profileId, int page}) key = (profileId: id, page: 0);
    switch (_tab) {
      case 1:
        return _posts(
          ref.watch(userCommentedPostsProvider(key)),
          l10n.profile_empty_no_replies,
        );
      case 2:
        return _posts(
          ref.watch(userLikedPostsProvider(key)),
          l10n.profile_empty_no_liked,
        );
      case 3:
        return _posts(
          ref.watch(userRepostedPostsProvider(key)),
          l10n.profile_empty_no_reposts,
        );
      case 4:
        return _activity(l10n);
      default:
        return _posts(
          ref.watch(userPostsProvider(key)),
          l10n.profile_empty_no_posts,
        );
    }
  }

  Widget _activity(AppLocalizations l10n) {
    final PublicActivitiesState state = ref.watch(
      userActivitiesProvider(widget.profileId),
    );
    if (state.isLoading && state.activities.isEmpty) {
      return const _Loading();
    }
    if (state.activities.isEmpty) {
      return _Empty(l10n.profile_empty_no_activity);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final activity in state.activities)
          PublicActivityCard(activity: activity),
      ],
    );
  }

  Widget _posts(AsyncValue<List<Post>> async, String empty) {
    return async.when(
      data: (List<Post> posts) {
        if (posts.isEmpty) return _Empty(empty);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[for (final Post post in posts) resolvePostLayout(post)],
        );
      },
      loading: () => const _Loading(),
      error: (Object _, StackTrace __) => Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space6),
        child: DabblerEmptyState.error(
          title: AppLocalizations.of(context).profile_error_failed_load_posts,
          size: DabblerEmptyStateSize.inline,
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(DabblerSpacing.space11),
    child: Center(child: DabblerSpinner()),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: DabblerSpacing.space6,
      vertical: DabblerSpacing.space8,
    ),
    child: DabblerEmptyState(icon: 'document-text', title: message),
  );
}
