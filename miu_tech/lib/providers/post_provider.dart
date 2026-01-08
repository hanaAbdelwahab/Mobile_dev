import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class PostProvider extends ChangeNotifier {
  // postId -> like count
  final Map<int, int> postLikeCounts = {};

  // set of postIds liked by the current user
  final Set<int> likedByMe = {};

  final int currentUserId;

  PostProvider({required this.currentUserId});

  // ===============================
  // Load likes for a specific post
  // ===============================
  Future<void> loadPostLikes(int postId) async {
    try {
      final response = await _supabase
          .from('likes')
          .select('user_id')
          .eq('post_id', postId);

      final List likesList = response as List;

      // set like count
      postLikeCounts[postId] = likesList.length;

      // check if current user liked this post
      likedByMe.remove(postId);
      for (final like in likesList) {
        if (like['user_id'] == currentUserId) {
          likedByMe.add(postId);
          break;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading likes for post $postId: $e');
    }
  }

  // ===============================
  // Toggle like (Optimistic UI)
  // ===============================
  Future<void> togglePostLike(int postId) async {
    final bool currentlyLiked = likedByMe.contains(postId);

    // ---- Optimistic update ----
    if (currentlyLiked) {
      likedByMe.remove(postId);
      postLikeCounts[postId] = (postLikeCounts[postId] ?? 1) - 1;
    } else {
      likedByMe.add(postId);
      postLikeCounts[postId] = (postLikeCounts[postId] ?? 0) + 1;
    }
    notifyListeners();

    try {
      if (currentlyLiked) {
        // unlike
        await _supabase.from('likes').delete().match({
          'post_id': postId,
          'user_id': currentUserId,
        });
      } else {
        // like
        await _supabase.from('likes').insert({
          'post_id': postId,
          'user_id': currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // ---- rollback if error ----
      if (currentlyLiked) {
        likedByMe.add(postId);
        postLikeCounts[postId] = (postLikeCounts[postId] ?? 0) + 1;
      } else {
        likedByMe.remove(postId);
        postLikeCounts[postId] = (postLikeCounts[postId] ?? 1) - 1;
      }
      notifyListeners();
      debugPrint('Error toggling like for post $postId: $e');
    }
  }

  // ===============================
  // Helper getters (optional)
  // ===============================
  int getLikeCount(int postId) {
    return postLikeCounts[postId] ?? 0;
  }

  bool isLikedByMe(int postId) {
    return likedByMe.contains(postId);
  }
}
