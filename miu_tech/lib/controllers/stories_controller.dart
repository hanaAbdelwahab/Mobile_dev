import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_stories.dart';
import '../models/user_model.dart';
import '../models/story.dart';
import '../models/Friendship.dart';

// =======================
// State
// =======================
class StoriesState {
  final UserStories? myStory;
  final List<UserStories> friendsStories;

  const StoriesState({this.myStory, this.friendsStories = const []});
}

// =======================
// Controller (Riverpod 3.x)
// =======================
class StoriesController extends StateNotifier<AsyncValue<StoriesState>> {
  StoriesController() : super(const AsyncValue.loading()) {
    loadStories();
  }
  final _supabase = Supabase.instance.client;
  int? _resolvedUserId;

  // Helper to get current user ID
  int get currentUserId {
    if (_resolvedUserId != null) return _resolvedUserId!;
    final user = _supabase.auth.currentUser;
    // Try metadata, fallback to 6 (guest/test)
    return user?.userMetadata?['user_id'] ?? 6;
  }

  /// Ensure we have the correct Integer UserID from the database
  /// matching the authenticated user's email/UUID.
  Future<int> _fetchRealUserId() async {
    if (_resolvedUserId != null) return _resolvedUserId!;

    final user = _supabase.auth.currentUser;
    if (user == null) return 6;

    // 1. Try Metadata
    if (user.userMetadata?['user_id'] != null) {
      _resolvedUserId = user.userMetadata!['user_id'];
      return _resolvedUserId!;
    }

    // 2. Try Database Lookup (by email)
    // This handles cases where metadata is missing but the user exists in 'users' table.
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      try {
        final res = await _supabase
            .from('users')
            .select('user_id')
            .eq('email', email)
            .maybeSingle();

        if (res != null) {
          _resolvedUserId = res['user_id'] as int;
          return _resolvedUserId!;
        }
      } catch (e) {
        debugPrint("Error resolving user ID: $e");
      }
    }

