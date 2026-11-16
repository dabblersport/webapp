import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/location/providers/listing_city.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// KAN-962: one tag of a tab's filter row (`Home Feed.dc.html`, `TAGS`).
enum HomeTabTag {
  allSports(null),
  mySports('medal-star'),
  city('location'),
  country('map'),
  anywhere('global'),
  newsFollowing('people'),
  newsAll('document-text');

  const HomeTabTag(this.icon);

  /// The chip's bold leading glyph, or null for none.
  final String? icon;
}

/// KAN-962: the tags of [tab]'s filter row, in the design's order (`TAGS`).
/// The first tag clears the tab's picks and is on while none is picked.
/// Active has its own panel (`actPanel`), so it has no tag row here.
List<HomeTabTag> homeTabTags(FeedTab tab) => switch (tab) {
  FeedTab.forYou => const <HomeTabTag>[
    HomeTabTag.allSports,
    HomeTabTag.mySports,
  ],
  FeedTab.nearby => const <HomeTabTag>[
    HomeTabTag.city,
    HomeTabTag.country,
    HomeTabTag.anywhere,
  ],
  FeedTab.news => const <HomeTabTag>[
    HomeTabTag.newsFollowing,
    HomeTabTag.newsAll,
  ],
  _ => const <HomeTabTag>[],
};

/// KAN-962: each tab's picked tags (`state.picks`). Not autoDispose: the picks
/// persist across tab switches. A tab with no entry has nothing picked.
final homeTabPicksProvider = StateProvider<Map<FeedTab, List<HomeTabTag>>>(
  (ref) => const <FeedTab, List<HomeTabTag>>{},
);

/// KAN-962: the picks after tapping [tag] on [tab] (`subTags[].select`). The
/// first tag clears the tab's picks; any other toggles in or out, in tap
/// order. Other tabs are untouched.
Map<FeedTab, List<HomeTabTag>> toggleHomeTabPick(
  Map<FeedTab, List<HomeTabTag>> picks,
  FeedTab tab,
  HomeTabTag tag,
) {
  final tags = homeTabTags(tab);
  if (tags.isEmpty || !tags.contains(tag)) return picks;
  final cur = picks[tab] ?? const <HomeTabTag>[];
  final next = tag == tags.first
      ? const <HomeTabTag>[]
      : cur.contains(tag)
      ? <HomeTabTag>[
          for (final t in cur)
            if (t != tag) t,
        ]
      : <HomeTabTag>[...cur, tag];
  return <FeedTab, List<HomeTabTag>>{...picks, tab: next};
}

/// KAN-962: whether [tag] paints on (`subTags[].on`): the first tag while
/// nothing is picked, any other while picked.
bool homeTabTagOn(List<HomeTabTag> picks, FeedTab tab, HomeTabTag tag) {
  final tags = homeTabTags(tab);
  if (tags.isEmpty) return false;
  return tag == tags.first ? picks.isEmpty : picks.contains(tag);
}

/// The label of [tag]. Nearby's city and country come from the listing city.
String homeTabTagLabel(AppLocalizations l, HomeTabTag tag, ListingCity? city) =>
    switch (tag) {
      HomeTabTag.allSports => l.home_sport_all,
      HomeTabTag.mySports => l.home_tag_my_sports,
      HomeTabTag.city => city?.name ?? l.home_tag_city,
      HomeTabTag.country => city?.country ?? l.home_tag_country,
      HomeTabTag.anywhere => l.home_tag_anywhere,
      HomeTabTag.newsFollowing => l.home_tag_news_following,
      HomeTabTag.newsAll => l.home_tag_news_all,
    };

/// KAN-962: a tab's filter row (`Home Feed.dc.html:267-281`, `showSubTags`):
/// its tags as chips; tapping one toggles it in the tab's picks.
class HomeTabTagRail extends ConsumerWidget {
  const HomeTabTagRail({super.key, required this.tab});

  final FeedTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final picks = ref.watch(homeTabPicksProvider)[tab] ?? const <HomeTabTag>[];
    final city = tab == FeedTab.nearby ? ref.watch(listingCityProvider) : null;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: DabblerSpacing.space4,
      ),
      child: SingleChildScrollView(
        key: ValueKey<String>('home-tag-rail-${tab.name}'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: DabblerInsets.feedScreen.left,
        ),
        child: Row(
          spacing: DabblerSpacing.space2,
          children: <Widget>[
            for (final tag in homeTabTags(tab))
              DabblerChip(
                key: ValueKey<String>('home-tag-${tag.name}'),
                label: homeTabTagLabel(l, tag, city),
                selected: homeTabTagOn(picks, tab, tag),
                metrics: DabblerFeedMetrics.drawn,
                leadingIcon: tag.icon == null
                    ? null
                    : DabblerIcon(tag.icon!, weight: DabblerIconWeight.bold),
                onTap: () {
                  final n = ref.read(homeTabPicksProvider.notifier);
                  n.state = toggleHomeTabPick(n.state, tab, tag);
                },
              ),
          ],
        ),
      ),
    );
  }
}
