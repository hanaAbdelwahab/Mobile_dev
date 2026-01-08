import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class RepostProvider with ChangeNotifier {
  final int currentUserId;

  // Track which posts the current user has reposted
  final Set<int> _repostedByMe = {};

  // Cache repost counts per post
  final Map<int, int> _repostCounts = {};

  // Loading states
  final Set<int> _loadingPosts = {};

  RepostProvider({required this.currentUserId});

  // Getters
  Set<int> get repostedByMe => _repostedByMe;
  Map<int, int> get repostCounts => _repostCounts;

  bool isReposted(int postId) => _repostedByMe.contains(postId);
  int getRepostCount(int postId) => _repostCounts[postId] ?? 0;
  bool isLoading(int postId) => _loadingPosts.contains(postId);

  /// Load repost data for a specific post
  Future<void> loadRepostData(int postId) async {
    if (_loadingPosts.contains(postId)) return;

    _loadingPosts.add(postId);

    try {
      // Check if current user has reposted
      final myRepost = await supabase
          .from('reposts')
          .select('repost_id')
          .eq('post_id', postId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (myRepost != null) {
        _repostedByMe.add(postId);
      } else {
        _repostedByMe.remove(postId);
      }

      // Get total repost count
      final allReposts = await supabase
          .from('reposts')
          .select('repost_id')
          .eq('post_id', postId);

      _repostCounts[postId] = (allReposts as List).length;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading repost data for post $postId: $e');
    } finally {
      _loadingPosts.remove(postId);
    }
  }

  /// Load repost data for multiple posts
  Future<void> loadRepostsForPosts(List<int> postIds) async {
    if (postIds.isEmpty) return;

    try {
      // Batch load: check which posts current user has reposted
      final inClause = '(${postIds.join(",")})';
      final myReposts = await supabase
          .from('reposts')
          .select('post_id')
          .filter('post_id', 'in', inClause)
          .eq('user_id', currentUserId);

      _repostedByMe.clear();
      for (final r in myReposts as List) {
        _repostedByMe.add(r['post_id'] as int);
      }

      // Batch load: get repost counts for all posts
      final allReposts = await supabase
          .from('reposts')
          .select('post_id')
          .filter('post_id', 'in', inClause);

      _repostCounts.clear();
      for (final postId in postIds) {
        final count = (allReposts as List)
            .where((r) => r['post_id'] == postId)
            .length;
        _repostCounts[postId] = count;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading reposts for multiple posts: $e');
    }
  }

  /// Toggle repost status (optimistic update)
  Future<void> toggleRepost(int postId) async {
    final wasReposted = _repostedByMe.contains(postId);

    // Optimistic UI update
    if (wasReposted) {
      _repostedByMe.remove(postId);
      _repostCounts[postId] = (_repostCounts[postId] ?? 1) - 1;
    } else {
      _repostedByMe.add(postId);
      _repostCounts[postId] = (_repostCounts[postId] ?? 0) + 1;
    }
    notifyListeners();

    try {
      if (wasReposted) {
        // Remove repost
        await supabase
            .from('reposts')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUserId);
      } else {
        // Add repost
        await supabase.from('reposts').insert({
          'post_id': postId,
          'user_id': currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error toggling repost: $e');

      // Rollback on error
      if (wasReposted) {
        _repostedByMe.add(postId);
        _repostCounts[postId] = (_repostCounts[postId] ?? 0) + 1;
      } else {
        _repostedByMe.remove(postId);
        _repostCounts[postId] = (_repostCounts[postId] ?? 1) - 1;
      }
      notifyListeners();

      rethrow; // Let UI handle error display
    }
  }

  /// Get list of friends who reposted a post
  Future<List<Map<String, dynamic>>> getRepostedByFriends(
    int postId,
    List<int> friendIds,
  ) async {
    if (friendIds.isEmpty) return [];

    try {
      final inClause = '(${friendIds.join(",")})';
      final reposts = await supabase
          .from('reposts')
          .select('user_id')
          .eq('post_id', postId)
          .filter('user_id', 'in', inClause);

      if ((reposts as List).isEmpty) return [];

      // Get user names
      final userIds = reposts.map((r) => r['user_id'] as int).toList();
      final userInClause = '(${userIds.join(",")})';
      
      final users = await supabase
          .from('users')
          .select('user_id, name')
          .filter('user_id', 'in', userInClause);

      return (users as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting reposted by friends: $e');
      return [];
    }
  }

  /// Clear all cached data
  void clear() {
    _repostedByMe.clear();
    _repostCounts.clear();
    _loadingPosts.clear();
    notifyListeners();
  }

  /// Clear data for a specific post
  void clearPost(int postId) {
    _repostedByMe.remove(postId);
    _repostCounts.remove(postId);
    _loadingPosts.remove(postId);
    notifyListeners();
  }
}