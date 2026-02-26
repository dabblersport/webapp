/// Lightweight model for a hashtag returned by the unified search RPC.
class HashtagSearchResult {
  final String id;
  final String slug;
  final String? displayTag;
  final int postCount;

  const HashtagSearchResult({
    required this.id,
    required this.slug,
    this.displayTag,
    required this.postCount,
  });

  factory HashtagSearchResult.fromJson(Map<String, dynamic> json) {
    return HashtagSearchResult(
      id: (json['id'] ?? json['entity_id'] ?? json['slug'] ?? '').toString(),
      slug: (json['slug'] ?? json['tag'] ?? json['name'] ?? '').toString(),
      displayTag: json['display_tag']?.toString(),
      postCount:
          (json['usage_count'] as num?)?.toInt() ??
          (json['post_count'] as num?)?.toInt() ??
          0,
    );
  }
}
