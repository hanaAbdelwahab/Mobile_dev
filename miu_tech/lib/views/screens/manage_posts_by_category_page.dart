import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManagePostsByCategoryPage extends StatefulWidget {
  const ManagePostsByCategoryPage({super.key});

  @override
  State<ManagePostsByCategoryPage> createState() => _ManagePostsByCategoryPageState();
}

class _ManagePostsByCategoryPageState extends State<ManagePostsByCategoryPage> {
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _selectedCategory;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoadingCategories = true;
  bool _isLoadingPosts = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
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

      // ✅ Filter out "Events" category since it has its own page
      final allCategories = List<Map<String, dynamic>>.from(response);
      final filteredCategories = allCategories
          .where((cat) => cat['name']?.toString().toLowerCase() != 'events')
          .toList();

      setState(() {
        _categories = filteredCategories;
        _isLoadingCategories = false;
      });

      // Auto-select first category
      if (_categories.isNotEmpty) {
        _selectCategory(_categories.first);
      }
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');
      setState(() {
        _errorMessage = 'Failed to load categories: $e';
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _selectCategory(Map<String, dynamic> category) async {
    setState(() {
      _selectedCategory = category;
      _isLoadingPosts = true;
      _errorMessage = null;
    });

    try {
      debugPrint('📥 Loading posts for category: ${category['name']}');

      // ✅ USE JOIN to get user data directly from users table
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
          .eq('category_id', category['category_id'])
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
        _posts = processedPosts;
        _isLoadingPosts = false;
      });

      debugPrint('✅ Loaded ${_posts.length} posts for ${category['name']}');
    } catch (e) {
      debugPrint('❌ Error loading posts: $e');
      setState(() {
        _errorMessage = 'Failed to load posts: $e';
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _deletePost(String postId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
          _posts.removeAt(index);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Post deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showPostDialog([Map<String, dynamic>? post]) async {
    if (_selectedCategory == null) return;

    final isEditing = post != null;
    final contentController = TextEditingController(text: post?['content'] ?? '');
    final mediaUrlController = TextEditingController(text: post?['media_url'] ?? '');
    final fileUrlController = TextEditingController(text: post?['file_url'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEditing ? 'Edit Post' : 'New Post'),
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
                        _getCategoryIcon(_selectedCategory!['name']),
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Category: ${_selectedCategory!['name']}',
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
                  decoration: const InputDecoration(
                    labelText: 'Content *',
                    hintText: 'Write your post content...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: mediaUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Media URL (optional)',
                    hintText: 'https://example.com/image.jpg',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: fileUrlController,
                  decoration: const InputDecoration(
                    labelText: 'File URL (optional)',
                    hintText: 'https://example.com/document.pdf',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_file),
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
          ElevatedButton(
            onPressed: () async {
              if (contentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter post content'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) {
                  throw Exception('No user logged in');
                }

                // ✅ Get real user_id from users table
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
                  'category_id': _selectedCategory!['category_id'],
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
                _selectCategory(_selectedCategory!);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? '✅ Post updated successfully'
                            : '✅ Post created successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
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
              if (_selectedCategory != null) {
                _selectCategory(_selectedCategory!);
              }
            },
          ),
        ],
      ),
      floatingActionButton: _selectedCategory != null
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Error',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
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
                )
              : Row(
                  children: [
                    // Left: Category List
                    Container(
                      width: 250,
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                            child: const Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final isSelected = _selectedCategory?['category_id'] ==
                                    category['category_id'];

                                return InkWell(
                                  onTap: () => _selectCategory(category),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.white,
                                      border: Border(
                                        left: BorderSide(
                                          color: isSelected
                                              ? Colors.red
                                              : Colors.transparent,
                                          width: 4,
                                        ),
                                        bottom: BorderSide(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getCategoryIcon(category['name']),
                                          color: isSelected
                                              ? Colors.red
                                              : Colors.grey[600],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            category['name'],
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? Colors.red
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right: Posts List
                    Expanded(
                      child: _selectedCategory == null
                          ? Center(
                              child: Text(
                                'Select a category',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey[200]!),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getCategoryIcon(
                                          _selectedCategory!['name'],
                                        ),
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedCategory!['name'],
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${_posts.length} posts',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: _isLoadingPosts
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : _posts.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.post_add,
                                                    size: 80,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'No posts in this category',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : RefreshIndicator(
                                              onRefresh: () =>
                                                  _selectCategory(
                                                _selectedCategory!,
                                              ),
                                              child: ListView.builder(
                                                padding: const EdgeInsets.all(16),
                                                itemCount: _posts.length,
                                                itemBuilder: (context, index) {
                                                  final post = _posts[index];
                                                  return _buildPostCard(
                                                    post,
                                                    index,
                                                  );
                                                },
                                              ),
                                            ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final userName = post['user_name'] as String;
    final userEmail = post['user_email'] as String?;
    final userImage = post['user_image'] as String?;
    final userRole = post['user_role'] as String?;
    final content = post['content'] as String? ?? '';
    final mediaUrl = post['media_url'] as String?;
    final fileUrl = post['file_url'] as String?;
    final createdAt = post['created_at'] != null
        ? DateTime.parse(post['created_at'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.red[100],
                  backgroundImage:
                      userImage != null ? NetworkImage(userImage) : null,
                  child: userImage == null
                      ? Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (userEmail != null)
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (userRole != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            userRole,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                      if (createdAt != null)
                        Text(
                          _timeAgo(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showPostDialog(post);
                    } else if (value == 'delete') {
                      _deletePost(post['post_id'].toString(), index);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue, size: 20),
                          SizedBox(width: 12),
                          Text('Edit Post'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 12),
                          Text('Delete Post'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                content,
                style: const TextStyle(fontSize: 15),
              ),
            ),

          // Media
          if (mediaUrl != null && mediaUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 50),
                      ),
                    );
                  },
                ),
              ),
            ),

          // File attachment
          if (fileUrl != null && fileUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Attached File',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),
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
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}