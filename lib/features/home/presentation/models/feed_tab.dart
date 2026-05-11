import 'package:dabbler/l10n/app_localizations.dart';

/// Represents each tab in the Home Feed.
enum FeedTab {
  forYou,
  following,
  nearby,
  active,
  news;

  String label(AppLocalizations l) => switch (this) {
        FeedTab.forYou => l.tab_most_recent,
        FeedTab.following => l.tab_following,
        FeedTab.nearby => l.tab_nearby,
        FeedTab.active => l.tab_active,
        FeedTab.news => l.tab_news,
      };
}
