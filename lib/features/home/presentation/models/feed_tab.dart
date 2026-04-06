/// Represents each tab in the Home Feed.
enum FeedTab {
  forYou,
  following,
  nearby,
  active,
  news;

  String get label => switch (this) {
    FeedTab.forYou => 'For You',
    FeedTab.following => 'Following',
    FeedTab.nearby => 'Nearby',
    FeedTab.active => 'Active',
    FeedTab.news => 'News',
  };
}
