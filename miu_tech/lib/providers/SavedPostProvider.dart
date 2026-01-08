import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SavedPostProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  final Set<int> _savedPostIds = {};

  Set<int> get savedPostIds => _savedPostIds;

  // =========================
  // تحميل saved posts
  // =========================
  Future<void> loadSavedPosts(int userId) async {
    final res = await supabase
        .from('saved_posts')
        .select('post_id')
        .eq('user_id', userId);

    _savedPostIds
      ..clear()
      ..addAll((res as List).map((e) => e['post_id'] as int));

    notifyListeners();
  }

  // =========================
  // toggle save / unsave
  // =========================
  Future<void> toggleSave({
    required int userId,
    required int postId,
  }) async {
    if (_savedPostIds.contains(postId)) {
      // UNSAVE
      await supabase
          .from('saved_posts')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);

      _savedPostIds.remove(postId);
    } else {
      // SAVE
      await supabase.from('saved_posts').insert({
        'user_id': userId,
        'post_id': postId,
      });

      _savedPostIds.add(postId);
    }

    notifyListeners();
  }

  bool isSaved(int postId) => _savedPostIds.contains(postId);
}
