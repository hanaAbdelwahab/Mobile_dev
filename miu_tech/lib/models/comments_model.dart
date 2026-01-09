class CommentModel {
  final int commentId;
  final int postId;
  final int userId;
  final String content;
  final DateTime createdAt;
  final int? parentCommentId; // new, nullable for replies

  CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.parentCommentId,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      commentId: map['comment_id'],
      postId: map['post_id'],
      userId: map['user_id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      parentCommentId: map.containsKey('parent_comment_id') && map['parent_comment_id'] != null
          ? map['parent_comment_id'] as int
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
    };
  }
}
