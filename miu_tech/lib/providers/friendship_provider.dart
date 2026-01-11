import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class FriendshipProvider with ChangeNotifier {
  // Cache friendship status: userId -> {status, type}
  final Map<int, Map<String, dynamic>?> _friendshipCache = {};

  // Get cached status or null if not loaded
  Map<String, dynamic>? getCachedStatus(int targetUserId) {
    return _friendshipCache[targetUserId];
  }

  // Load friendship status for a user
  Future<Map<String, dynamic>?> loadFriendshipStatus(
    int currentUserId,
    int targetUserId,
  ) async {
    try {
      // Check if already friends
      final friendship = await supabase
          .from('friendships')
          .select()
          .or('and(user_id.eq.$currentUserId,friend_id.eq.$targetUserId),and(user_id.eq.$targetUserId,friend_id.eq.$currentUserId)')
          .maybeSingle();

      if (friendship != null && friendship['status'] == 'accepted') {
        _friendshipCache[targetUserId] = {'status': 'accepted', 'type': 'friendship'};
        notifyListeners();
        return _friendshipCache[targetUserId];
      }

      // Check if I sent a request
      final myRequest = await supabase
          .from('friendship_requests')
          .select()
          .eq('requester_id', currentUserId)
          .eq('receiver_id', targetUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (myRequest != null) {
        _friendshipCache[targetUserId] = {'status': 'pending', 'type': 'sent'};
        notifyListeners();
        return _friendshipCache[targetUserId];
      }

      // Check if they sent a request
      final theirRequest = await supabase
          .from('friendship_requests')
          .select()
          .eq('requester_id', targetUserId)
          .eq('receiver_id', currentUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (theirRequest != null) {
        _friendshipCache[targetUserId] = {'status': 'pending', 'type': 'received'};
        notifyListeners();
        return _friendshipCache[targetUserId];
      }

      _friendshipCache[targetUserId] = null;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('⚠️ Error checking friendship status: $e');
      return null;
    }
  }

  // Update status after action (call this after follow/unfollow/accept/reject)
  void updateStatus(int targetUserId, Map<String, dynamic>? newStatus) {
    _friendshipCache[targetUserId] = newStatus;
    notifyListeners();
  }

  // Clear cache for a specific user
  void clearStatus(int targetUserId) {
    _friendshipCache.remove(targetUserId);
    notifyListeners();
  }

  // Clear all cache
  void clearAll() {
    _friendshipCache.clear();
    notifyListeners();
  }
}