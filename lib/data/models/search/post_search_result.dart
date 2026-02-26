/// Lightweight model for a post returned by the unified search RPC.
///
/// Uses minimal fields to avoid coupling to the full [Post] Freezed model,
/// which requires many columns that the RPC may not return.
class PostSearchResult {
  final String id;
  final String body;
  final DateTime? createdAt;
  final String? authorDisplayName;

  const PostSearchResult({
    required this.id,
    required this.body,
    this.createdAt,
    this.authorDisplayName,
  });

  factory PostSearchResult.fromJson(Map<String, dynamic> json) {
    return PostSearchResult(
      id: (json['entity_id'] ?? json['id'] ?? '').toString(),
      body: (json['title'] ?? json['body'] ?? json['snippet'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      authorDisplayName: (json['subtitle'] ?? json['author_display_name'])
          ?.toString(),
    );
  }
}
