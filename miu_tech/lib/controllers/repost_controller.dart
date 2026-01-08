import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_controller.dart';
class RepostController {
  static final _supabase = Supabase.instance.client;

  
  static Future<bool> isReposted({
    required int postId,
    required int userId,
  }) async {
    final res = await _supabase
        .from('reposts')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    return res != null;
  }

  static Future<Map<String, dynamic>?> repostedByFriend({
    required int postId,
    required List<int> friendIds,
  }) async {
    if (friendIds.isEmpty) return null;

    final data = await _supabase
        .from('reposts')
        .select('user_id')
        .eq('post_id', postId)
        .filter('user_id', 'in', '(${friendIds.join(',')})')
        .limit(1)
        .maybeSingle();

    if (data == null) return null;

    return await UserController.fetchUserData(data['user_id']);
  }

  
  static Future<List<Map<String, dynamic>>> repostedByFriends({
    required int postId,
    required List<int> friendIds,
  }) async {
    if (friendIds.isEmpty) return [];

    try {
      final data = await _supabase
          .from('reposts')
          .select('user_id')
          .eq('post_id', postId)
          .filter('user_id', 'in', '(${friendIds.join(',')})');

      if (data == null || (data as List).isEmpty) return [];

      final List<Map<String, dynamic>> friends = [];

      for (final repost in data as List) {
        final userId = repost['user_id'];
        if (userId != null) {
          final userData = await UserController.fetchUserData(userId);
          if (userData != null) {
            friends.add(userData);
          }
        }
      }

      return friends;
    } catch (e) {
      print('Error fetching reposted by friends: $e');
      return [];
    }
  }

  // toggle repost
  static Future<void> toggleRepost({
    required int postId,
    required int userId,
  }) async {
    final existing = await _supabase
        .from('reposts')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('reposts').insert({
        'post_id': postId,
        'user_id': userId,
      });
    } else {
      await _supabase
          .from('reposts')
          .delete()
          .eq('id', existing['id']);
    }
  }

  static Future<int> repostCount(int postId) async {
    final data = await _supabase
        .from('reposts')
        .select('id')
        .eq('post_id', postId);

    return (data as List).length;
  }
  
}