    // 3. Fallback
    return 6;
  }

  Future<void> loadStories() async {
    try {
      // Resolve ID first
      await _fetchRealUserId();

      final data = await _loadStories();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @override
  Future<StoriesState> build() async {
    return await _loadStories();
  }

  Future<void> markStoryAsSeen(int storyId) async {
    // 1. Optimistically update state
    state.whenData((currentState) {
      final myStory = currentState.myStory;
      final friends = currentState.friendsStories;

      // Helper to update a single UserStories
      UserStories updateStoryList(UserStories us) {
        final newStories = us.stories.map((s) {
          if (s.id == storyId) {
            final newSeen = Set<int>.from(s.seenBy)..add(currentUserId);
            return s.copyWith(seenBy: newSeen);
          }
          return s;
        }).toList();
        return UserStories(user: us.user, stories: newStories);
      }

      // Check my story
      var newMyStory = myStory;
      if (myStory != null) {
        newMyStory = updateStoryList(myStory);
      }

      // Check friends stories
      final newFriends = friends.map(updateStoryList).toList();

      state = AsyncValue.data(
        StoriesState(myStory: newMyStory, friendsStories: newFriends),
      );
    });

    // 2. Persist to DB
    try {
      await _supabase.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': currentUserId,
      });
    } catch (_) {
      // If DB fails, we might want to revert, but for "seen" status it's low risk
    }
  }

  Future<void> deleteStory(int storyId) async {
    await _supabase.from('stories').delete().eq('id', storyId);
    state = AsyncValue.data(await _loadStories());
  }

  Future<StoriesState> _loadStories() async {
    final now = DateTime.now();
    final twentyFourHoursAgoIso = now
        .subtract(const Duration(hours: 24))
        .toIso8601String();

    // 1. Fetch friendships
    List<Friendship> friendships = [];
    try {
      final data = await _supabase
          .from('friendships')
          .select()
          .or('user_id.eq.$currentUserId,friend_id.eq.$currentUserId')
          .eq('status', 'accepted');

      friendships = (data as List)
          .map((e) => Friendship.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    // 2. Friend IDs
    final friendIds = <int>{currentUserId};
    for (final f in friendships) {
      if (f.userId == currentUserId) {
        friendIds.add(f.friendId);
      } else if (f.friendId == currentUserId) {
        friendIds.add(f.userId);
      }
    }

    // 3. Fetch stories
    final data = await _supabase
        .from('stories')
        .select('''
          id, story_image, created_at, user_id,
          users (user_id, name, profile_image),
          story_views(viewer_id)
        ''')
        .inFilter('user_id', friendIds.toList())
        .gt('created_at', twentyFourHoursAgoIso)
        .order('created_at');

    final Map<int, UserStories> grouped = {};

    for (final item in data) {
      final uid = item['user_id'];
      // Skip if user_id is null or user data is missing (referential integrity check)
      if (uid == null || item['users'] == null) continue;

      grouped.putIfAbsent(
        uid,
        () => UserStories(user: UserModel.fromMap(item['users']), stories: []),
      );

      // Helper to safely parse date
      DateTime parseDate(dynamic dateStr) {
        if (dateStr == null) return DateTime.now();
        try {
          return DateTime.parse(dateStr.toString());
        } catch (_) {
          return DateTime.now();
        }
      }

      grouped[uid]!.stories.add(
        Story(
          id: item['id'],
          userId: uid,
          mediaUrl: item['story_image'] ?? '',
          createdAt: parseDate(item['created_at']),
          expiresAt: parseDate(
            item['created_at'],
          ).add(const Duration(hours: 24)),
          seenBy: (item['story_views'] as List)
              .map((v) => v['viewer_id'])
              .cast<int>()
              .toSet(),
        ),
      );
    }

    final allStories = grouped.values.toList();

    UserStories? myStory;
    // Check if my stories are already loaded
    try {
      myStory = allStories.firstWhere((s) => s.user.userId == currentUserId);
    } catch (_) {
      // If not, fetch my profile so I can show the avatar
      try {
        final userData = await _supabase
            .from('users')
            .select()
            .eq('user_id', currentUserId)
            .single();

        myStory = UserStories(user: UserModel.fromMap(userData), stories: []);
      } catch (e) {
        // Absolute fallback
        myStory = UserStories(
          user: UserModel(
            userId: currentUserId,
            name: 'Me',
            email: '',
            role: 'Student',
            createdAt: DateTime.now(),
            profileImage: '',
          ),
          stories: [],
        );
      }
    }

    final friends =
        allStories.where((s) => s.user.userId != currentUserId).toList()
          ..sort((a, b) {
            final aUnseen = a.hasUnseen(currentUserId);
            final bUnseen = b.hasUnseen(currentUserId);
            return aUnseen == bUnseen ? 0 : (aUnseen ? -1 : 1);
          });

    return StoriesState(myStory: myStory, friendsStories: friends);
  }

  // =======================
  // Public Actions
  // =======================
  Future<void> refreshStories() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _loadStories());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addStory(File file) async {
    try {
      state = const AsyncValue.loading();

      // Ensure we have the correct ID before uploading
      final uid = await _fetchRealUserId();

      final ext = file.path.split('.').last;
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload
      await _supabase.storage.from('story-media').upload(fileName, file);

      // Get URL
      final mediaUrl = _supabase.storage
          .from('story-media')
          .getPublicUrl(fileName);

      // Insert DB
      await _supabase.from('stories').insert({
        'user_id': uid,
        'story_image': mediaUrl,
      });

      // Reload stories
      state = AsyncValue.data(await _loadStories());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// =======================
// Provider
// =======================
final storiesProvider =
    StateNotifierProvider.autoDispose<
      StoriesController,
      AsyncValue<StoriesState>
    >((ref) => StoriesController());
