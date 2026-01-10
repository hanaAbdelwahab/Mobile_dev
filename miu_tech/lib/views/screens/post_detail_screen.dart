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

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final int? currentUserId; // Made optional

  const PostDetailScreen({super.key, required this.postId, this.currentUserId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // Current User ID (fetched or passed)
  int _currentUserId = 0;

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
  Map<int?, List<CommentModel>> _childrenMap =
      {}; // parent_comment_id -> children

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.currentUserId != null) {
      _currentUserId = widget.currentUserId!;
    } else {
      // Fetch current user ID from Supabase Auth
      final user = supabase.auth.currentUser;
      if (user != null && user.email != null) {
        try {
          final userData = await supabase
              .from('users')
              .select('user_id')
              .eq('email', user.email!)
              .maybeSingle();
          if (userData != null) {
            _currentUserId = userData['user_id'] as int;
          }
        } catch (e) {
          debugPrint('Error fetching current user ID: $e');
        }
      }
    }
    await _loadAll();
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
        _post = PostModel.fromMap(postData);
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
      for (final c in _allComments) {
        userIds.add(c.userId);
      }

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
          if (uid == _currentUserId) _likedCommentsByMe.add(cid);
        }
      }

      // Load post likes and reposts using providers
      if (mounted) {
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        final repostProvider = Provider.of<RepostProvider>(
          context,
          listen: false,
        );

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
        _commentLikeCounts[commentId] =
            (_commentLikeCounts[commentId] ?? 1) - 1;
      } else {
        _likedCommentsByMe.add(commentId);
        _commentLikeCounts[commentId] =
            (_commentLikeCounts[commentId] ?? 0) + 1;
      }
    });

    try {
      if (currentlyLiked) {
        await supabase.from('comment_likes').delete().match({
          'comment_id': commentId,
          'user_id': _currentUserId,
        });
      } else {
        await supabase.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': _currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // rollback on error
      setState(() {
        if (currentlyLiked) {
          _likedCommentsByMe.add(commentId);
          _commentLikeCounts[commentId] =
              (_commentLikeCounts[commentId] ?? 0) + 1;
        } else {
          _likedCommentsByMe.remove(commentId);
          _commentLikeCounts[commentId] =
              (_commentLikeCounts[commentId] ?? 1) - 1;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update like')));
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
        'user_id': _currentUserId,
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
        'parent_comment_id': null,
      });

      _newCommentController.clear();
      await _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to post comment')));
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
        'user_id': _currentUserId,
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
        'parent_comment_id': parentCommentId,
      });

      controller?.clear();
      setState(() {
        _replyControllers.remove(parentCommentId)?.dispose();
      });

      await _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to post reply')));
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: indent == 0
                        ? Colors.grey.shade100
                        : Colors.grey.shade50,
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
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
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
                                horizontal: 8,
                                vertical: 4,
                              ),
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
                                  color: liked
                                      ? Colors.red
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Like",
                                  style: TextStyle(
                                    color: liked
                                        ? Colors.red
                                        : Colors.grey.shade600,
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
                                Icon(
                                  Icons.reply,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Reply",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
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
        title: Text(
          "Post Details",
          style: const TextStyle(fontWeight: FontWeight.bold),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                      ),
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
  Widget _buildPostCard(PostModel p) {
    final authorName = _usernameFor(p.authorId);
    final avatar = _avatarFor(p.authorId);
    final commentCount = _allComments.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              CircleAvatar(
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null ? const Icon(Icons.person) : null,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _timeAgo(p.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // optional top-right actions (save/bookmark)
              Consumer<SavedPostProvider>(
                builder: (context, savedProvider, _) {
                  final isSaved = savedProvider.isSaved(p.postId);

                  return IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border_rounded,
                      color: isSaved ? Colors.red : Colors.grey,
                      size: 22,
                    ),
                    onPressed: () async {
                      await savedProvider.toggleSave(
                        userId: _currentUserId,
                        postId: p.postId,
                      );
                    },
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(p.content),

          const SizedBox(height: 10),

          FutureBuilder<List<TagModel>>(
            future: supabase
                .from('tags')
                .select('tag_id, tag_name, post_id')
                .eq('post_id', widget.postId)
                .then(
                  (data) =>
                      (data as List).map((t) => TagModel.fromMap(t)).toList(),
                ),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.isEmpty) {
                return const SizedBox();
              }

              return Wrap(
                spacing: 6,
                children: snap.data!.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "#${tag.tagName}",
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          if (p.mediaUrl != null && p.mediaUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  p.mediaUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          const SizedBox(height: 14),

          // ACTION BAR (uses PostProvider for post-like and RepostProvider for reposts)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // LIKE (uses provider)
              Consumer<PostProvider>(
                builder: (context, provider, _) {
                  final likeCount = provider.postLikeCounts[p.postId] ?? 0;
                  final liked = provider.likedByMe.contains(p.postId);

                  return GestureDetector(
                    onTap: () => provider.togglePostLike(p.postId),
                    child: Row(
                      children: [
                        Icon(
                          liked
                              ? Icons.thumb_up_alt
                              : Icons.thumb_up_alt_outlined,
                          size: 20,
                          color: liked ? Colors.red : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$likeCount',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: liked ? Colors.red : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Like',
                          style: TextStyle(
                            color: liked ? Colors.red : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // COMMENT (scrolls / no-op here)
              GestureDetector(
                onTap: () {
                  // optionally scroll to comments list or focus input
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 20,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$commentCount',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Comment',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              // REPOST (uses RepostProvider)
              Consumer<RepostProvider>(
                builder: (context, repostProvider, _) {
                  final isReposted = repostProvider.isReposted(p.postId);
                  final count = repostProvider.getRepostCount(p.postId);
                  final color = isReposted ? Colors.red : Colors.grey.shade700;

                  return GestureDetector(
                    onTap: () async {
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
                    child: Row(
                      children: [
                        Icon(Icons.repeat, size: 20, color: color),
                        const SizedBox(width: 8),
                        Text(
                          "$count",
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Repost",
                          style: TextStyle(
                            color: isReposted
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================
  // HELPER LOOKUPS
  // ================================================
  String _usernameFor(int userId) => _userNames[userId] ?? 'User';
  String? _avatarFor(int userId) => _userAvatars[userId];
}