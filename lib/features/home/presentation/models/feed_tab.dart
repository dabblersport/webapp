/// Represents each tab in the Home Feed.
enum FeedTab {
  forYou,
  following,
  nearby,
  active,
  news;

  String get label => switch (this) {
    FeedTab.forYou => 'Most Recent',
    FeedTab.following => 'Following',
    FeedTab.nearby => 'Nearby',
    FeedTab.active => 'Active',
    FeedTab.news => 'News',
  };
}
