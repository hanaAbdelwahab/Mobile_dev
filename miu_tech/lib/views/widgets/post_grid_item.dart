import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../views/screens/post_detail_screen.dart';

class PostGridItem extends StatelessWidget {
  final PostModel post;

  const PostGridItem({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PostDetailScreen(postId: int.tryParse(post.postId) ?? 0),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
          image: post.mediaUrl != null
              ? DecorationImage(
                  image: NetworkImage(post.mediaUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: post.mediaUrl == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    post.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}