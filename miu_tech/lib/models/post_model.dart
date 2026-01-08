class PostModel {
  final String postId;
  final String authorId;
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
    required this.likesCount,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      postId: map['post_id']?.toString() ?? '',
      authorId: map['author_id']?.toString() ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      categoryId: map['category_id'] ?? 0,
      type: map['type'] ?? 'post',
      mediaUrl:
          (map['media_url'] != null && map['media_url'].toString().isNotEmpty)
          ? map['media_url']
          : null,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      likesCount:
          (map['likes'] != null &&
              map['likes'] is List &&
              (map['likes'] as List).isNotEmpty)
          ? (map['likes'][0]['count'] ?? 0)
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
