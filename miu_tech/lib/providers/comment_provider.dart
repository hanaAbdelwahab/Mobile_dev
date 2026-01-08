import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comments_model.dart';

final supabase = Supabase.instance.client;

class CommentProvider extends ChangeNotifier {
  List<CommentModel> comments = [];
  Map<int?, List<CommentModel>> tree = {};
  Map<int, int> likeCounts = {};
  Set<int> likedByMe = {};
  bool loading = false;

  Future<void> loadComments(int postId, int userId) async {
    loading = true;
    notifyListeners();

    try {
      final data = await supabase
          .from('comments')
          .select('*')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      comments = (data as List)
          .map((e) => CommentModel.fromMap(e))
          .toList();

      /// Build comment tree
      tree = {};
      for (final c in comments) {
        tree.putIfAbsent(c.parentCommentId, () => []);
        tree[c.parentCommentId]!.add(c);
      }

      /// Load likes
      likeCounts.clear();
      likedByMe.clear();

      if (comments.isNotEmpty) {
        final ids = comments.map((e) => e.commentId).join(',');
        final likes = await supabase
            .from('comment_likes')
            .select('comment_id, user_id')
            .filter('comment_id', 'in', '($ids)');

        for (final l in likes as List) {
          final cid = l['comment_id'] as int;
          final uid = l['user_id'] as int;

          likeCounts[cid] = (likeCounts[cid] ?? 0) + 1;
          if (uid == userId) likedByMe.add(cid);
        }
      }
    } catch (e) {
      debugPrint("loadComments error: $e");
    }

    loading = false;
    notifyListeners();
  }

  Future<void> addComment(int postId, int userId, String text) async {
    await supabase.from('comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'parent_comment_id': null,
    });

    await loadComments(postId, userId);
  }

  Future<void> addReply(int postId, int userId, int parentId, String text) async {
    await supabase.from('comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'parent_comment_id': parentId,
    });

    await loadComments(postId, userId);
  }

  Future<void> toggleLike(int commentId, int userId) async {
    final liked = likedByMe.contains(commentId);

    if (liked) {
      likedByMe.remove(commentId);
      likeCounts[commentId] = (likeCounts[commentId] ?? 1) - 1;
      await supabase
          .from('comment_likes')
          .delete()
          .match({'comment_id': commentId, 'user_id': userId});
    } else {
      likedByMe.add(commentId);
      likeCounts[commentId] = (likeCounts[commentId] ?? 0) + 1;
      await supabase.from('comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    notifyListeners();
  }
}
