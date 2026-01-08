import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/stories_controller.dart';
import '../../models/user_stories.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/create_story_screen.dart';
import '../widgets/story_avatar.dart';

class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key});

  void _navToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
    );
  }

  void _navToView(BuildContext context, List<UserStories> users, int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            StoryViewerScreen(users: users, initialUserIndex: index),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesProvider);
    final currentUserId = ref.read(storiesProvider.notifier).currentUserId;

    return storiesAsync.when(
      loading: () => const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 110,
        child: Center(child: Text('Error: $e')),
      ),
      data: (state) {
        final myStory = state.myStory;
        final friends = state.friendsStories;

        return SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // ================= YOUR STORY =================
              if (myStory != null)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (myStory.stories.isEmpty) {
                          _navToCreate(context);
                        } else {
                          _navToView(context, [myStory], 0);
                        }
                      },
                      child: StoryAvatar(
                        userId: myStory.user.userId,
                        avatarUrl: myStory.user.profileImage ?? '',
                        username: 'Your story',
                        hasUnseenStories: false,
                        isYou: true,
                      ),
                    ),

                    Positioned(
                      bottom: 26,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _navToCreate(context),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(width: 12),

              // ================= FRIENDS STORIES =================
              ...friends.map((friendStories) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _navToView(
                      context,
                      friends,
                      friends.indexOf(friendStories),
                    ),
                    child: StoryAvatar(
                      key: ValueKey(
                        '${friendStories.user.userId}_${friendStories.hasUnseen(currentUserId)}',
                      ),
                      userId: friendStories.user.userId,
                      avatarUrl: friendStories.user.profileImage ?? '',
                      username: friendStories.user.name,
                      hasUnseenStories:
                          friendStories.hasUnseen(currentUserId),
                      isYou: false,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
