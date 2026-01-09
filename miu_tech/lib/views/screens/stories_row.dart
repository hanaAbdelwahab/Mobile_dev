import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../controllers/stories_controller.dart';
import '../../models/user_stories.dart';
import '../../models/story.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/create_story_screen.dart';

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

    return storiesAsync.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          SizedBox(height: 120, child: Center(child: Text('Error: $e'))),
      data: (state) {
        final currentUserId = ref.read(storiesProvider.notifier).currentUserId;
        final myStory = state.myStory;
        final friends = state.friendsStories;

        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length + 1,
            itemBuilder: (context, index) {
              // ================= YOUR STORY =================
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      if (myStory == null || myStory.stories.isEmpty) {
                        _navToCreate(context);
                      } else {
                        _navToView(context, [myStory], 0);
                      }
                    },
                    child: _StoryAdd(
                      avatarUrl: myStory?.user.profileImage,
                      hasStory: myStory?.stories.isNotEmpty ?? false,
                      onAddTap: () => _navToCreate(context),
                    ),
                  ),
                );
              }

              // ================= FRIENDS STORIES =================
              final friendStory = friends[index - 1];
              final hasUnseen = friendStory.hasUnseen(currentUserId);
              // Safe fallback for potentially empty lists if data is malformed
              String previewImageUrl = '';
              bool isVideo = false;

              if (friendStory.stories.isNotEmpty) {
                final firstStory = friendStory.stories.first;
                previewImageUrl = firstStory.mediaUrl;
                isVideo = firstStory.mediaType == MediaType.video;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _navToView(context, friends, index - 1),
                  child: _StoryCard(
                    name: friendStory.user.name,
                    imageUrl: previewImageUrl,
                    isVideo: isVideo,
                    avatarUrl: friendStory.user.profileImage,
                    allSeen: !hasUnseen,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

//
// ========================= MY STORY WIDGET =========================
//
class _StoryAdd extends StatelessWidget {
  final String? avatarUrl;
  final bool hasStory;
  final VoidCallback onAddTap;

  const _StoryAdd({
    this.avatarUrl,
    required this.hasStory,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        children: [
          Stack(
            children: [
              if (hasStory)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFF44336), Color(0xFFFF9800)],
                    ),
                  ),
                  child: _avatar(),
                )
              else
                _avatar(),

              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text("My Story", style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _avatar() {
    return CircleAvatar(
      radius: 32,
      backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
          ? NetworkImage(avatarUrl!)
          : null,
      child: (avatarUrl == null || avatarUrl!.isEmpty)
          ? const Icon(Icons.person)
          : null,
    );
  }
}

//
// ========================= FRIEND STORY CARD =========================
//
class _StoryCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final bool isVideo;
  final String? avatarUrl;
  final bool allSeen;

  const _StoryCard({
    required this.name,
    required this.imageUrl,
    required this.isVideo,
    required this.avatarUrl,
    required this.allSeen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Rectangular Blurred Image Background
              Container(
                width: 110,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: allSeen
                        ? [Colors.grey.shade400, Colors.grey.shade500]
                        : [const Color(0xFFF44336), const Color(0xFFFF9800)],
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _buildPreview(),
                ),
              ),

              // 2. Avatar Overlay
              Positioned(
                bottom: -14,
                left: (110 / 2) - 29,
                child: CircleAvatar(
                  radius: 29,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage:
                        (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: (avatarUrl == null || avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (imageUrl.isEmpty) {
      return Container(color: Colors.grey.shade300);
    }

    if (isVideo) {
      // For videos, show a placeholder or just a solid color with an icon
      // Since it's blurred anyway, we don't need the actual video frame
      return Container(color: Colors.grey.shade300, child: const Center());
    }

    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        // Cache detailed resize
        cacheWidth: 200, // Small width since it's a thumbnail
        errorBuilder: (context, error, stackTrace) =>
            Container(color: Colors.grey.shade300),
      ),
    );
  }
}
