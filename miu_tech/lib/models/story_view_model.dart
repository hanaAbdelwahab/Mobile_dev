import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class StoryViewModel {
  static final _supabase = Supabase.instance.client;

  // =========================
  // هل اليوزر شاف الستوري دي؟
  // =========================
  static Future<bool> isStorySeen({
    required int storyId,
    required int viewerId,
  }) async {
    try {
      final res = await _supabase
          .from('story_views')
          .select('id')
          .eq('story_id', storyId)
          .eq('viewer_id', viewerId)
          .maybeSingle();

      return res != null;
    } catch (e) {
      debugPrint('Error checking story seen: $e');
      return false;
    }
  }

  // =========================
  // هل كل stories بتوع الشخص اتشافوا؟
  // =========================
  static Future<bool> areAllStoriesSeen({
    required List<Map<String, dynamic>> stories,
    required int viewerId,
  }) async {
    try {
      for (final story in stories) {
        final storyId = story['id'];

        final seen = await _supabase
            .from('story_views')
            .select('id')
            .eq('story_id', storyId)
            .eq('viewer_id', viewerId)
            .maybeSingle();

        if (seen == null) {
          return false; // لسه في ستوري متشافِتش
        }
      }

      return true; // كله اتشاف
    } catch (e) {
      debugPrint('Error checking all stories seen: $e');
      return false;
    }
  }

  // =========================
  // ترتيب المستخدمين:
  // unseen فوق – seen تحت
  // =========================
  static Future<List<MapEntry<int, List<Map<String, dynamic>>>>> sortUsersBySeen({
    required List<MapEntry<int, List<Map<String, dynamic>>>> users,
    required int viewerId,
  }) async {
    final unseenUsers = <MapEntry<int, List<Map<String, dynamic>>>>[];
    final seenUsers = <MapEntry<int, List<Map<String, dynamic>>>>[];

    for (final user in users) {
      final allSeen = await areAllStoriesSeen(
        stories: user.value,
        viewerId: viewerId,
      );

      if (allSeen) {
        seenUsers.add(user);
      } else {
        unseenUsers.add(user);
      }
    }

    return [...unseenUsers, ...seenUsers];
  }
}
