class Friendship {
  final int friendshipId;
  final int userId;
  final int friendId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Friendship({
    required this.friendshipId,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      friendshipId: json['friendship_id'],
      userId: json['user_id'],
      friendId: json['friend_id'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
