import 'dart:io';
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

  const StoriesState({
    this.myStory,
    this.friendsStories = const [],
  });
}

// =======================
// Controller (Riverpod 3.x)
// =======================
class StoriesController extends StateNotifier<AsyncValue<StoriesState>> {
  StoriesController() : super(const AsyncValue.loading()) {
    loadStories();
  }
  final _supabase = Supabase.instance.client;

  // 🟢 TEMP USER ID
  int get currentUserId => 20;

  Future<void> loadStories() async {
    try {
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
  await _supabase.from('story_views').insert({
    'story_id': storyId,
    'viewer_id': currentUserId,
  });
}
Future<void> deleteStory(int storyId) async {
  await _supabase.from('stories').delete().eq('id', storyId);
  state = AsyncValue.data(await _loadStories());
}

  Future<StoriesState> _loadStories() async {
    final now = DateTime.now();
    final twentyFourHoursAgoIso =
        now.subtract(const Duration(hours: 24)).toIso8601String();

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
      friendIds.add(f.userId == currentUserId ? f.friendId : f.userId);
    }

    // 3. Fetch stories
    final data = await _supabase
        .from('stories')
        .select('''
          id, story_image, created_at, user_id,
          users (user_id, name, profile_image),
          story_views(viewer_id)
        ''')
        .filter('user_id', 'in', friendIds.toList())
        .gt('created_at', twentyFourHoursAgoIso)
        .order('created_at');

    final Map<int, UserStories> grouped = {};

    for (final item in data) {
      final uid = item['user_id'];

      grouped.putIfAbsent(
        uid,
        () => UserStories(
          user: UserModel.fromMap(item['users']),
          stories: [],
        ),
      );

      grouped[uid]!.stories.add(
        Story(
          id: item['id'],
          userId: uid,
          mediaUrl: item['story_image'],
          createdAt: DateTime.parse(item['created_at']),
          expiresAt:
              DateTime.parse(item['created_at']).add(const Duration(hours: 24)),
          seenBy: (item['story_views'] as List)
              .map((v) => v['viewer_id'])
              .cast<int>()
              .toSet(),
        ),
      );
    }

    final allStories = grouped.values.toList();

    final myStory = allStories.firstWhere(
      (s) => s.user.userId == currentUserId,
      orElse: () => UserStories(
  user: UserModel(
    userId: currentUserId,
    name: 'Me',
    email: '', // ✅ required
    role: 'Student', // ✅ required
    createdAt: DateTime.now(), // ✅ required
    profileImage: '',
  ),
  stories: [],
),
    );

    final friends = allStories
        .where((s) => s.user.userId != currentUserId)
        .toList()
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

      final ext = file.path.split('.').last;
      final fileName =
          '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload
      await _supabase.storage
          .from('story-media')
          .upload(fileName, file);

      // Get URL
      final mediaUrl =
          _supabase.storage.from('story-media').getPublicUrl(fileName);

      // Insert DB
      await _supabase.from('stories').insert({
        'user_id': currentUserId,
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
  >(
    (ref) => StoriesController(),
  );

