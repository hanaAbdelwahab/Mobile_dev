import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CommentPage extends StatefulWidget {
  final String userName;
  final String postId;
  final List<String> initialComments;
  final void Function(String newComment) onCommentAdded;

  const CommentPage({
    super.key,
    required this.userName,
    required this.postId,
    required this.initialComments,
    required this.onCommentAdded,
  });

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  late List<Map<String, dynamic>> _comments;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool loading = true;
  
  final String mockCurrentUserId = "11111111-1111-1111-1111-111111111111";

  @override
  void initState() {
    super.initState();
    fetchComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> fetchComments() async {
    try {
      print('🔍 Fetching comments for post: ${widget.postId}');
      
      final response = await supabase
          .from('comments')
          .select('id, content, created_at, user_id, users(username)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false);

      print('📝 Comments fetched: ${(response as List).length}');

      setState(() {
        _comments = (response as List).map((comment) {
          return {
            'id': comment['id'],
            'content': comment['content'],
            'created_at': comment['created_at'],
            'user_id': comment['user_id'],
            'username': comment['users']['username'] ?? 'Unknown',
          };
        }).toList();
        loading = false;
      });
    } catch (e) {
      print('❌ Error fetching comments: $e');
      setState(() {
        _comments = [];
        loading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    String text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      print('💬 Adding comment to post: ${widget.postId}');
      
      await supabase.from('comments').insert({
        'post_id': widget.postId,
        'user_id': mockCurrentUserId,
        'content': text,
      });

      print('✅ Comment added successfully');

      _controller.clear();
      await fetchComments();
      widget.onCommentAdded(text);
      FocusScope.of(context).unfocus();

    } catch (e) {
      print('❌ Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding comment: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId, String commentUserId) async {
    if (commentUserId != mockCurrentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You can only delete your own comments'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    try {
      print('🗑️ Deleting comment: $commentId');
      
      await supabase
          .from('comments')
          .delete()
          .eq('id', commentId);

      print('✅ Comment deleted');
      await fetchComments();

    } catch (e) {
      print('❌ Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting comment: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        // Format as "Jan 15" without using intl package
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[dateTime.month - 1]} ${dateTime.day}';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildComment(Map<String, dynamic> commentData, int index) {
    final String comment = commentData['content'];
    final String username = commentData['username'];
    final String userId = commentData['user_id'];
    final String timestamp = commentData['created_at'] ?? '';
    final bool isMyComment = userId == mockCurrentUserId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with gradient
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isMyComment 
                    ? [Colors.red[700]!, Colors.red[500]!]
                    : [Colors.grey[600]!, Colors.grey[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isMyComment 
                      ? Colors.red.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                username.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          if (isMyComment) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(You)',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (timestamp.isNotEmpty)
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Comment content
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isMyComment ? Colors.red[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMyComment ? Colors.red[100]! : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    comment,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
                // Action buttons
                if (isMyComment) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _showDeleteDialog(commentData['id'], userId),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.red[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String commentId, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Comment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this comment? This action cannot be undone.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(commentId, userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[700]!, Colors.red[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.userName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          decoration: const InputDecoration(
                            hintText: "Add a comment...",
                            hintStyle: TextStyle(color: Colors.black45),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _sendComment,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red[700]!, Colors.red[600]!],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 50,
              color: Colors.red[300],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No comments yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Be the first to share your thoughts",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              "Comments",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (!loading) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!, width: 1),
                ),
                child: Text(
                  '${_comments.length}',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[200],
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.red[700],
                      strokeWidth: 3,
                    ),
                  )
                : _comments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _comments.length,
                        itemBuilder: (_, index) => _buildComment(_comments[index], index),
                      ),
          ),
          _commentInput(),
        ],
      ),
    );
  }
}