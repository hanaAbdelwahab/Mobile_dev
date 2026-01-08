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
      friendshipId: json['friendship_id'] is int
          ? json['friendship_id']
          : int.tryParse(json['friendship_id'].toString()) ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id'].toString()) ?? 0,
      friendId: json['friend_id'] is int
          ? json['friend_id']
          : int.tryParse(json['friend_id'].toString()) ?? 0,
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
