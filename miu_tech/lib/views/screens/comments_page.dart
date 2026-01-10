import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/repost_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/SavedPostProvider.dart';
import '../../models/comments_model.dart';
import '../../models/posts_model.dart';
import '../../models/tag_model.dart';

final supabase = Supabase.instance.client;

class CommentsPage extends StatefulWidget {
  final int postId;
  final int currentUserId;

  const CommentsPage({
    super.key,
    required this.postId,
    required this.currentUserId,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  // store usernames and avatars mapped by userId
  final Map<int, String> _userNames = {};
  final Map<int, String?> _userAvatars = {};

  // input controller for "new top-level comment"
  final TextEditingController _newCommentController = TextEditingController();

  // track reply controllers for open reply inputs keyed by commentId
  final Map<int, TextEditingController> _replyControllers = {};

  // cached data
  PostModel? _post;

  // comment likes state (comment-specific)
  final Map<int, int> _commentLikeCounts = {}; // commentId -> count
  final Set<int> _likedCommentsByMe = {}; // commentIds liked by current user

  // comments tree
  List<CommentModel> _allComments = []; // flat list
  Map<int?, List<CommentModel>> _childrenMap = {}; // parent_comment_id -> children

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _newCommentController.dispose();
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ================================================
  // LOAD POST + COMMENTS + USER DATA + LIKES
  // ================================================
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // Load post
      final postData = await supabase
          .from('posts')
          .select('*')
          .eq('post_id', widget.postId)
          .maybeSingle();

      if (postData != null) {
        _post = PostModel.fromMap(postData as Map<String, dynamic>);
      }

      // Load comments for the post (all)
      final commentData = await supabase
          .from('comments')
          .select()
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      _allComments = (commentData as List)
          .map((m) => CommentModel.fromMap(m as Map<String, dynamic>))
          .toList();

      // Build children map for reply tree
      _childrenMap = {};
      for (final c in _allComments) {
        final parent = c.parentCommentId;
        _childrenMap.putIfAbsent(parent, () => []);
        _childrenMap[parent]!.add(c);
      }

      // Prepare list of involved user IDs (post author + commenters)
      final userIds = <int>{};
      if (_post != null) userIds.add(_post!.authorId);
      for (final c in _allComments) userIds.add(c.userId);

      // Load user names and avatars in a single filter call if possible
      _userNames.clear();
      _userAvatars.clear();
      if (userIds.isNotEmpty) {
        final inClause = '(${userIds.join(",")})';
        final users = await supabase
            .from('users')
            .select('user_id, name, profile_image')
            .filter('user_id', 'in', inClause);

        for (final u in users as List) {
          final uid = u['user_id'] as int;
          _userNames[uid] = u['name'] ?? 'User';
          _userAvatars[uid] = u['profile_image'];
        }
      }

      // Load comment likes
      final commentIds = _allComments.map((c) => c.commentId).toList();
      _commentLikeCounts.clear();
      _likedCommentsByMe.clear();

      if (commentIds.isNotEmpty) {
        final inClause = '(${commentIds.join(",")})';
        final likes = await supabase
            .from('comment_likes')
            .select('comment_id, user_id')
            .filter('comment_id', 'in', inClause);

        for (final l in likes as List) {
          final cid = l['comment_id'] as int;
          final uid = l['user_id'] as int;

          _commentLikeCounts[cid] = (_commentLikeCounts[cid] ?? 0) + 1;
          if (uid == widget.currentUserId) _likedCommentsByMe.add(cid);
        }
      }

      // Load post likes and reposts using providers
      if (mounted) {
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        final repostProvider = Provider.of<RepostProvider>(context, listen: false);
        
        postProvider.loadPostLikes(widget.postId);
        repostProvider.loadRepostData(widget.postId);
      }
    } catch (e, st) {
      debugPrint('Error loading comments page: $e\n$st');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================================================
  // LIKE / UNLIKE COMMENT (optimistic)
  // ================================================
  Future<void> _toggleLikeComment(int commentId) async {
    final currentlyLiked = _likedCommentsByMe.contains(commentId);

    // Optimistic UI update
    setState(() {
      if (currentlyLiked) {
        _likedCommentsByMe.remove(commentId);
        _commentLikeCounts[commentId] = (_commentLikeCounts[commentId] ?? 1) - 1;
      } else {
        _likedCommentsByMe.add(commentId);
        _commentLikeCounts[commentId] = (_commentLikeCounts[commentId] ?? 0) + 1;
      }
    });

    try {
      if (currentlyLiked) {
        await supabase
            .from('comment_likes')
            .delete()
            .match({'comment_id': commentId, 'user_id': widget.currentUserId});
      } else {
        await supabase.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': widget.currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // rollback on error
      setState(() {
        if (currentlyLiked) {
          _likedCommentsByMe.add(commentId);
          _commentLikeCounts[commentId] = (_commentLikeCounts[commentId] ?? 0) + 1;
        } else {
          _likedCommentsByMe.remove(commentId);
          _commentLikeCounts[commentId] = (_commentLikeCounts[commentId] ?? 1) - 1;
        }
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to update like')));
    }
  }

  // ================================================
  // ADD TOP-LEVEL COMMENT
  // ================================================
  Future<void> _addTopLevelComment() async {
    final text = _newCommentController.text.trim();
    if (text.isEmpty) return;

    try {
      await supabase.from('comments').insert({
  'post_id': widget.postId,
  'user_id': widget.currentUserId,
  'content': text,
});


      _newCommentController.clear();
      await _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to post comment')));
    }
  }

  // ================================================
  // ADD REPLY TO A COMMENT
  // ================================================
  Future<void> _addReply(int parentCommentId) async {
    final controller = _replyControllers[parentCommentId];
    final text = controller?.text.trim() ?? '';

    if (text.isEmpty) return;

    try {
      await supabase.from('comments').insert({
        'post_id': widget.postId,
        'user_id': widget.currentUserId,
        'content': text,
        'parent_comment_id': parentCommentId, // ✅ ده المهم
      });



      controller?.clear();
      setState(() {
        _replyControllers.remove(parentCommentId)?.dispose();
      });

      await _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to post reply')));
    }
  }

  // ================================================
  // TIME FORMATTER
  // ================================================
  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  // ================================================
  // BUILD COMMENT RECURSIVELY WITH REPLIES
  // ================================================
  Widget _buildCommentWithReplies(CommentModel comment, {int indent = 0}) {
    final replies = _childrenMap[comment.commentId] ?? [];
    final likeCount = _commentLikeCounts[comment.commentId] ?? 0;
    final liked = _likedCommentsByMe.contains(comment.commentId);

    return Padding(
      padding: EdgeInsets.only(left: indent.toDouble()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COMMENT CARD
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: _avatarFor(comment.userId) != null
                    ? NetworkImage(_avatarFor(comment.userId)!)
                    : null,
                child: _avatarFor(comment.userId) == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: indent == 0 ? Colors.grey.shade100 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NAME + TIME
                      Row(
                        children: [
                          Text(
                            _usernameFor(comment.userId),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _timeAgo(comment.createdAt),
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      Text(comment.content),

                      const SizedBox(height: 8),

                      // ACTIONS
                      Row(
                        children: [
                          // Like count badge
                          if (likeCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$likeCount',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          if (likeCount > 0) const SizedBox(width: 10),

                          // Like button
                          GestureDetector(
                            onTap: () => _toggleLikeComment(comment.commentId),
                            child: Row(
                              children: [
                                Icon(
                                  liked
                                      ? Icons.thumb_up_alt
                                      : Icons.thumb_up_alt_outlined,
                                  size: 18,
                                  color: liked ? Colors.red : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Like",
                                  style: TextStyle(
                                    color:
                                        liked ? Colors.red : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 18),

                          // Reply button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _replyControllers.putIfAbsent(
                                  comment.commentId,
                                  () => TextEditingController(),
                                );
                              });
                            },
                            child: Row(
                              children: [
                                Icon(Icons.reply,
                                    size: 18, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text("Reply",
                                    style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // REPLY INPUT
          if (_replyControllers.containsKey(comment.commentId))
  Padding(
    padding: const EdgeInsets.only(left: 46),
    child: Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _replyControllers[comment.commentId],
              decoration: const InputDecoration(
                hintText: "Write a reply...",
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        // ✅ السهم اللي كنتِ بتدوري عليه
        IconButton(
          icon: const Icon(Icons.send, color: Colors.blue),
          onPressed: () {
            _addReply(comment.commentId);
          },
        ),
      ],
    ),
  ),

          // CHILD REPLIES
          for (final reply in replies) ...[
            const SizedBox(height: 8),
            _buildCommentWithReplies(reply, indent: indent + 24),
          ],
        ],
      ),
    );
  }

  // ================================================
  // PAGE BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F8FF),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Comments",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_post != null) _buildPostCard(_post!),
                        const SizedBox(height: 20),

                        const Text(
                          "Comments",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),

                        const SizedBox(height: 10),

                        if ((_childrenMap[null] ?? []).isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 30),
                              child: Text(
                                "No comments yet",
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        else
                          ...(_childrenMap[null]!).map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: _buildCommentWithReplies(c),
                            ),
                          ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // INPUT for new top-level comment
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
                            controller: _newCommentController,
                            decoration: const InputDecoration(
                              hintText: "Post a comment...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: _addTopLevelComment,
                      )
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ================================================
  // POST CARD (with action bar: like, comment, repost)
  // ================================================
 // ================================================
// POST CARD (Updated to match Profile Page UI)
// ================================================
Widget _buildPostCard(PostModel p) {
  final authorName = _usernameFor(p.authorId);
  final avatar = _avatarFor(p.authorId);
  final commentCount = _allComments.length;

  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // USER INFO HEADER
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? const Icon(Icons.person, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _timeAgo(p.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // SAVE/BOOKMARK BUTTON
              Consumer<SavedPostProvider>(
                builder: (context, savedProvider, _) {
                  final isSaved = savedProvider.isSaved(p.postId);
                  return IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? const Color(0xFFDC143C) : Colors.grey,
                      size: 24,
                    ),
                    onPressed: () async {
                      await savedProvider.toggleSave(
                        userId: widget.currentUserId,
                        postId: p.postId,
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // POST CONTENT
          Text(
            p.content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),

          // TAGS
          FutureBuilder<List<TagModel>>(
            future: supabase
                .from('tags')
                .select('tag_id, tag_name, post_id')
                .eq('post_id', widget.postId)
                .then((data) =>
                    (data as List).map((t) => TagModel.fromMap(t)).toList()),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.isEmpty) {
                return const SizedBox();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: snap.data!.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC143C).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "#${tag.tagName}",
                        style: const TextStyle(
                          color: Color(0xFFDC143C),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          // POST IMAGE
          if (p.mediaUrl != null && p.mediaUrl!.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                p.mediaUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[100],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey[300]),
          const SizedBox(height: 8),

          // INTERACTION STATS
          Consumer<PostProvider>(
            builder: (context, postProvider, _) {
              return Consumer<RepostProvider>(
                builder: (context, repostProvider, _) {
                  final likeCount = postProvider.postLikeCounts[p.postId] ?? 0;
                  final repostCount = repostProvider.getRepostCount(p.postId);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (likeCount > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Color(0xFFDC143C),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likeCount',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox(),
                      Text(
                        '$commentCount comment${commentCount != 1 ? 's' : ''} · $repostCount repost${repostCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[300]),

          // ACTION BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // LIKE BUTTON
              Consumer<PostProvider>(
                builder: (context, provider, _) {
                  final liked = provider.likedByMe.contains(p.postId);
                  return TextButton.icon(
                    onPressed: () => provider.togglePostLike(p.postId),
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? const Color(0xFFDC143C) : Colors.grey[700],
                      size: 20,
                    ),
                    label: Text(
                      'Like',
                      style: TextStyle(
                        color: liked ? const Color(0xFFDC143C) : Colors.grey[700],
                      ),
                    ),
                  );
                },
              ),

              // COMMENT BUTTON
              TextButton.icon(
                onPressed: () {
                  // Scroll to comments or focus input
                },
                icon: Icon(
                  Icons.comment_outlined,
                  color: Colors.grey[700],
                  size: 20,
                ),
                label: Text(
                  'Comment',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),

              // REPOST BUTTON
              Consumer<RepostProvider>(
                builder: (context, repostProvider, _) {
                  final isReposted = repostProvider.isReposted(p.postId);
                  return TextButton.icon(
                    onPressed: () async {
                      try {
                        await repostProvider.toggleRepost(p.postId);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to update repost'),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.repeat,
                      color: isReposted ? const Color(0xFFDC143C) : Colors.grey[700],
                      size: 20,
                    ),
                    label: Text(
                      'Repost',
                      style: TextStyle(
                        color: isReposted ? const Color(0xFFDC143C) : Colors.grey[700],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
} // ================================================
  // HELPER LOOKUPS
  // ================================================
  String _usernameFor(int userId) => _userNames[userId] ?? 'User';
  String? _avatarFor(int userId) => _userAvatars[userId];
}