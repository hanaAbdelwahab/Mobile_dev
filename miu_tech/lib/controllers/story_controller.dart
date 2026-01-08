import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class StoryController {
  static final _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchStories({
    required int currentUserId,
    required bool forYou,
  }) async {
    try {
      List<int> friendIds = [];

      // ================= FRIENDS =================
      if (forYou) {
        final friendsResult = await _supabase
            .from('friendships')
            .select('user_id, friend_id, status')
            .or(
              'and(user_id.eq.$currentUserId,status.eq.accepted),'
              'and(friend_id.eq.$currentUserId,status.eq.accepted)',
            );

        for (final f in friendsResult as List) {
          if (f['user_id'] != currentUserId) friendIds.add(f['user_id']);
          if (f['friend_id'] != currentUserId) friendIds.add(f['friend_id']);
        }

        if (friendIds.isEmpty) return [];
      }

      // ================= STORIES =================
      final List<dynamic> stories = forYou
          ? await _supabase
              .from('stories')
              .select('id, user_id, story_image, created_at')
              .filter('user_id', 'in', '(${friendIds.join(',')})')
              .order('created_at', ascending: false)
          : await _supabase
              .from('stories')
              .select('id, user_id, story_image, created_at')
              .order('created_at', ascending: false);

      List<Map<String, dynamic>> result = [];

      for (final story in stories) {
        // ================= USER =================
        final user = await _supabase
            .from('users')
            .select('name, profile_image')
            .eq('user_id', story['user_id'])
            .maybeSingle();

        // ================= SEEN CHECK =================
        final seen = await _supabase
            .from('story_views')
            .select('id')
            .eq('story_id', story['id'])
            .eq('viewer_id', currentUserId)
            .maybeSingle();

        result.add({
          'id': story['id'],
          'user_id': story['user_id'],
          'story_image': story['story_image'],
          'created_at': story['created_at'],
          'user_name': user?['name'],
          'profile_image': user?['profile_image'],
          'is_seen': seen != null, // ✅ أهم سطر
        });
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching stories: $e');
      debugPrint('$stackTrace');
      return [];
    }
  }
}
