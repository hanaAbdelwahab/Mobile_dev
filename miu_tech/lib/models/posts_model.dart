class PostModel {
  final int postId;
  final int authorId;
  final String title;
  final String content;
  final int categoryId;
  final String type;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;

  PostModel({
    required this.postId,
    required this.authorId,
    required this.title,
    required this.content,
    required this.categoryId,
    required this.type,
    this.mediaUrl,
    required this.createdAt,
    this.updatedAt,
    required this.likesCount
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      postId: map['post_id'],
      authorId: map['author_id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      categoryId: map['category_id'],
      type: map['type'] ?? '',
      mediaUrl: map['media_url'] == "" ? null : map['media_url'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'])
          : null,
          likesCount: (map['likes'] != null && map['likes'].isNotEmpty)
        ? map['likes'][0]['count']
        : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'author_id': authorId,
      'title': title,
      'content': content,
      'category_id': categoryId,
      'type': type,
      'media_url': mediaUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
