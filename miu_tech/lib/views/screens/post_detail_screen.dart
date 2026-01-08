import 'package:flutter/material.dart';
import '../../models/post_model.dart';

class PostDetailScreen extends StatelessWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Category ID: ${post.categoryId}'),
            const SizedBox(height: 8),
            Text(post.content),
            const SizedBox(height: 8),
            Text('Likes: ${post.likesCount}'),
            const SizedBox(height: 8),
            Text('Created: ${post.createdAt}'),
          ],
        ),
      ),
    );
  }
}
