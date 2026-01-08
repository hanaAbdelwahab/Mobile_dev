class StoryModel {
  final int id;
  final int userId;
  final String storyImage;
  final DateTime createdAt;

  StoryModel({
    required this.id,
    required this.userId,
    required this.storyImage,
    required this.createdAt,
  });

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    return StoryModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      storyImage: map['story_image'] as String,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
