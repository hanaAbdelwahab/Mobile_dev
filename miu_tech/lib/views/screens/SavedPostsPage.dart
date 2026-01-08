import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/posts_model.dart';
import '../../models/tag_model.dart';
import '../../controllers/user_controller.dart';
import 'comments_page.dart';
import 'package:provider/provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/repost_provider.dart';
import '../../providers/SavedPostProvider.dart';
import '../widgets/top_navbar.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/user_drawer_header.dart';

final supabase = Supabase.instance.client;

class SavedPostsPage extends StatefulWidget {
  final int currentUserId;

  const SavedPostsPage({super.key, required this.currentUserId});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final Map<int, int> _commentCounts = {};
  late Future<List<PostModel>> _savedPostsFuture;

  @override
  void initState() {
    super.initState();
    _savedPostsFuture = _fetchSavedPosts();
  }

  Future<List<PostModel>> _fetchSavedPosts() async {
    try {
      // 1️⃣ Get saved post IDs for current user
      final savedData = await supabase
          .from('saved_posts')
          .select('post_id, saved_at')
          .eq('user_id', widget.currentUserId)
          .order('saved_at', ascending: false);

      if (savedData.isEmpty) {
        return [];
      }

      final postIds = (savedData as List)
          .map((s) => s['post_id'] as int)
          .toList();

      // 2️⃣ Fetch the actual posts
      final postsData = await supabase
          .from('posts')
          .select('*')
          .filter('post_id', 'in', '(${postIds.join(',')})');

      final posts = (postsData as List)
          .map((p) => PostModel.fromMap(p as Map<String, dynamic>))
          .toList();

      // 3️⃣ Sort by saved_at order
      final savedMap = Map.fromEntries(
        (savedData as List).map((s) => MapEntry(
              s['post_id'] as int,
              DateTime.parse(s['saved_at'] as String),
            )),
      );

      posts.sort((a, b) {
        final dateA = savedMap[a.postId] ?? DateTime.now();
        final dateB = savedMap[b.postId] ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      return posts;
    } catch (e) {
      debugPrint("❌ Error loading saved posts: $e");
      return [];
    }
  }

  Future<void> _loadLikesAndRepostsForPosts(List<PostModel> posts) async {
    try {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final repostProvider = Provider.of<RepostProvider>(context, listen: false);

      final postIds = posts.map((post) => post.postId).toList();

      for (final id in postIds) {
        postProvider.loadPostLikes(id);
      }

      if (postIds.isNotEmpty) {
        await repostProvider.loadRepostsForPosts(postIds);
      }
    } catch (e) {
      debugPrint('Error loading likes and reposts: $e');
    }
  }

  Future<void> _ensureCommentCount(int postId) async {
    if (_commentCounts.containsKey(postId)) return;

    try {
      final comments = await supabase.from('comments').select().eq('post_id', postId);
      final count = (comments as List).length;

      if (mounted) {
        setState(() {
          _commentCounts[postId] = count;
        });
      }
    } catch (e) {
      debugPrint("Error fetching comment count for post $postId: $e");
      if (mounted) {
        setState(() {
          _commentCounts.putIfAbsent(postId, () => 0);
        });
      }
    }
  }

  Future<List<TagModel>> _fetchTags(int postId) async {
    try {
      final data = await supabase
          .from('tags')
          .select('tag_id, tag_name, post_id')
          .eq('post_id', postId);

      final list = data as List<dynamic>;
      return list.map((t) => TagModel.fromMap(t as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("Error fetching tags for post $postId: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      endDrawer: UserDrawerContent(userId: widget.currentUserId),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: TopNavbar(userId: widget.currentUserId),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Text(
                  "Saved Posts",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Posts List
          Expanded(
            child: FutureBuilder<List<PostModel>>(
              future: _savedPostsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No saved posts yet",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Save posts to view them here",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final posts = snapshot.data!;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadLikesAndRepostsForPosts(posts);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _feedCard(posts[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavbar(
        currentIndex: -1,
        currentUserId: widget.currentUserId,
      ),
    );
  }

  Widget _feedCard(PostModel post) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserController.fetchUserData(post.authorId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data!;
        final userName = user["name"] ?? "User";
        final avatar = user["profile_image"];

        if (!_commentCounts.containsKey(post.postId)) {
          _ensureCommentCount(post.postId);
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeAgo(post.createdAt),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // SAVE ICON
                  Consumer<SavedPostProvider>(
                    builder: (context, savedProvider, _) {
                      final isSaved = savedProvider.isSaved(post.postId);

                      return IconButton(
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? Colors.red : Colors.grey,
                        ),
                        onPressed: () {
                          savedProvider.toggleSave(
                            userId: widget.currentUserId,
                            postId: post.postId,
                          );

                          // Refresh the list after unsaving
                          if (isSaved) {
                            setState(() {
                              _savedPostsFuture = _fetchSavedPosts();
                            });
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post.content,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<TagModel>>(
                future: _fetchTags(post.postId),
                builder: (context, tagSnapshot) {
                  if (!tagSnapshot.hasData || tagSnapshot.data!.isEmpty) {
                    return const SizedBox();
                  }

                  final tags = tagSnapshot.data!;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "#${tag.tagName}",
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.mediaUrl!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // LIKE
                  Consumer<PostProvider>(
                    builder: (context, provider, _) {
                      final likeCount = provider.postLikeCounts[post.postId] ?? 0;
                      final liked = provider.likedByMe.contains(post.postId);

                      return GestureDetector(
                        onTap: () => provider.togglePostLike(post.postId),
                        child: Row(
                          children: [
                            Icon(
                              liked
                                  ? Icons.thumb_up_alt
                                  : Icons.thumb_up_alt_outlined,
                              size: 20,
                              color: liked ? Colors.red : Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "$likeCount",
                              style: TextStyle(
                                color: liked ? Colors.red : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Like",
                              style: TextStyle(
                                color: liked ? Colors.red : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // COMMENT
                  _postAction(
                    Icons.comment_outlined,
                    "Comment",
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentsPage(
                            postId: post.postId,
                            currentUserId: widget.currentUserId,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) {
                          setState(() {
                            _commentCounts.remove(post.postId);
                          });
                          _ensureCommentCount(post.postId);

                          final postProvider =
                              Provider.of<PostProvider>(context, listen: false);
                          final repostProvider =
                              Provider.of<RepostProvider>(context, listen: false);

                          postProvider.loadPostLikes(post.postId);
                          repostProvider.loadRepostData(post.postId);
                        }
                      });
                    },
                    count: _commentCounts[post.postId] ?? 0,
                  ),

                  // REPOST
                  Consumer<RepostProvider>(
                    builder: (context, repostProvider, _) {
                      final isReposted = repostProvider.isReposted(post.postId);
                      final count = repostProvider.getRepostCount(post.postId);

                      return GestureDetector(
                        onTap: () async {
                          try {
                            await repostProvider.toggleRepost(post.postId);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to update repost'),
                                ),
                              );
                            }
                          }
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 20,
                              color: isReposted ? Colors.red : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "$count",
                              style: TextStyle(
                                color: isReposted ? Colors.red : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Repost",
                              style: TextStyle(
                                color: isReposted ? Colors.red : Colors.grey[600],
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
      },
    );
  }

  Widget _postAction(IconData icon, String label, VoidCallback onTap, {int? count}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 6),
          if (count != null) ...[
            Text(
              '$count',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return "${diff.inMinutes} minutes ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    if (diff.inDays < 7) return "${diff.inDays} days ago";

    final weeks = (diff.inDays / 7).floor();
    return "$weeks week${weeks > 1 ? 's' : ''} ago";
  }
}