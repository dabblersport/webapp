/// Lightweight model for a comment returned by the unified search RPC.
///
/// The deep-link route for navigation is:
///   /social-post-detail/{postId}#comment-{id}
class CommentSearchResult {
  final String id;
  final String postId;
  final String snippet;

  /// Title of the parent post (may be null if the post has no body).
  final String? postTitle;

  const CommentSearchResult({
    required this.id,
    required this.postId,
    required this.snippet,
    this.postTitle,
  });

  factory CommentSearchResult.fromJson(Map<String, dynamic> json) {
    return CommentSearchResult(
      id: (json['entity_id'] ?? json['id'] ?? '').toString(),
      postId: (json['post_id'] ?? '').toString(),
      snippet: (json['title'] ?? json['snippet'] ?? json['body'] ?? '')
          .toString(),
      postTitle: (json['subtitle'] ?? json['post_title'])?.toString(),
    );
  }
}
