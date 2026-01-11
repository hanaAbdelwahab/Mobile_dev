import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/post_model.dart';
import '../screens/post_detail_screen.dart';

class PostGridItem extends StatefulWidget {
  final PostModel post;

  const PostGridItem({super.key, required this.post});

  @override
  State<PostGridItem> createState() => _PostGridItemState();
}

class _PostGridItemState extends State<PostGridItem> {
  bool _isSaved = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  Future<void> _checkIfSaved() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('user_id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userResponse == null) return;

      final saved = await Supabase.instance.client
          .from('saved_freelance_projects')
          .select('saved_id')
          .eq('user_id', userResponse['user_id'])
          .eq('post_id', widget.post.postId)
          .maybeSingle();

      if (mounted) {
        setState(() => _isSaved = saved != null);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _toggleSave() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('user_id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userResponse == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = userResponse['user_id'] as int;

      if (_isSaved) {
        // Unsave
        await Supabase.instance.client
            .from('saved_freelance_projects')
            .delete()
            .eq('user_id', userId)
            .eq('post_id', widget.post.postId);
      } else {
        // Save
        await Supabase.instance.client
            .from('saved_freelance_projects')
            .insert({
          'user_id': userId,
          'post_id': widget.post.postId,
          'item_type': 'post',
        });
      }

      if (mounted) {
        setState(() {
          _isSaved = !_isSaved;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSaved ? '✅ Saved!' : '❌ Removed'),
            backgroundColor: _isSaved ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post)),
        );
      },
      child: Stack(
        children: [
          // Original grid item
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
              image: widget.post.mediaUrl != null
                  ? DecorationImage(
                      image: NetworkImage(widget.post.mediaUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.post.mediaUrl == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        widget.post.title,
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

          // ✅ BOOKMARK BUTTON - TOP RIGHT
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: Colors.white,
                        size: 20,
                      ),
                onPressed: _toggleSave,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
