import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManagePostsByCategoryPage extends StatefulWidget {
  const ManagePostsByCategoryPage({super.key});

  @override
  State<ManagePostsByCategoryPage> createState() => _ManagePostsByCategoryPageState();
}

class _ManagePostsByCategoryPageState extends State<ManagePostsByCategoryPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _categories = [];
  Map<int, List<Map<String, dynamic>>> _postsByCategory = {};
  Map<int, bool> _loadingByCategory = {};
  bool _isLoadingCategories = true;
  String? _errorMessage;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('category_id, name')
          .order('name');

      final allCategories = List<Map<String, dynamic>>.from(response);
      final filteredCategories = allCategories
          .where((cat) => cat['name']?.toString().toLowerCase() != 'events')
          .toList();

      if (filteredCategories.isEmpty) {
        setState(() {
          _categories = [];
          _isLoadingCategories = false;
          _errorMessage = 'No categories found';
        });
        return;
      }

      setState(() {
        _categories = filteredCategories;
        _tabController = TabController(length: _categories.length, vsync: this);
        _isLoadingCategories = false;
      });

      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          final categoryId = _categories[_tabController!.index]['category_id'];
          if (!_postsByCategory.containsKey(categoryId)) {
            _loadPostsForCategory(categoryId);
          }
        }
      });

      _loadPostsForCategory(_categories.first['category_id']);
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');
      setState(() {
        _errorMessage = 'Failed to load categories: $e';
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadPostsForCategory(int categoryId) async {
    setState(() {
      _loadingByCategory[categoryId] = true;
    });

    try {
      debugPrint('📥 Loading posts for category ID: $categoryId');

      final postsResponse = await Supabase.instance.client
          .from('posts')
          .select('''
            post_id,
            content,
            media_url,
            file_url,
            created_at,
            updated_at,
            author_id,
            users!author_id (
              user_id,
              name,
              email,
              profile_image,
              role
            )
          ''')
          .eq('category_id', categoryId)
          .order('created_at', ascending: false);

      debugPrint('✅ Found ${(postsResponse as List).length} posts');

      List<Map<String, dynamic>> processedPosts = [];

      for (var post in postsResponse) {
        final userData = post['users'];
        
        final String userName = userData?['name'] ?? 'Unknown User';
        final String? userEmail = userData?['email'];
        final String? userImage = userData?['profile_image'];
        final String? userRole = userData?['role'];

        processedPosts.add({
          'post_id': post['post_id'],
          'content': post['content'],
          'media_url': post['media_url'],
          'file_url': post['file_url'],
          'created_at': post['created_at'],
          'updated_at': post['updated_at'],
          'author_id': post['author_id'],
          'user_name': userName,
          'user_email': userEmail,
          'user_image': userImage,
          'user_role': userRole,
        });

        debugPrint('  ✅ Post by: $userName ($userEmail)');
      }

      setState(() {
        _postsByCategory[categoryId] = processedPosts;
        _loadingByCategory[categoryId] = false;
      });

      debugPrint('✅ Loaded ${processedPosts.length} posts');
    } catch (e) {
      debugPrint('❌ Error loading posts: $e');
      setState(() {
        _loadingByCategory[categoryId] = false;
      });
    }
  }

  Future<void> _deletePost(int postId, int categoryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Post'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('posts')
            .delete()
            .eq('post_id', postId);

        setState(() {
          _postsByCategory[categoryId]?.removeWhere((p) => p['post_id'] == postId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Post deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error: $e')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Future<void> _showPostDialog([Map<String, dynamic>? post]) async {
    if (_categories.isEmpty || _tabController == null) return;

    final currentCategory = _categories[_tabController!.index];
    final isEditing = post != null;
    final contentController = TextEditingController(text: post?['content'] ?? '');
    final mediaUrlController = TextEditingController(text: post?['media_url'] ?? '');
    final fileUrlController = TextEditingController(text: post?['file_url'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isEditing ? Icons.edit : Icons.add,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(isEditing ? 'Edit Post' : 'New Post'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(currentCategory['name']),
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Category: ${currentCategory['name']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Content *',
                    hintText: 'Write your post content...',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: mediaUrlController,
                  decoration: InputDecoration(
                    labelText: 'Media URL (optional)',
                    hintText: 'https://example.com/image.jpg',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.image),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: fileUrlController,
                  decoration: InputDecoration(
                    labelText: 'File URL (optional)',
                    hintText: 'https://example.com/document.pdf',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_file),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (contentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Please enter post content'),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                return;
              }

              try {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) {
                  throw Exception('No user logged in');
                }

                final userResponse = await Supabase.instance.client
                    .from('users')
                    .select('user_id')
                    .eq('email', user.email!)
                    .maybeSingle();

                if (userResponse == null) {
                  throw Exception('User not found in database');
                }

                final userId = userResponse['user_id'] as int;

                final postData = {
                  'content': contentController.text.trim(),
                  'media_url': mediaUrlController.text.trim().isEmpty 
                      ? null 
                      : mediaUrlController.text.trim(),
                  'file_url': fileUrlController.text.trim().isEmpty 
                      ? null 
                      : fileUrlController.text.trim(),
                  'category_id': currentCategory['category_id'],
                  'author_id': userId,
                };

                if (isEditing) {
                  await Supabase.instance.client
                      .from('posts')
                      .update(postData)
                      .eq('post_id', post['post_id']);
                } else {
                  await Supabase.instance.client
                      .from('posts')
                      .insert(postData);
                }

                Navigator.pop(ctx);
                _loadPostsForCategory(currentCategory['category_id']);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            isEditing
                                ? 'Post updated successfully'
                                : 'Post created successfully',
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Error: $e')),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: Icon(isEditing ? Icons.save : Icons.add, size: 18),
            label: Text(
              isEditing ? 'Update' : 'Create',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Manage Posts by Category'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_categories.isNotEmpty && _tabController != null) {
                final categoryId = _categories[_tabController!.index]['category_id'];
                _loadPostsForCategory(categoryId);
              }
            },
          ),
        ],
        bottom: _isLoadingCategories || _tabController == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.zero,
                    indicatorPadding: EdgeInsets.zero,
                    tabs: _categories.map((category) {
                      return Tab(
                        icon: Icon(_getCategoryIcon(category['name']), size: 20),
                        text: category['name'],
                      );
                    }).toList(),
                  ),
                ),
              ),
      ),
      floatingActionButton: !_isLoadingCategories && _categories.isNotEmpty && _tabController != null
          ? FloatingActionButton.extended(
              onPressed: () => _showPostDialog(),
              backgroundColor: Colors.red,
              icon: const Icon(Icons.add),
              label: const Text('New Post'),
            )
          : null,
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadCategories,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _tabController == null
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: _categories.map((category) {
                        final categoryId = category['category_id'];
                        final posts = _postsByCategory[categoryId] ?? [];
                        final isLoading = _loadingByCategory[categoryId] ?? false;

                        return _buildCategoryContent(category, posts, isLoading);
                      }).toList(),
                    ),
    );
  }

  Widget _buildCategoryContent(
    Map<String, dynamic> category,
    List<Map<String, dynamic>> posts,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.post_add,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No posts in ${category['name']}',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first post',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPostsForCategory(category['category_id']),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return _buildPostCard(posts[index], category['category_id']);
        },
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int categoryId) {
    final userName = post['user_name'] as String;
    final userEmail = post['user_email'] as String?;
    final userImage = post['user_image'] as String?;
    final userRole = post['user_role'] as String?;
    final content = post['content'] as String? ?? '';
    final mediaUrl = post['media_url'] as String?;
    final fileUrl = post['file_url'] as String?;
    final postId = post['post_id'] as int;
    final createdAt = post['created_at'] != null
        ? DateTime.parse(post['created_at'])
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.red[100],
              backgroundImage: userImage != null && userImage.isNotEmpty
                  ? NetworkImage(userImage)
                  : null,
              child: userImage == null || userImage.isEmpty
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    )
                  : null,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (userRole != null && userRole.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      userRole,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userEmail != null && userEmail.isNotEmpty)
                  Text(
                    userEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (createdAt != null)
                  Text(
                    _timeAgo(createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
              onSelected: (value) {
                if (value == 'edit') {
                  _showPostDialog(post);
                } else if (value == 'delete') {
                  _deletePost(postId, categoryId);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue, size: 18),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                content,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),

          if (mediaUrl != null && mediaUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  mediaUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          if (fileUrl != null && fileUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fileUrl,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'internships':
        return Icons.work_outline;
      case 'competitions':
        return Icons.emoji_events_outlined;
      case 'courses':
        return Icons.school_outlined;
      case 'news':
        return Icons.article_outlined;
      case 'events':
        return Icons.calendar_today_outlined;
      case 'jobs':
        return Icons.business_center_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}