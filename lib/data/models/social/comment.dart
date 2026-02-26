import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

/// Domain model for a post comment, mapping 1:1 to the `post_comments` table.
@freezed
class PostComment with _$PostComment {
  const factory PostComment({
    required String id,
    @JsonKey(name: 'post_id') required String postId,
    @JsonKey(name: 'author_user_id') required String authorUserId,
    @JsonKey(name: 'author_profile_id') required String authorProfileId,
    @JsonKey(name: 'author_display_name') String? authorDisplayName,
    required String body,
    @JsonKey(name: 'parent_comment_id') String? parentCommentId,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'is_hidden_admin') @Default(false) bool isHiddenAdmin,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _PostComment;

  factory PostComment.fromJson(Map<String, dynamic> json) =>
      _$PostCommentFromJson(json);
}
