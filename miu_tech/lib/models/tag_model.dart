class TagModel {
  final int tagId;
  final String tagName;
  final int postId;

  TagModel({
    required this.tagId,
    required this.tagName,
    required this.postId,
  });

  factory TagModel.fromMap(Map<String, dynamic> map) {
    return TagModel(
      tagId: map['tag_id'],
      tagName: map['tag_name'] ?? '',
      postId: map['post_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tag_id': tagId,
      'tag_name': tagName,
      'post_id': postId,
    };
  }
}
