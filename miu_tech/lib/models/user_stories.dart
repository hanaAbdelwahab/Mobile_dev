import 'user_model.dart';
import 'story.dart';

class UserStories {
  final UserModel user;
  final List<Story> stories;

  UserStories({required this.user, required this.stories});

  /// Check if this user is the current logged-in user
  bool isMine(int currentUserId) => user.userId == currentUserId;

  /// Check if there are any stories the current user hasn't seen yet
  bool hasUnseen(int currentUserId) {
    return stories.any((s) => !s.seenBy.contains(currentUserId));
  }
}
