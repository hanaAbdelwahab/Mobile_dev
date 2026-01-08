import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';

class StoryHeader extends StatelessWidget {
  final UserModel user;
  final DateTime storyDate;
  final VoidCallback onClose;

  const StoryHeader({
    super.key,
    required this.user,
    required this.storyDate,
    required this.onClose,
  });

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      left: 10,
      right: 10,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'story_avatar_${user.userId}',
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.transparent,
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: user.profileImage ?? '',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,

                        // 🟢 FIX: Placeholder matches the Error Widget exactly
                        // Note: We use size: 18 to match the error widget below
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),

                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                        shadows: [Shadow(blurRadius: 3, color: Colors.black45)],
                      ),
                    ),
                    Text(
                      _timeAgo(storyDate),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                        shadows: [Shadow(blurRadius: 3, color: Colors.black45)],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.translucent,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromARGB(31, 255, 255, 255),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
