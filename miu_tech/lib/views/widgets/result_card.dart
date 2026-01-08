import 'package:flutter/material.dart';
import '../../models/search_result_model.dart';
import '../../models/post_model.dart';
import '../screens/user_profile_screen.dart';
import '../screens/post_detail_screen.dart';

class ResultCard extends StatelessWidget {
  final SearchResultModel result;

  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    switch (result.type) {
      case SearchResultType.user:
        // Assuming data is map for user
        final user = result.data as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12.0),
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: user['profile_image'] != null
                  ? NetworkImage(user['profile_image'])
                  : null,
              child: user['profile_image'] == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              user['name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(user['role'] ?? 'User'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: user['user_id']),
                ),
              );
            },
          ),
        );
      case SearchResultType.post:
        final post = result.data as PostModel;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getCategoryName(post.categoryId),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getCategoryName(int id) {
    switch (id) {
      case 11:
        return 'Internships';
      case 12:
        return 'Events';
      case 13:
        return 'Competitions';
      case 14:
        return 'Announcements';
      case 15:
        return 'Jobs';
      case 16:
        return 'Courses';
      case 17:
        return 'News';
      case 18:
        return 'Projects';
      default:
        return 'Post';
    }
  }
}
