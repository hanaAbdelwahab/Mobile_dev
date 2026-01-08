import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryAvatar extends StatelessWidget {
  final int userId;
  final String avatarUrl;
  final String username;
  final bool hasUnseenStories;
  final bool isYou;

  const StoryAvatar({
    super.key,
    required this.userId,
    required this.avatarUrl,
    required this.username,
    required this.hasUnseenStories,
    required this.isYou,
  });

  @override
  Widget build(BuildContext context) {
    final ringGradient = const LinearGradient(
      colors: [Colors.purple, Colors.orange],
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasUnseenStories ? ringGradient : null,
            border: !hasUnseenStories
                ? Border.all(width: 2.5, color: Colors.grey.shade400)
                : null,
          ),
          child: Hero(
            tag: 'story_avatar_$userId',
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.transparent,
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,

                  // 🟢 FIX: Placeholder matches the Error Widget exactly
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),

                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
