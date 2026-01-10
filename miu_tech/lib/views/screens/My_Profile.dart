import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // For Gradient
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/top_navbar.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/user_drawer_header.dart';

// user_drawer_header.dart is already imported if you're using UserDrawerContent
// ==========================================
// MAIN PROFILE WIDGET
// ==========================================

class AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementCard({Key? key, required this.announcement})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DateTime eventDateTime = _parseDateTime(announcement);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date/Time Section
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDayLabel(eventDateTime),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(eventDateTime),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Content Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement['title'] ?? 'Announcement',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  announcement['description'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Notification Bell Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Color(0xFFDC2626),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _parseDateTime(Map<String, dynamic> announcement) {
    try {
      if (announcement['date'] != null && announcement['time'] != null) {
        final date = DateTime.parse(announcement['date']);
        final timeParts = announcement['time'].toString().split(':');
        return DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
      }
    } catch (e) {
      print('Error parsing announcement date/time: $e');
    }
    return DateTime.now();
  }

  String _formatDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);

    if (eventDay == today) {
      return 'TODAY';
    } else if (eventDay == today.add(const Duration(days: 1))) {
      return 'TOMORROW';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class MyProfile extends StatefulWidget {
  final int userId;

  const MyProfile({super.key, required this.userId});

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // User basic info
  String? fullName;
  String? role;
  String? imageUrl;
  String? coverImageUrl;
  String? department;
  String? bio; // Headline
  int? academicYear;
  int followers = 0;
  int connections = 0;
  bool isLoading = true;
  bool _showAllPosts = false;
  bool _showAllComments = false;
  bool _showAllReposts = false;
  String? userRole; // ADD THIS LINE

  // Profile sections data
  List<Map<String, dynamic>> experiences = [];
  List<Map<String, dynamic>> skills = [];
  List<Map<String, dynamic>> licenses = [];
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> userPosts = [];
  List<Map<String, dynamic>> userComments = [];
  List<Map<String, dynamic>> userReposts = [];

  // Tab controller for activity section
  late TabController _activityTabController;
  int _selectedActivityTab = 0;

  // Image pickers
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _activityTabController = TabController(length: 3, vsync: this);
    _activityTabController.addListener(() {
      if (_activityTabController.indexIsChanging) {
        setState(() {
          _selectedActivityTab = _activityTabController.index;
          // Reset "show all" states when switching tabs
          _showAllPosts = false;
          _showAllComments = false;
          _showAllReposts = false;
        });
      }
    });
    _loadCompleteProfileData();
  }

  @override
  void dispose() {
    _activityTabController.dispose();
    super.dispose();
  }

  // ============================================
  // LOAD ALL PROFILE DATA (ROBUST VERSION)
  // ============================================
  // Add this loading method

  Future<void> _openFile(String? url) async {
    if (url == null || url.isEmpty) {
      _showError("Invalid file link");
      return;
    }

    final Uri uri = Uri.parse(url);
    try {
      // Attempt to launch the URL in an external browser
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showError("Could not open the file");
      }
    } catch (e) {
      print("Error launching URL: $e");
      _showError("Error opening attachment");
    }
  }

  Future<void> _loadCompleteProfileData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    // We run these independently so one failure doesn't break the whole profile
    try {
      // 1. Load User Basics (Vital)
      try {
        await _loadBasicUserInfo();
      } catch (e) {
        print("Error loading basic info: $e");
      }

      // 2. Load Stats
      try {
        await _loadConnectionStats();
      } catch (e) {
        print("Error loading stats: $e");
      }

      // 3. Load Content (Parallel)
      await Future.wait([
        _loadExperiences().catchError((e) => print("Exp error: $e")),
        _loadLicenses().catchError((e) => print("License error: $e")),
        _loadProjects().catchError((e) => print("Project error: $e")),
        _loadSkills().catchError((e) => print("Skill error: $e")),
        _loadUserPosts().catchError((e) => print("Post error: $e")),
        _loadUserComments().catchError((e) => print("Comment error: $e")),
        _loadUserReposts().catchError((e) => print("Repost error: $e")),
      ]);
    } catch (e) {
      print("General loading error: $e");
      if (mounted) _showError("Some profile data failed to load");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadBasicUserInfo() async {
    final userData = await supabase
        .from('users')
        .select(
          'name, role, profile_image, cover_image, department, bio, academic_year',
        )
        .eq('user_id', widget.userId)
        .single();

    if (mounted) {
      setState(() {
        fullName = userData['name'];
        role = userData['role'];
        userRole = userData['role']; // ADD THIS LINE
        imageUrl = userData['profile_image'];
        coverImageUrl = userData['cover_image'];
        department = userData['department'];
        bio = userData['bio'];
        academicYear = userData['academic_year'];
      });
    }
  }

  Future<void> _loadConnectionStats() async {
    final friendships1 = await supabase
        .from('friendships')
        .select('friend_id')
        .eq('user_id', widget.userId)
        .eq('status', 'accepted');

    final friendships2 = await supabase
        .from('friendships')
        .select('user_id')
        .eq('friend_id', widget.userId)
        .eq('status', 'accepted');

    if (mounted) {
      setState(() {
        connections = friendships1.length + friendships2.length;
        followers = connections;
      });
    }
  }

  Widget _buildModalLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 16),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.grey[700],
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildModalTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE63946), width: 2),
        ),
      ),
    );
  }

  Widget _buildDateDisplay(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: const TextStyle(fontSize: 14)),
          const Icon(Icons.arrow_drop_down, color: Colors.grey),
        ],
      ),
    );
  }

  void _showPostActionMenu(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('Save post'),
            onTap: () {
              Navigator.pop(context);
              _showSuccess('Post saved successfully!');
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit post'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePostModal(
                    userId: widget.userId,
                    editPostData: post,
                  ),
                ),
              ).then((_) => _loadUserPosts());
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Delete post',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmDeletePost(post['post_id']);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmDeletePost(int postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _deletePost(postId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadExperiences() async {
    final data = await supabase
        .from('experiences')
        .select('*')
        .eq('user_id', widget.userId)
        .order('start_date', ascending: false);

    if (mounted)
      setState(() => experiences = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _loadLicenses() async {
    final data = await supabase
        .from('licenses')
        .select('*')
        .eq('user_id', widget.userId)
        .order('issue_date', ascending: false);

    if (mounted)
      setState(() => licenses = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _loadProjects() async {
    final data = await supabase
        .from('projects')
        .select('*')
        .eq('user_id', widget.userId)
        .order('start_date', ascending: false);

    if (mounted)
      setState(() => projects = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _loadSkills() async {
    final data = await supabase
        .from('skills')
        .select('*')
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false);

    if (mounted) setState(() => skills = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _loadUserPosts() async {
    try {
      List<Map<String, dynamic>> allUserPosts = [];

      // 1. Load regular posts from 'posts' table (ALL ROLES)
      final regularPosts = await supabase
          .from('posts')
          .select('*, created_at')
          .eq('author_id', widget.userId)
          .order('created_at', ascending: false);

      for (var post in regularPosts) {
        allUserPosts.add({
          ...post,
          'post_type': 'post',
          'original_table': 'posts',
        });
      }

      // 2. Load announcements from 'announcement' table
      // ONLY for non-Instructor/TA users
      if (userRole?.toLowerCase() != 'instructor' &&
          userRole?.toLowerCase() != 'ta') {
        final announcements = await supabase
            .from('announcement')
            .select('*, created_at')
            .eq('auth_id', widget.userId)
            .order('created_at', ascending: false);

        for (var announcement in announcements) {
          allUserPosts.add({
            'post_id': announcement['announcement_id'],
            'author_id': announcement['auth_id'],
            'title': announcement['title'],
            'content': announcement['description'],
            'category_id': announcement['category_id'],
            'created_at': announcement['created_at'],
            'media_url': null,
            'file_url': null,
            'post_type': 'announcement',
            'original_table': 'announcement',
            'announcement_date': announcement['date'],
            'announcement_time': announcement['time'],
          });
        }
      }

      // 3. Load competition requests from 'competition_requests' table
      // ONLY for non-Instructor/TA users
      if (userRole?.toLowerCase() != 'instructor' &&
          userRole?.toLowerCase() != 'ta') {
        final competitionRequests = await supabase
            .from('competition_requests')
            .select('*, created_at')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false);

        for (var request in competitionRequests) {
          allUserPosts.add({
            'post_id': request['competition_id'],
            'author_id': request['user_id'],
            'title': request['title'],
            'content': request['description'],
            'category_id': null,
            'created_at': request['created_at'],
            'media_url': null,
            'file_url': null,
            'post_type': 'competition_request',
            'original_table': 'competition_requests',
            'needed_skills': request['needed_skills'],
            'team_size': request['team_size'],
          });
        }
      }

      // 4. Sort all posts by created_at (most recent first)
      allUserPosts.sort((a, b) {
        final aDate = DateTime.parse(a['created_at']);
        final bDate = DateTime.parse(b['created_at']);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() => userPosts = allUserPosts);
        print(
          '✅ Loaded ${allUserPosts.length} posts for user ${widget.userId} (Role: $userRole)',
        );
        if (userRole?.toLowerCase() == 'instructor' ||
            userRole?.toLowerCase() == 'ta') {
          print('   ℹ️ Instructor/TA: Only showing regular posts');
        } else {
          print('   - ${regularPosts.length} regular posts');
          print(
            '   - ${allUserPosts.where((p) => p['post_type'] == 'announcement').length} announcements',
          );
          print(
            '   - ${allUserPosts.where((p) => p['post_type'] == 'competition_request').length} competition requests',
          );
        }
      }
    } catch (e) {
      print('❌ Error loading user posts: $e');
      if (mounted) setState(() => userPosts = []);
    }
  }

  Future<void> _loadUserComments() async {
    try {
      final data = await supabase
          .from('comments')
          .select('''
          *,
          posts!inner(post_id, title, content, author_id)
        ''')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted)
        setState(() => userComments = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('Error loading comments: $e');
      // Don't break the app if comments fail to load
      if (mounted) setState(() => userComments = []);
    }
  }

  Future<List<Map<String, dynamic>>> loadPostComments(int postId) async {
    final data = await supabase
        .from('comments')
        .select('''
        comment_id,
        content,
        created_at,
        user_id,
        users:user_id (
          name,
          profile_image
        )
      ''')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _loadUserReposts() async {
    try {
      final data = await supabase
          .from('reposts')
          .select('''
          *,
          posts!inner(post_id, title, content, author_id, created_at, media_url)
        ''')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted)
        setState(() => userReposts = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('Error loading reposts: $e');
      if (mounted) setState(() => userReposts = []);
    }
  }
  // ============================================
  // POST INTERACTION METHODS
  // ============================================

  Future<bool> _isPostLiked(int postId) async {
    final result = await supabase
        .from('likes')
        .select('like_id')
        .eq('user_id', widget.userId)
        .eq('post_id', postId);
    return result.isNotEmpty;
  }

  Future<int> _getPostLikeCount(int postId) async {
    final result = await supabase
        .from('likes')
        .select('like_id')
        .eq('post_id', postId);
    return result.length;
  }

  Future<int> _getPostCommentCount(int postId) async {
    final result = await supabase
        .from('comments')
        .select('comment_id')
        .eq('post_id', postId);
    return result.length;
  }

  Future<int> _getPostRepostCount(int postId) async {
    final result = await supabase
        .from('reposts')
        .select('id')
        .eq('post_id', postId);
    return result.length;
  }

  Future<bool> _isPostReposted(int postId) async {
    final result = await supabase
        .from('reposts')
        .select('id')
        .eq('user_id', widget.userId)
        .eq('post_id', postId);
    return result.isNotEmpty;
  }

  Future<void> _toggleLike(int postId) async {
    try {
      final isLiked = await _isPostLiked(postId);

      if (isLiked) {
        await supabase
            .from('likes')
            .delete()
            .eq('user_id', widget.userId)
            .eq('post_id', postId);
        _showSuccess('Post unliked');
      } else {
        final lastLike = await supabase
            .from('likes')
            .select('like_id')
            .order('like_id', ascending: false)
            .limit(1);

        int nextLikeId = 1;
        if (lastLike.isNotEmpty) {
          nextLikeId = (lastLike[0]['like_id'] as int) + 1;
        }

        await supabase.from('likes').insert({
          'user_id': widget.userId,
          'post_id': postId,
          'created_at': DateTime.now().toIso8601String(),
        });
        _showSuccess('Post liked');
      }
      setState(() {});
    } catch (e) {
      _showError('Failed to toggle like: $e');
    }
  }

  Future<void> _toggleRepost(int postId) async {
    try {
      final isReposted = await _isPostReposted(postId);

      if (isReposted) {
        await supabase
            .from('reposts')
            .delete()
            .eq('user_id', widget.userId)
            .eq('post_id', postId);
        _showSuccess('Repost removed');
      } else {
        final lastRepost = await supabase
            .from('reposts')
            .select('id')
            .order('id', ascending: false)
            .limit(1);

        int nextRepostId = 1;
        if (lastRepost.isNotEmpty) {
          nextRepostId = (lastRepost[0]['id'] as int) + 1;
        }

        await supabase.from('reposts').insert({
          'id': nextRepostId,
          'user_id': widget.userId,
          'post_id': postId,
          'created_at': DateTime.now().toIso8601String(),
        });
        _showSuccess('Post reposted');
      }
      // Refresh reposts list
      await _loadUserReposts();
      setState(() {});
    } catch (e) {
      _showError('Failed to toggle repost: $e');
    }
  }

  // ============================================
  // COMMENT INTERACTION METHODS
  // ============================================

  Future<bool> _isCommentLiked(int commentId) async {
    final result = await supabase
        .from('comment_likes')
        .select('comment_like_id')
        .eq('user_id', widget.userId)
        .eq('comment_id', commentId);
    return result.isNotEmpty;
  }

  Future<int> _getCommentLikeCount(int commentId) async {
    final result = await supabase
        .from('comment_likes')
        .select('comment_like_id')
        .eq('comment_id', commentId);
    return result.length;
  }

  Future<void> _toggleCommentLike(int commentId) async {
    try {
      final isLiked = await _isCommentLiked(commentId);

      if (isLiked) {
        await supabase
            .from('comment_likes')
            .delete()
            .eq('user_id', widget.userId)
            .eq('comment_id', commentId);
      } else {
        final lastLike = await supabase
            .from('comment_likes')
            .select('comment_like_id')
            .order('comment_like_id', ascending: false)
            .limit(1);

        int nextLikeId = 1;
        if (lastLike.isNotEmpty) {
          nextLikeId = (lastLike[0]['comment_like_id'] as int) + 1;
        }

        await supabase.from('comment_likes').insert({
          'comment_like_id': nextLikeId,
          'comment_id': commentId,
          'user_id': widget.userId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      setState(() {});
    } catch (e) {
      _showError('Failed to toggle like: $e');
    }
  }
  // ============================================
  // IMAGE UPLOAD METHODS
  // ============================================

  Future<void> _uploadProfilePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => isLoading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName =
          'profile_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'profile_images/$fileName';

      // Using upsert false to avoid overwriting accidentally, though timestamp prevents collision
      await supabase.storage
          .from('Posts')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: false,
            ),
          );

      final publicUrl = supabase.storage.from('Posts').getPublicUrl(filePath);

      await supabase
          .from('users')
          .update({'profile_image': publicUrl})
          .eq('user_id', widget.userId);

      await _loadBasicUserInfo();
      if (mounted) setState(() => isLoading = false);
      _showSuccess('Profile picture updated successfully!');
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _showError('Failed to upload profile picture: $e');
    }
  }

  Future<void> _uploadCoverPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => isLoading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName =
          'cover_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'cover_images/$fileName';

      await supabase.storage
          .from('Posts')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: false,
            ),
          );

      final publicUrl = supabase.storage.from('Posts').getPublicUrl(filePath);

      await supabase
          .from('users')
          .update({'cover_image': publicUrl})
          .eq('user_id', widget.userId);

      await _loadBasicUserInfo();
      if (mounted) setState(() => isLoading = false);
      _showSuccess('Cover photo updated successfully!');
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _showError('Failed to upload cover photo: $e');
    }
  }

  // ============================================
  // CRUD OPERATIONS (User Data)
  // ============================================

  // Only updates Name, not role/location/bio/about (handled separately)
  Future<void> _updateBasicInfoName(String name) async {
    try {
      await supabase
          .from('users')
          .update({'name': name})
          .eq('user_id', widget.userId);

      await _loadBasicUserInfo();
      _showSuccess('Name updated successfully!');
    } catch (e) {
      _showError('Failed to update name: $e');
    }
  }

  Future<void> _updateBio(String newBio) async {
    try {
      await supabase
          .from('users')
          .update({'bio': newBio})
          .eq('user_id', widget.userId);

      await _loadBasicUserInfo();
      _showSuccess('Bio updated successfully!');
    } catch (e) {
      _showError('Failed to update bio: $e');
    }
  }

  Future<void> _addExperience(Map<String, dynamic> experienceData) async {
    try {
      experienceData['user_id'] = widget.userId;
      await supabase.from('experiences').insert(experienceData);
      await _loadExperiences();
      _showSuccess('Experience added successfully!');
    } catch (e) {
      _showError('Failed to add experience: $e');
    }
  }

  Future<void> _updateExperience(
    int experienceId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await supabase
          .from('experiences')
          .update(updates)
          .eq('experience_id', experienceId);
      await _loadExperiences();
      _showSuccess('Experience updated successfully!');
    } catch (e) {
      _showError('Failed to update experience: $e');
    }
  }

  Future<void> _deleteExperience(int experienceId) async {
    try {
      await supabase
          .from('experiences')
          .delete()
          .eq('experience_id', experienceId);
      await _loadExperiences();
      _showSuccess('Experience deleted successfully!');
    } catch (e) {
      _showError('Failed to delete experience: $e');
    }
  }

  Future<void> _addLicense(Map<String, dynamic> licenseData) async {
    try {
      licenseData['user_id'] = widget.userId;
      await supabase.from('licenses').insert(licenseData);
      await _loadLicenses();
      _showSuccess('License added successfully!');
    } catch (e) {
      _showError('Failed to add license: $e');
    }
  }

  Future<void> _updateLicense(
    int licenseId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await supabase
          .from('licenses')
          .update(updates)
          .eq('license_id', licenseId);
      await _loadLicenses();
      _showSuccess('License updated successfully!');
    } catch (e) {
      _showError('Failed to update license: $e');
    }
  }

  Future<void> _deleteLicense(int licenseId) async {
    try {
      await supabase.from('licenses').delete().eq('license_id', licenseId);
      await _loadLicenses();
      _showSuccess('License deleted successfully!');
    } catch (e) {
      _showError('Failed to delete license: $e');
    }
  }

  Future<void> _addProject(Map<String, dynamic> projectData) async {
    try {
      projectData['user_id'] = widget.userId;
      await supabase.from('projects').insert(projectData);
      await _loadProjects();
      _showSuccess('Project added successfully!');
    } catch (e) {
      _showError('Failed to add project: $e');
    }
  }

  Future<void> _updateProject(
    int projectId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await supabase
          .from('projects')
          .update(updates)
          .eq('project_id', projectId);
      await _loadProjects();
      _showSuccess('Project updated successfully!');
    } catch (e) {
      _showError('Failed to update project: $e');
    }
  }

  Future<void> _deleteProject(int projectId) async {
    try {
      await supabase.from('projects').delete().eq('project_id', projectId);
      await _loadProjects();
      _showSuccess('Project deleted successfully!');
    } catch (e) {
      _showError('Failed to delete project: $e');
    }
  }

  Future<void> _addSkill(String skillName, String? endorsement) async {
    try {
      await supabase.from('skills').insert({
        'user_id': widget.userId,
        'name': skillName,
        'endorsement_info': endorsement ?? 'Self-endorsed',
        'proficiency_level': 'Intermediate',
      });
      await _loadSkills();
      _showSuccess('Skill added successfully!');
    } catch (e) {
      _showError('Failed to add skill: $e');
    }
  }

  Future<void> _updateSkill(int skillId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await supabase.from('skills').update(updates).eq('skill_id', skillId);
      await _loadSkills();
      _showSuccess('Skill updated successfully!');
    } catch (e) {
      _showError('Failed to update skill: $e');
    }
  }

  Future<void> _deleteSkill(int skillId) async {
    try {
      await supabase.from('skills').delete().eq('skill_id', skillId);
      await _loadSkills();
      _showSuccess('Skill deleted successfully!');
    } catch (e) {
      _showError('Failed to delete skill: $e');
    }
  }

  // ============================================
  // CRUD OPERATIONS (Posts/Comments)
  // ============================================

  Future<void> _updatePost(int postId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await supabase.from('posts').update(updates).eq('post_id', postId);
      await _loadUserPosts();
      _showSuccess('Post updated successfully!');
    } catch (e) {
      _showError('Failed to update post: $e');
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      await supabase.from('comments').delete().eq('post_id', postId);
      await supabase.from('likes').delete().eq('post_id', postId);
      await supabase.from('reposts').delete().eq('post_id', postId);
      await supabase.from('posts').delete().eq('post_id', postId);

      await _loadUserPosts();
      await _loadUserReposts();
      _showSuccess('Post deleted successfully!');
    } catch (e) {
      _showError('Failed to delete post: $e');
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await supabase
          .from('comment_likes') // Assuming this table exists, optional if not
          .delete()
          .eq('comment_id', commentId);

      await supabase
          .from('comments')
          .delete()
          .eq('parent_comment_id', commentId); // Delete children first

      await supabase.from('comments').delete().eq('comment_id', commentId);

      _showSuccess('Comment deleted successfully!');
    } catch (e) {
      _showError('Failed to delete comment: $e');
    }
  }

  Future<void> _addComment(int postId, String content) async {
    try {
      // Get the next comment_id
      final lastComment = await supabase
          .from('comments')
          .select('comment_id')
          .order('comment_id', ascending: false)
          .limit(1);

      int nextCommentId = 1;
      if (lastComment.isNotEmpty) {
        nextCommentId = (lastComment[0]['comment_id'] as int) + 1;
      }

      await supabase.from('comments').insert({
        'comment_id': nextCommentId,
        'post_id': postId,
        'user_id': widget.userId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSuccess('Comment posted successfully!');
    } catch (e) {
      _showError('Failed to post comment: $e');
    }
  }

  Future<void> _updateComment(int commentId, String content) async {
    try {
      await supabase
          .from('comments')
          .update({'content': content})
          .eq('comment_id', commentId);

      _showSuccess('Comment updated successfully!');
    } catch (e) {
      _showError('Failed to update comment: $e');
    }
  }

  // ============================================
  // DIALOG METHODS
  // ============================================

  // Separate Name Editing (Basic Info) - Role and Location removed
  void _showEditBasicInfoDialog() {
    final nameController = TextEditingController(text: fullName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateBasicInfoName(nameController.text);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC143C),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Separate Bio Editing
  void _showEditBioDialog() {
    final bioController = TextEditingController(text: bio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit About'),
        content: TextField(
          controller: bioController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'About',
            hintText: 'Ex: Student at ASU | Software Engineer',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateBio(bioController.text);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC143C),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProfessionalExperienceModal({Map<String, dynamic>? experience}) {
    final bool isEdit = experience != null;
    final titleController = TextEditingController(text: experience?['title']);
    final companyController = TextEditingController(
      text: experience?['company'],
    );
    final typeController = TextEditingController(
      text: experience?['employment_type'] ?? 'Full-time',
    );
    final locController = TextEditingController(text: experience?['location']);
    final descController = TextEditingController(
      text: experience?['description'],
    );

    DateTime startDate = experience?['start_date'] != null
        ? DateTime.parse(experience!['start_date'])
        : DateTime.now();
    DateTime? endDate = experience?['end_date'] != null
        ? DateTime.parse(experience!['end_date'])
        : null;
    bool isCurrent = experience?['is_current'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit experience' : 'Add experience',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModalLabel("Title*"),
                      _buildModalTextField(
                        titleController,
                        "Ex: Software Engineer",
                      ),
                      _buildModalLabel("Company name*"),
                      _buildModalTextField(companyController, "Ex: Microsoft"),
                      _buildModalLabel("Employment type"),
                      _buildModalTextField(typeController, "Ex: Full-time"),
                      _buildModalLabel("Location"),
                      _buildModalTextField(
                        locController,
                        "Ex: London, United Kingdom",
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          "I am currently working in this role",
                          style: TextStyle(fontSize: 14),
                        ),
                        value: isCurrent,
                        activeColor: const Color(0xFFE63946),
                        onChanged: (val) =>
                            setSheetState(() => isCurrent = val ?? false),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildModalLabel("Start date*"),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: startDate,
                                      firstDate: DateTime(1950),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null)
                                      setSheetState(() => startDate = picked);
                                  },
                                  child: _buildDateDisplay(
                                    DateFormat('MMMM yyyy').format(startDate),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isCurrent) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildModalLabel("End date*"),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: endDate ?? DateTime.now(),
                                        firstDate: DateTime(1950),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null)
                                        setSheetState(() => endDate = picked);
                                    },
                                    child: _buildDateDisplay(
                                      endDate != null
                                          ? DateFormat(
                                              'MMMM yyyy',
                                            ).format(endDate!)
                                          : "Select date",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      _buildModalLabel("Description"),
                      _buildModalTextField(descController, "", maxLines: 4),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.isEmpty ||
                          companyController.text.isEmpty)
                        return;
                      final data = {
                        'user_id': widget.userId,
                        'title': titleController.text,
                        'company': companyController.text,
                        'employment_type': typeController.text,
                        'location': locController.text,
                        'description': descController.text,
                        'start_date': startDate.toIso8601String(),
                        'end_date': isCurrent
                            ? null
                            : endDate?.toIso8601String(),
                        'is_current': isCurrent,
                      };
                      if (isEdit) {
                        await supabase
                            .from('experiences')
                            .update(data)
                            .eq('experience_id', experience['experience_id']);
                      } else {
                        await supabase.from('experiences').insert(data);
                      }
                      Navigator.pop(context);
                      _loadExperiences();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE63946),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      "Save",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddLicenseDialog() {
    final nameController = TextEditingController();
    final orgController = TextEditingController();
    DateTime issuedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add license or certification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              _buildModalLabel("Name*"),
              _buildModalTextField(
                nameController,
                "Ex: Microsoft Certified Network Associate",
              ),
              _buildModalLabel("Issuing organization*"),
              _buildModalTextField(orgController, "Ex: Microsoft"),
              _buildModalLabel("Issued date*"),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: issuedDate,
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setModalState(() => issuedDate = picked);
                },
                child: _buildDateDisplay(
                  DateFormat('MMMM yyyy').format(issuedDate),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        orgController.text.isEmpty)
                      return;
                    await _addLicense({
                      'name': nameController.text,
                      'issuing_organization': orgController.text,
                      'issue_date': issuedDate.toIso8601String(),
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE63946),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditLicenseDialog(Map<String, dynamic> license) {
    final nameController = TextEditingController(text: license['name']);
    final orgController = TextEditingController(
      text: license['issuing_organization'],
    );
    DateTime issuedDate = DateTime.parse(
      license['issue_date'] ?? DateTime.now().toIso8601String(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit license',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              _buildModalLabel("Name*"),
              _buildModalTextField(nameController, ""),
              _buildModalLabel("Issuing organization*"),
              _buildModalTextField(orgController, ""),
              _buildModalLabel("Issued date*"),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: issuedDate,
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setModalState(() => issuedDate = picked);
                },
                child: _buildDateDisplay(
                  DateFormat('MMMM yyyy').format(issuedDate),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _deleteLicense(license['license_id']);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                      child: const Text("Delete"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _updateLicense(license['license_id'], {
                          'name': nameController.text,
                          'issuing_organization': orgController.text,
                          'issue_date': issuedDate.toIso8601String(),
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                      ),
                      child: const Text(
                        "Save",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddProjectDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final skillsController = TextEditingController();
    final urlController = TextEditingController();

    DateTime startDate = DateTime.now();
    DateTime? endDate;
    bool isCurrent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add project',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModalLabel("Project name*"),
                      _buildModalTextField(
                        nameController,
                        "Ex: Mobile App Development",
                      ),

                      _buildModalLabel("Description"),
                      _buildModalTextField(
                        descriptionController,
                        "Describe what you did in this project",
                        maxLines: 4,
                      ),

                      _buildModalLabel("Project URL (optional)"),
                      _buildModalTextField(
                        urlController,
                        "Ex: https://github.com/username/project",
                      ),

                      _buildModalLabel("Skills used"),
                      _buildModalTextField(
                        skillsController,
                        "Ex: Flutter, Firebase, REST API",
                      ),

                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          "I am currently working on this project",
                          style: TextStyle(fontSize: 14),
                        ),
                        value: isCurrent,
                        activeColor: const Color(0xFFE63946),
                        onChanged: (val) =>
                            setModalState(() => isCurrent = val ?? false),
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildModalLabel("Start date*"),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: startDate,
                                      firstDate: DateTime(1950),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null)
                                      setModalState(() => startDate = picked);
                                  },
                                  child: _buildDateDisplay(
                                    DateFormat('MMMM yyyy').format(startDate),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isCurrent) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildModalLabel("End date*"),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: endDate ?? DateTime.now(),
                                        firstDate: DateTime(1950),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null)
                                        setModalState(() => endDate = picked);
                                    },
                                    child: _buildDateDisplay(
                                      endDate != null
                                          ? DateFormat(
                                              'MMMM yyyy',
                                            ).format(endDate!)
                                          : "Select date",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter project name'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final projectData = {
                        'user_id': widget.userId,
                        'name': nameController.text,
                        'description': descriptionController.text,
                        'project_url': urlController.text,
                        'skills': skillsController.text,
                        'start_date': startDate.toIso8601String(),
                        'end_date': isCurrent
                            ? null
                            : endDate?.toIso8601String(),
                        'is_current': isCurrent,
                      };

                      await _addProject(projectData);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE63946),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      "Save",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProjectDialog(Map<String, dynamic> project) {
    final nameController = TextEditingController(text: project['name']);
    final descriptionController = TextEditingController(
      text: project['description'] ?? '',
    );
    final skillsController = TextEditingController(
      text: project['skills'] ?? '',
    );
    final urlController = TextEditingController(
      text: project['project_url'] ?? '',
    );

    DateTime startDate = project['start_date'] != null
        ? DateTime.parse(project['start_date'])
        : DateTime.now();
    DateTime? endDate = project['end_date'] != null
        ? DateTime.parse(project['end_date'])
        : null;
    bool isCurrent = project['is_current'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit project',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModalLabel("Project name*"),
                      _buildModalTextField(nameController, ""),

                      _buildModalLabel("Description"),
                      _buildModalTextField(
                        descriptionController,
                        "",
                        maxLines: 4,
                      ),

                      _buildModalLabel("Project URL (optional)"),
                      _buildModalTextField(urlController, ""),

                      _buildModalLabel("Skills used"),
                      _buildModalTextField(skillsController, ""),

                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          "I am currently working on this project",
                          style: TextStyle(fontSize: 14),
                        ),
                        value: isCurrent,
                        activeColor: const Color(0xFFE63946),
                        onChanged: (val) =>
                            setModalState(() => isCurrent = val ?? false),
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildModalLabel("Start date*"),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: startDate,
                                      firstDate: DateTime(1950),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null)
                                      setModalState(() => startDate = picked);
                                  },
                                  child: _buildDateDisplay(
                                    DateFormat('MMMM yyyy').format(startDate),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isCurrent) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildModalLabel("End date*"),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: endDate ?? DateTime.now(),
                                        firstDate: DateTime(1950),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null)
                                        setModalState(() => endDate = picked);
                                    },
                                    child: _buildDateDisplay(
                                      endDate != null
                                          ? DateFormat(
                                              'MMMM yyyy',
                                            ).format(endDate!)
                                          : "Select date",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Project?'),
                              content: const Text(
                                'Are you sure you want to delete this project?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    await _deleteProject(project['project_id']);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Delete"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter project name'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          await _updateProject(project['project_id'], {
                            'name': nameController.text,
                            'description': descriptionController.text,
                            'project_url': urlController.text,
                            'skills': skillsController.text,
                            'start_date': startDate.toIso8601String(),
                            'end_date': isCurrent
                                ? null
                                : endDate?.toIso8601String(),
                            'is_current': isCurrent,
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE63946),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Save",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSkillDialog() {
    final skillController = TextEditingController();
    final endorsementController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Skill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: skillController,
              decoration: const InputDecoration(labelText: 'Skill Name *'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: endorsementController,
              decoration: const InputDecoration(labelText: 'Endorsement Info'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (skillController.text.isNotEmpty) {
                await _addSkill(
                  skillController.text,
                  endorsementController.text,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC143C),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditSkillDialog(Map<String, dynamic> skill) {
    final skillController = TextEditingController(text: skill['name']);
    final endorsementController = TextEditingController(
      text: skill['endorsement_info'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Skill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: skillController,
              decoration: const InputDecoration(labelText: 'Skill Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: endorsementController,
              decoration: const InputDecoration(labelText: 'Endorsement Info'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await _deleteSkill(skill['skill_id']);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateSkill(skill['skill_id'], {
                'name': skillController.text,
                'endorsement_info': endorsementController.text,
              });
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC143C),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => CreatePostModal(
              userId: widget.userId,
              userRole: userRole, // ADD THIS LINE
            ),
          ),
        )
        .then((result) async {
          if (result != null && result['success'] == true) {
            await _loadCompleteProfileData();

            if (mounted) {
              _showSuccess('Post created successfully!');
            }
          }
        });
  }

  void _showEditPostDialog(Map<String, dynamic> post) {
    final titleController = TextEditingController(text: post['title']);
    final contentController = TextEditingController(text: post['content']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Post'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await _deletePost(post['post_id']);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updatePost(post['post_id'], {
                'title': titleController.text,
                'content': contentController.text,
              });
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC143C),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPostDetailsWithComments(Map<String, dynamic> post) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsScreen(
          post: post,
          currentUserId: widget.userId,
          currentUserName: fullName,
          currentUserImage: imageUrl,
        ),
      ),
    ).then((_) {
      // Refresh data when coming back
      _loadUserPosts();
      _loadUserComments();
      setState(() {});
    });
  }

  void _showCommentDialog(
    int postId,
    String postTitle, {
    int? parentCommentId,
  }) async {
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parentCommentId == null ? 'Add Comment' : 'Add Reply',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              postTitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        content: TextField(
          controller: commentController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: parentCommentId == null
                ? 'Write your comment...'
                : 'Write your reply...',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (commentController.text.trim().isNotEmpty) {
                try {
                  // Get next comment ID
                  final lastComment = await supabase
                      .from('comments')
                      .select('comment_id')
                      .order('comment_id', ascending: false)
                      .limit(1);

                  int nextCommentId = 1;
                  if (lastComment.isNotEmpty) {
                    nextCommentId = (lastComment[0]['comment_id'] as int) + 1;
                  }

                  await supabase.from('comments').insert({
                    'comment_id': nextCommentId,
                    'post_id': postId,
                    'user_id': widget.userId,
                    'content': commentController.text.trim(),
                    'parent_comment_id': parentCommentId,
                    'created_at': DateTime.now().toIso8601String(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    _showSuccess('Comment posted successfully!');
                    // Show the updated comments dialog
                    _showAllCommentsDialog(postId, postTitle);
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    _showError('Failed to post comment: $e');
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC143C),
            ),
            child: const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAllCommentsDialog(int postId, String postTitle) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ===== HEADER =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          postTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const Divider(),

                  // ===== COMMENTS LIST =====
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: supabase
                          .from('comments')
                          .select('''
                          *,
                          users!inner(user_id, name, profile_image, role, department)
                        ''')
                          .eq('post_id', postId)
                          .order('created_at', ascending: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFDC143C),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading comments',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No comments yet',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to comment!',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final allComments = snapshot.data!;

                        // ===== BUILD TREE (PARENTS + REPLIES) =====
                        Map<int, List<Map<String, dynamic>>> tree = {};
                        List<Map<String, dynamic>> parents = [];

                        for (var c in allComments) {
                          if (c['parent_comment_id'] == null) {
                            parents.add(c);
                            tree[c['comment_id']] = [];
                          }
                        }

                        for (var c in allComments) {
                          if (c['parent_comment_id'] != null) {
                            tree[c['parent_comment_id']]?.add(c);
                          }
                        }

                        return Column(
                          children: [
                            // Comment count
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${allComments.length} comment${allComments.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            Expanded(
                              child: ListView.builder(
                                itemCount: parents.length,
                                itemBuilder: (context, index) {
                                  final comment = parents[index];
                                  final replies =
                                      tree[comment['comment_id']] ?? [];

                                  return _buildSimpleCommentItem(
                                    comment,
                                    replies,
                                    postId,
                                    postTitle,
                                    setDialogState,
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const Divider(),

                  // ===== ADD COMMENT BUTTON =====
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCommentDialog(postId, postTitle);
                    },
                    icon: const Icon(Icons.add_comment, size: 18),
                    label: const Text('Add Comment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC143C),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimpleCommentItem(
    Map<String, dynamic> comment,
    List<Map<String, dynamic>> replies,
    int postId,
    String postTitle,
    StateSetter setDialogState,
  ) {
    final user = comment['users'] ?? {};
    final isMyComment = comment['user_id'] == widget.userId;
    final userName = user['name'] ?? 'Unknown User';
    final userImage = user['profile_image'];
    final userRole = user['role'];
    final userDept = user['department'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main comment
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    (userImage != null && userImage.toString().isNotEmpty)
                    ? NetworkImage(userImage)
                    : null,
                backgroundColor: Colors.grey[300],
                child: (userImage == null || userImage.toString().isEmpty)
                    ? Icon(Icons.person, size: 18, color: Colors.grey[600])
                    : null,
              ),
              const SizedBox(width: 12),

              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and info
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (userRole != null || userDept != null)
                      Text(
                        '${userRole ?? ''}${userRole != null && userDept != null ? ' at ' : ''}${userDept ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(comment['created_at']),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),

                    // Comment text
                    Text(
                      comment['content'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Action buttons
                    Row(
                      children: [
                        // Like count
                        FutureBuilder<int>(
                          future: _getCommentLikeCount(comment['comment_id']),
                          builder: (context, snapshot) {
                            final likeCount = snapshot.data ?? 0;
                            if (likeCount > 0) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.thumb_up,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$likeCount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        // Like button
                        InkWell(
                          onTap: () async {
                            await _toggleCommentLike(comment['comment_id']);
                            setDialogState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: FutureBuilder<bool>(
                              future: _isCommentLiked(comment['comment_id']),
                              builder: (context, snapshot) {
                                final isLiked = snapshot.data ?? false;
                                return Text(
                                  'Like',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isLiked
                                        ? const Color(0xFFDC143C)
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Reply button
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _showCommentDialog(
                              postId,
                              postTitle,
                              parentCommentId: comment['comment_id'],
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Edit/Delete menu
                        if (isMyComment)
                          PopupMenuButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: const Text('Edit'),
                                onTap: () {
                                  Future.delayed(Duration.zero, () {
                                    final controller = TextEditingController(
                                      text: comment['content'],
                                    );
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Edit Comment'),
                                        content: TextField(
                                          controller: controller,
                                          maxLines: 3,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              await _updateComment(
                                                comment['comment_id'],
                                                controller.text,
                                              );
                                              if (mounted) {
                                                Navigator.pop(context);
                                                Navigator.pop(context);
                                                _showAllCommentsDialog(
                                                  postId,
                                                  postTitle,
                                                );
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFDC143C,
                                              ),
                                            ),
                                            child: const Text(
                                              'Save',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  });
                                },
                              ),
                              PopupMenuItem(
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                                onTap: () async {
                                  await _deleteComment(comment['comment_id']);
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _showAllCommentsDialog(postId, postTitle);
                                  }
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Nested replies
          if (replies.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 40, top: 12),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey[300]!, width: 2),
                ),
              ),
              child: Column(
                children: replies.map((reply) {
                  final replyUser = reply['users'] ?? {};
                  final isMyReply = reply['user_id'] == widget.userId;
                  final replyUserName = replyUser['name'] ?? 'Unknown';
                  final replyUserImage = replyUser['profile_image'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage:
                              (replyUserImage != null &&
                                  replyUserImage.toString().isNotEmpty)
                              ? NetworkImage(replyUserImage)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child:
                              (replyUserImage == null ||
                                  replyUserImage.toString().isEmpty)
                              ? Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.grey[600],
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                replyUserName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDate(reply['created_at']),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reply['content'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      await _toggleCommentLike(
                                        reply['comment_id'],
                                      );
                                      setDialogState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      child: FutureBuilder<bool>(
                                        future: _isCommentLiked(
                                          reply['comment_id'],
                                        ),
                                        builder: (context, snapshot) {
                                          final isLiked =
                                              snapshot.data ?? false;
                                          return Text(
                                            'Like',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isLiked
                                                  ? const Color(0xFFDC143C)
                                                  : Colors.grey[600],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showCommentDialog(
                                        postId,
                                        postTitle,
                                        parentCommentId: comment['comment_id'],
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      child: Text(
                                        'Reply',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isMyReply)
                                    PopupMenuButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        Icons.more_horiz,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          child: const Text('Edit'),
                                          onTap: () {
                                            Future.delayed(Duration.zero, () {
                                              final controller =
                                                  TextEditingController(
                                                    text: reply['content'],
                                                  );
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text(
                                                    'Edit Reply',
                                                  ),
                                                  content: TextField(
                                                    controller: controller,
                                                    maxLines: 3,
                                                    decoration:
                                                        const InputDecoration(
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        await _updateComment(
                                                          reply['comment_id'],
                                                          controller.text,
                                                        );
                                                        if (mounted) {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          _showAllCommentsDialog(
                                                            postId,
                                                            postTitle,
                                                          );
                                                        }
                                                      },
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                  0xFFDC143C,
                                                                ),
                                                          ),
                                                      child: const Text(
                                                        'Save',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            });
                                          },
                                        ),
                                        PopupMenuItem(
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          onTap: () async {
                                            await _deleteComment(
                                              reply['comment_id'],
                                            );
                                            if (mounted) {
                                              Navigator.pop(context);
                                              _showAllCommentsDialog(
                                                postId,
                                                postTitle,
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddSectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.work_outline),
              title: const Text('Experience'),
              onTap: () {
                Navigator.pop(context);
                _showProfessionalExperienceModal();
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('License or Certification'),
              onTap: () {
                Navigator.pop(context);
                _showAddLicenseDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Project'),
              onTap: () {
                Navigator.pop(context);
                _showAddProjectDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Skill'),
              onTap: () {
                Navigator.pop(context);
                _showAddSkillDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // UI UTILS
  // ============================================

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Present';
    try {
      final DateTime dt = DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = now.difference(dt);

      // Handle future dates (shouldn't happen, but just in case)
      if (difference.isNegative) {
        return 'Just now';
      }

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (e) {
      return 'Just now';
    }
  }

  String _calculateDuration(dynamic startDate, dynamic endDate) {
    if (startDate == null) return '';
    try {
      final DateTime start = DateTime.parse(startDate.toString());
      final DateTime end = endDate != null
          ? DateTime.parse(endDate.toString())
          : DateTime.now();

      final int months = (end.year - start.year) * 12 + end.month - start.month;
      if (months < 1) return '< 1 mo';
      if (months == 1) return '1 mo';
      if (months < 12) return '$months mos';

      final int years = months ~/ 12;
      final int remainingMonths = months % 12;
      if (remainingMonths == 0) return '$years yr${years > 1 ? 's' : ''}';
      return '$years yr${years > 1 ? 's' : ''} $remainingMonths mo${remainingMonths > 1 ? 's' : ''}';
    } catch (e) {
      return '';
    }
  }

  // ============================================
  // BUILD METHOD
  // ============================================

  @override
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFDC143C)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],

      // ✅ ADD TOP NAVBAR
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: TopNavbar(userId: widget.userId),
      ),

      // ✅ KEEP DRAWER
      endDrawer: UserDrawerContent(userId: widget.userId),

      body: RefreshIndicator(
        onRefresh: _loadCompleteProfileData,
        color: const Color(0xFFDC143C),
        displacement: 40, // Distance to pull before refresh triggers
        strokeWidth: 3.0, // Thickness of the refresh indicator
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // ADD THIS LINE - Enables pull even when content is short

          slivers: [
            // ❌ REMOVE _buildAppBar() - we're using TopNavbar instead
            // _buildAppBar(),  // DELETE THIS LINE
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 8),

                  // Headline / Bio Section
                  if (bio != null && bio!.isNotEmpty) ...[
                    _buildBioSection(),
                    const SizedBox(height: 8),
                  ],

                  // Activities
                  if (userPosts.isNotEmpty ||
                      userComments.isNotEmpty ||
                      userReposts.isNotEmpty) ...[
                    _buildActivitySection(),
                    const SizedBox(height: 8),
                  ],

                  // Experience
                  if (experiences.isNotEmpty) ...[
                    _buildExperienceSection(),
                    const SizedBox(height: 8),
                  ],

                  // Projects (AFTER EXPERIENCE)
                  if (projects.isNotEmpty) ...[
                    _buildProjectsSection(),
                    const SizedBox(height: 8),
                  ],

                  // Licenses
                  if (licenses.isNotEmpty) ...[
                    _buildLicensesSection(),
                    const SizedBox(height: 8),
                  ],

                  // Skills
                  if (skills.isNotEmpty) ...[
                    _buildSkillsSection(),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),

      // ✅ ADD BOTTOM NAVBAR
      bottomNavigationBar: BottomNavbar(
        currentUserId: widget.userId,
        currentIndex: 3, // Profile tab is selected
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Cover Photo Area
          Stack(
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: coverImageUrl != null && coverImageUrl!.isNotEmpty
                      ? null
                      : LinearGradient(
                          colors: [Colors.grey[800]!, Colors.grey[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  image: (coverImageUrl != null && coverImageUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(coverImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _uploadCoverPhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.camera_alt, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Edit cover photo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          Transform.translate(
            offset: const Offset(0, -40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage:
                              (imageUrl != null && imageUrl!.isNotEmpty)
                              ? NetworkImage(imageUrl!)
                              : null,
                          child: (imageUrl == null || imageUrl!.isEmpty)
                              ? const Icon(Icons.person, size: 60)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadProfilePicture,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullName ?? 'Unknown User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Edit Basic Info (Name)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: _showEditBasicInfoDialog,
                      ),
                    ],
                  ),

                  if (role != null)
                    Text(
                      role!, // Role is read-only here
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                    ),

                  if (department != null)
                    Text(
                      'Department: $department',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),

                  if (academicYear != null)
                    Text(
                      'Year: $academicYear',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Text(
                        '$followers followers',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFDC143C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(' · ', style: TextStyle(color: Colors.grey[600])),
                      Text(
                        '$connections connections',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFDC143C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showAddSectionDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC143C),
                            side: const BorderSide(color: Color(0xFFDC143C)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Add section',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showCreatePostDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC143C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Create Post',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'About',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: _showEditBioDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bio ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    // Calculate total activities including announcements
    final totalActivities =
        userPosts.length + userComments.length + userReposts.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$totalActivities activities',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _showCreatePostDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFDC143C),
                  side: const BorderSide(color: Color(0xFFDC143C)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Create a post'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TabBar(
            controller: _activityTabController,
            labelColor: const Color(0xFFDC143C),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFFDC143C),
            isScrollable: true,
            tabs: [
              Tab(text: 'Posts (${userPosts.length})'),
              Tab(text: 'Comments (${userComments.length})'),
              Tab(text: 'Reposts (${userReposts.length})'),
            ],
          ),

          const SizedBox(height: 16),

          // Tab 0: Posts
          if (_selectedActivityTab == 0) ...[
            if (userPosts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No posts yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else ...[
              // Show only the most recent post, or all if expanded
              ...(_showAllPosts ? userPosts : userPosts.take(1)).map(
                (post) => _buildPostCard(post),
              ),

              // Show "View All" button if there's more than 1 post
              if (userPosts.length > 1)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: TextButton(
                      onPressed: () {
                        setState(() => _showAllPosts = !_showAllPosts);
                      },
                      child: Text(
                        _showAllPosts
                            ? 'Show Less'
                            : 'View All ${userPosts.length} Posts',
                        style: const TextStyle(
                          color: Color(0xFFDC143C),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],

          // Tab 1: Comments (was Tab 2)
          if (_selectedActivityTab == 1) ...[
            if (userComments.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No comments yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else ...[
              ...(_showAllComments ? userComments : userComments.take(1)).map(
                (comment) => _buildCommentCard(comment),
              ),

              if (userComments.length > 1)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: TextButton(
                      onPressed: () {
                        setState(() => _showAllComments = !_showAllComments);
                      },
                      child: Text(
                        _showAllComments
                            ? 'Show Less'
                            : 'View All ${userComments.length} Comments',
                        style: const TextStyle(
                          color: Color(0xFFDC143C),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],

          // Tab 2: Reposts (was Tab 3)
          if (_selectedActivityTab == 2) ...[
            if (userReposts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No reposts yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else ...[
              ...(_showAllReposts ? userReposts : userReposts.take(1)).map(
                (repost) => _buildRepostCard(repost),
              ),

              if (userReposts.length > 1)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: TextButton(
                      onPressed: () {
                        setState(() => _showAllReposts = !_showAllReposts);
                      },
                      child: Text(
                        _showAllReposts
                            ? 'Show Less'
                            : 'View All ${userReposts.length} Reposts',
                        style: const TextStyle(
                          color: Color(0xFFDC143C),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    // Check the post type
    final postType = post['post_type'] ?? 'post';

    return StatefulBuilder(
      builder: (context, setCardState) {
        // For announcements and competition requests, we don't need like/comment counts
        if (postType == 'announcement') {
          return _buildAnnouncementPostCard(post);
        } else if (postType == 'competition_request') {
          return _buildCompetitionRequestCard(post);
        }

        // Regular post - existing implementation with likes/comments/reposts
        return FutureBuilder<List<int>>(
          future: Future.wait([
            _getPostLikeCount(post['post_id']),
            _getPostCommentCount(post['post_id']),
            _getPostRepostCount(post['post_id']),
          ]),
          builder: (context, snapshot) {
            final counts = snapshot.data ?? [0, 0, 0];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[200],
                          backgroundImage:
                              (imageUrl != null && imageUrl!.isNotEmpty)
                              ? NetworkImage(imageUrl!)
                              : null,
                          child: (imageUrl == null || imageUrl!.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDate(post['created_at']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz),
                          onPressed: () => _showPostActionMenu(post),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (post['title'] != null &&
                        post['title'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          post['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      post['content'] ?? '',
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (post['media_url'] != null &&
                        post['media_url'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          post['media_url'],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ],
                    if (post['file_url'] != null &&
                        post['file_url'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openFile(post['file_url']),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blueGrey[100]!),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.insert_drive_file,
                                  color: Colors.blueGrey,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Attached Document",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        "Click to view or download",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.open_in_new,
                                  size: 18,
                                  color: Colors.blueGrey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Color(0xFFDC143C),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${counts[0]}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _showPostDetailsWithComments(post),
                          child: Text(
                            '${counts[1]} comment${counts[1] != 1 ? 's' : ''} · ${counts[2]} repost${counts[2] != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: Colors.grey[300]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        FutureBuilder<bool>(
                          future: _isPostLiked(post['post_id']),
                          builder: (context, snapshot) {
                            final isLiked = snapshot.data ?? false;
                            return TextButton.icon(
                              onPressed: () async {
                                await _toggleLike(post['post_id']);
                                setCardState(() {});
                              },
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked
                                    ? const Color(0xFFDC143C)
                                    : Colors.grey[700],
                                size: 20,
                              ),
                              label: Text(
                                'Like',
                                style: TextStyle(
                                  color: isLiked
                                      ? const Color(0xFFDC143C)
                                      : Colors.grey[700],
                                ),
                              ),
                            );
                          },
                        ),
                        TextButton.icon(
                          onPressed: () => _showPostDetailsWithComments(post),
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
                        FutureBuilder<bool>(
                          future: _isPostReposted(post['post_id']),
                          builder: (context, snapshot) {
                            final isReposted = snapshot.data ?? false;
                            return TextButton.icon(
                              onPressed: () async {
                                await _toggleRepost(post['post_id']);
                                setCardState(() {});
                              },
                              icon: Icon(
                                Icons.repeat,
                                color: isReposted
                                    ? const Color(0xFFDC143C)
                                    : Colors.grey[700],
                                size: 20,
                              ),
                              label: Text(
                                'Repost',
                                style: TextStyle(
                                  color: isReposted
                                      ? const Color(0xFFDC143C)
                                      : Colors.grey[700],
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
          },
        );
      },
    );
  }

  // Add these helper methods for announcements and competition requests:

  Widget _buildAnnouncementPostCard(Map<String, dynamic> announcement) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.campaign,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Announcement',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDate(announcement['created_at']),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement['title'] ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              announcement['content'] ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (announcement['announcement_date'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.event, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Event: ${announcement['announcement_date']} at ${announcement['announcement_time']}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitionRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE63946).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.group_add,
                    color: Color(0xFFE63946),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Competition Partner Request',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE63946),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDate(request['created_at']),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request['title'] ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              request['content'] ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Team size: ${request['team_size']}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            if (request['needed_skills'] != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: request['needed_skills']
                    .toString()
                    .split(',')
                    .map(
                      (skill) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          skill.trim(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final post = comment['posts'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? NetworkImage(imageUrl!)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${fullName ?? 'Unknown'} commented',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _formatDate(comment['created_at']),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Edit Comment'),
                              onTap: () {
                                Navigator.pop(context);
                                final controller = TextEditingController(
                                  text: comment['content'],
                                );
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Edit Comment'),
                                    content: TextField(
                                      controller: controller,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await _updateComment(
                                            comment['comment_id'],
                                            controller.text,
                                          );
                                          if (mounted) Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFDC143C,
                                          ),
                                        ),
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              title: const Text('Delete Comment'),
                              onTap: () async {
                                Navigator.pop(context);
                                await _deleteComment(comment['comment_id']);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                comment['content'] ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original Post',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (post != null) ...[
                    Text(
                      post['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      post['content'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else
                    const Text(
                      "Post unavailable",
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepostCard(Map<String, dynamic> repost) {
    final post = repost['posts'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.repeat, color: Color(0xFFDC143C), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${fullName ?? 'Unknown'} reposted this',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _formatDate(repost['created_at']),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _toggleRepost(post['post_id']),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: post == null
                  ? const Text("Original post unavailable")
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post['content'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (post['media_url'] != null &&
                            post['media_url'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                              image: DecorationImage(
                                image: NetworkImage(post['media_url']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Posted ${_formatDate(post['created_at'])}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Experience',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 24),
                onPressed: _showProfessionalExperienceModal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...experiences.map((exp) => _buildExperienceItem(exp)),
        ],
      ),
    );
  }

  Widget _buildExperienceItem(Map<String, dynamic> exp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showProfessionalExperienceModal(experience: exp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.business, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exp['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${exp['company']}${exp['employment_type'] != null ? ' · ${exp['employment_type']}' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  if (exp['start_date'] != null)
                    Text(
                      _calculateDuration(exp['start_date'], exp['end_date']),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  if (exp['location'] != null)
                    Text(
                      exp['location'],
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  if (exp['skills'] != null &&
                      exp['skills'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.star_border, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              exp['skills'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicensesSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Licenses & certifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 24),
                onPressed: _showAddLicenseDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...licenses.map((license) => _buildLicenseItem(license)),
        ],
      ),
    );
  }

  Widget _buildLicenseItem(Map<String, dynamic> license) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showEditLicenseDialog(license),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.workspace_premium, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    license['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    license['issuing_organization'] ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  if (license['issue_date'] != null)
                    Text(
                      'Issued ${_formatDate(license['issue_date'])}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Projects',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 24),
                onPressed: _showAddProjectDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...projects.map((project) => _buildProjectItem(project)),
        ],
      ),
    );
  }

  Widget _buildProjectItem(Map<String, dynamic> project) {
    final hasUrl =
        project['project_url'] != null &&
        project['project_url'].toString().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showEditProjectDialog(project),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE63946).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.folder_outlined,
                color: Color(0xFFE63946),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasUrl)
                        GestureDetector(
                          onTap: () => _openFile(project['project_url']),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Color(0xFFE63946),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (project['start_date'] != null)
                    Row(
                      children: [
                        Text(
                          '${DateFormat('MMM yyyy').format(DateTime.parse(project['start_date']))} - ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          project['is_current'] == true
                              ? 'Present'
                              : project['end_date'] != null
                              ? DateFormat(
                                  'MMM yyyy',
                                ).format(DateTime.parse(project['end_date']))
                              : 'Present',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (project['is_current'] == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'In Progress',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (project['description'] != null &&
                      project['description'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        project['description'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (project['skills'] != null &&
                      project['skills'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: project['skills']
                            .toString()
                            .split(',')
                            .map(
                              (skill) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  skill.trim(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Skills',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 24),
                onPressed: _showAddSkillDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...skills.map((skill) => _buildSkillItem(skill)),
        ],
      ),
    );
  }

  Widget _buildSkillItem(Map<String, dynamic> skill) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showEditSkillDialog(skill),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill['name'] ?? '',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (skill['endorsement_info'] != null &&
                skill['endorsement_info'].toString().isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.verified, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      skill['endorsement_info'],
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CREATE POST MODAL (Full AddPost Logic)
// ==========================================

class CreatePostModal extends StatefulWidget {
  final int userId;
  final String? userRole; // ADD THIS LINE
  final Map<String, dynamic>? editPostData;

  const CreatePostModal({
    Key? key,
    required this.userId,
    this.userRole, // ADD THIS LINE
    this.editPostData,
  }) : super(key: key);

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  // Add these with other TextEditingController declarations
  final TextEditingController _competitionTitleController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _neededSkillsController = TextEditingController();
  final TextEditingController _teamSizeController = TextEditingController();

  // Add this with other state variables
  String? _competitionSubType; // For Alumni: 'partner' or 'announcement'

  // --- STATE VARIABLES ---
  bool _showCreatePost = false;
  bool _isLoadingCategories = true;
  bool _isUploading = false;

  // --- POST DATA ---
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _selectedCategory;
  final TextEditingController _postController = TextEditingController();

  // These are the ones causing your errors:
  String _postType = 'Post';
  DateTime? _selectedDateTime;
  List<XFile> _selectedImages =
      []; // Note: changed from XFile? to List to match your .clear() call
  List<PlatformFile> _selectedFiles = []; // For file attachments

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _heightAnimation = Tween<double>(begin: 0.6, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadCategories();

    // Check if we are in EDIT mode
    if (widget.editPostData != null) {
      _postController.text = widget.editPostData!['content'] ?? '';
      _showCreatePost = true;
      _animationController.value = 1.0;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _postController.dispose();
    // ADD THESE LINES:
    _competitionTitleController.dispose();
    _descriptionController.dispose();
    _neededSkillsController.dispose();
    _teamSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select('category_id, name')
          .order('name');

      if (mounted) {
        List<Map<String, dynamic>> allCategories =
            List<Map<String, dynamic>>.from(response);

        // ADD THESE LINES:
        List<Map<String, dynamic>> filteredCategories = _filterCategoriesByRole(
          allCategories,
        );

        setState(() {
          _categories = filteredCategories; // CHANGE FROM allCategories
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ADD THIS NEW METHOD after _loadCategories()
  List<Map<String, dynamic>> _filterCategoriesByRole(
    List<Map<String, dynamic>> categories,
  ) {
    final role = widget.userRole?.toLowerCase();

    if (role == null) {
      return categories;
    }

    if (role == 'instructor' || role == 'ta') {
      return categories;
    } else if (role == 'alumni') {
      return categories.where((category) {
        final categoryName = category['name'].toString().toLowerCase();
        return !categoryName.contains('news') &&
            !categoryName.contains('course');
      }).toList();
    } else if (role == 'student') {
      return categories.where((category) {
        final categoryName = category['name'].toString().toLowerCase();
        return categoryName.contains('competition') ||
            categoryName.contains('event');
      }).toList();
    }

    return categories;
  }

  Future<void> _createPost() async {
    // ========================================
    // HANDLE COMPETITION PARTNER REQUEST (STUDENTS ONLY)
    // ========================================
    if (_isCompetitionRequest()) {
      // Validate competition request fields
      if (_competitionTitleController.text.trim().isEmpty ||
          _descriptionController.text.trim().isEmpty ||
          _neededSkillsController.text.trim().isEmpty ||
          _teamSizeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all competition request fields'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }

      final teamSize = int.tryParse(_teamSizeController.text.trim());
      if (teamSize == null || teamSize < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid team size (minimum 1)'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }

      setState(() => _isUploading = true);

      try {
        final userId = widget.userId;

        // Insert into competition_requests table
        // NOTE: competition_id is NOT included - it will be auto-generated by the database
        final requestData = {
          'user_id': userId,
          'title': _competitionTitleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'needed_skills': _neededSkillsController.text.trim(),
          'team_size': teamSize,
          'created_at': DateTime.now().toIso8601String(),
        };

        await supabase.from('competition_requests').insert(requestData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Competition partner request submitted successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, {
            'success': true,
            'type': 'competition_request',
          });
        }
      } catch (e) {
        print('Error creating competition request: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
      return; // Exit early for competition requests
    }

    // ========================================
    // REGULAR POST/ANNOUNCEMENT VALIDATION
    // ========================================
    if (_postController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add some content')));
      return;
    }

    // Validate announcement requirements
    if (_postType == 'Announcement' && _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and time for announcement'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = widget.userId;

      if (_postType == 'Announcement') {
        // ========================================
        // INSERT INTO ANNOUNCEMENTS TABLE
        // ========================================
        final announcementData = {
          'auth_id': userId,
          'date': _selectedDateTime!.toIso8601String().split('T')[0],
          'time':
              '${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}:00',
          'title': _selectedCategory!['name'],
          'description': _postController.text.trim(),
          'category_id': _selectedCategory!['category_id'],
          'created_at': DateTime.now().toIso8601String(),
        };

        await supabase.from('announcement').insert(announcementData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Announcement scheduled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, {'success': true, 'type': 'announcement'});
        }
      } else {
        // ========================================
        // INSERT INTO POSTS TABLE (Regular Post)
        // ========================================
        String imageMediaUrl = '';
        String attachedFileUrl = '';

        // Upload images
        if (_selectedImages.isNotEmpty) {
          final image = _selectedImages.first;
          final bytes = await image.readAsBytes();
          final fileExt = image.name.split('.').last;
          final fileName =
              'img_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

          await supabase.storage
              .from('Posts')
              .uploadBinary(
                'post_images/$fileName',
                bytes,
                fileOptions: FileOptions(contentType: 'image/$fileExt'),
              );
          imageMediaUrl = supabase.storage
              .from('Posts')
              .getPublicUrl('post_images/$fileName');
        }

        // Upload files
        if (_selectedFiles.isNotEmpty) {
          final file = _selectedFiles.first;
          final Uint8List fileData = kIsWeb
              ? file.bytes!
              : await File(file.path!).readAsBytes();
          final fileExt = file.extension ?? 'dat';
          final fileName =
              'doc_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

          await supabase.storage
              .from('Posts')
              .uploadBinary(
                'post_files/$fileName',
                fileData,
                fileOptions: FileOptions(contentType: 'application/$fileExt'),
              );
          attachedFileUrl = supabase.storage
              .from('Posts')
              .getPublicUrl('post_files/$fileName');
        }

        final postData = {
          'author_id': userId,
          'content': _postController.text.trim(),
          'media_url': imageMediaUrl,
          'file_url': attachedFileUrl,
          'category_id': _selectedCategory!['category_id'],
          'title': _selectedCategory!['name'],
        };

        await supabase.from('posts').insert(postData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, {'success': true, 'type': 'post'});
        }
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
  // ADD THESE THREE METHODS:

  bool _isCompetitionRequest() {
    if (_selectedCategory == null) return false;

    final categoryName = _selectedCategory!['name'].toString().toLowerCase();
    final userRole = widget.userRole?.toLowerCase();

    if (categoryName.contains('competition')) {
      if (userRole == 'student') return true;
      if (userRole == 'alumni' && _competitionSubType == 'partner') return true;
    }

    return false;
  }

  void _showCompetitionSubCategoryModal(Map<String, dynamic> category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Competition Type',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose what you want to do',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),

            // FIND COMPETITION PARTNER OPTION
            InkWell(
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedCategory = category;
                  _competitionSubType = 'partner';
                  _showCreatePost = true;
                  _postType = 'Post';
                  _selectedDateTime = null;
                  _selectedImages.clear();
                  _selectedFiles.clear();
                });
                _animationController.forward();
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE63946).withOpacity(0.85),
                      const Color(0xFFDC2F41).withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.group_add,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Competition Partner',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Looking for teammates',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // COMPETITION ANNOUNCEMENT OPTION
            InkWell(
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedCategory = category;
                  _competitionSubType = 'announcement';
                  _showCreatePost = true;
                  _postType = 'Post';
                  _selectedDateTime = null;
                  _selectedImages.clear();
                  _selectedFiles.clear();
                });
                _animationController.forward();
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[600]!.withOpacity(0.85),
                      Colors.grey[700]!.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Competition Announcement',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Share competition info',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canShowPostTypeDropdown() {
    if (_selectedCategory == null) return false;

    final categoryName = _selectedCategory!['name']
        .toString()
        .toLowerCase()
        .trim();

    final userRole = widget.userRole?.toLowerCase();

    final postOnlyCategories = [
      'internships',
      'internship',
      'jobs',
      'job',
      'news',
    ];

    final isPostOnly = postOnlyCategories.any(
      (cat) => categoryName.contains(cat),
    );

    if (isPostOnly && _postType != 'Post') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _postType = 'Post';
          });
        }
      });
    }

    // FOR STUDENTS: Events should be Announcement-only
    if (userRole == 'student' && categoryName.contains('event')) {
      if (_postType != 'Announcement') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _postType = 'Announcement';
            });
          }
        });
      }
      return false;
    }

    return !isPostOnly;
  }

  void _onCategorySelected(Map<String, dynamic> category) {
    final categoryName = category['name'].toString().toLowerCase().trim();
    final userRole = widget.userRole?.toLowerCase();

    // FOR ALUMNI: Competitions need sub-category selection
    if (userRole == 'alumni' && categoryName.contains('competition')) {
      _showCompetitionSubCategoryModal(category);
      return;
    }

    setState(() {
      _selectedCategory = category;
      _showCreatePost = true;

      final postOnlyCategories = [
        'internships',
        'jobs',
        'news',
        'internship',
        'job',
      ];
      final isPostOnly = postOnlyCategories.any(
        (cat) => categoryName.contains(cat),
      );

      // FOR STUDENTS: Events should default to Announcement
      if (userRole == 'student' && categoryName.contains('event')) {
        _postType = 'Announcement';
      } else {
        _postType = 'Post';
      }

      _selectedDateTime = null;
      _selectedImages.clear();
      _selectedFiles.clear();
      _competitionSubType = null;
    });
    _animationController.forward();
  }

  void _goBackToCategories() {
    _animationController.reverse().then((_) {
      setState(() {
        _showCreatePost = false;
        _selectedCategory = null;
        _postController.clear();
        _postType = 'Post';
        _selectedDateTime = null;
        _selectedImages.clear();
        _selectedFiles.clear();
        _competitionSubType = null; // ADD THIS LINE
      });
    });
  }

  Future<String?> _uploadFile(XFile file, String folder) async {
    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$folder/$fileName';

      await supabase.storage
          .from('Posts')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: false,
            ),
          );

      final publicUrl = supabase.storage.from('Posts').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print('Error uploading file: $e');
      if (e.toString().contains('Bucket not found') && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage bucket not configured. Post will be created without images.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _handlePost() async {
    if (_postController.text.trim().isEmpty) return;
    setState(() => _isUploading = true);

    try {
      String mediaUrl = widget.editPostData?['media_url'] ?? '';

      // ATTACHMENT FIX: Only upload new media if creating, lock if editing
      if (widget.editPostData == null && _selectedImages.isNotEmpty) {
        final image = _selectedImages.first;
        final bytes = await image.readAsBytes();
        final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = 'post_images/$fileName'; // Consistent path

        await supabase.storage.from('Posts').uploadBinary(filePath, bytes);
        mediaUrl = supabase.storage.from('Posts').getPublicUrl(filePath);
      }

      if (widget.editPostData != null) {
        // EDIT MODE: Only update text
        await supabase
            .from('posts')
            .update({
              'content': _postController.text.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('post_id', widget.editPostData!['post_id']);
      } else {
        // CREATE MODE: Insert full record
        await supabase.from('posts').insert({
          'author_id': widget.userId,
          'content': _postController.text.trim(),
          'media_url': mediaUrl,
          'category_id': _selectedCategory!['category_id'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      Navigator.pop(context, {'success': true});
    } catch (e) {
      print("Post error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // --- File/Image Selection Helpers ---

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'ppt', 'pptx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024)
      return '$bytes B';
    else if (bytes < 1024 * 1024)
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    else
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE63946),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFE63946),
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (selectedDateTime.isBefore(DateTime.now())) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a future date and time'),
              backgroundColor: Color(0xFFE63946),
            ),
          );
          return;
        }

        setState(() => _selectedDateTime = selectedDateTime);
      }
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    // This scaffold replaces the bottom sheet behavior for full screen modal feel
    return Scaffold(
      backgroundColor: Colors.transparent, // Or white if preferred
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _heightAnimation,
          builder: (context, child) {
            return Container(
              height: MediaQuery.of(context).size.height,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0),
                ),
              ),
              child: _showCreatePost
                  ? _buildCreatePostView()
                  : _buildCategorySelectionView(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategorySelectionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            children: [
              const Text(
                'Select Category',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the type of post you want to create',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Grid
        Expanded(
          child: _isLoadingCategories
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE63946)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildCategoryGrid(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),

        // Cancel
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    List<Widget> rows = [];
    for (int i = 0; i < _categories.length; i += 3) {
      List<Widget> rowChildren = [];
      for (int j = i; j < i + 3 && j < _categories.length; j++) {
        final category = _categories[j];
        rowChildren.add(
          Expanded(
            child: _CategoryCard(
              icon: _getCategoryIcon(category['name']),
              title: category['name'],
              gradient: _getCategoryGradient(j),
              onTap: () => _onCategorySelected(category),
            ),
          ),
        );
        if (j < i + 2 && j < _categories.length - 1) {
          rowChildren.add(const SizedBox(width: 16));
        }
      }
      rows.add(Row(children: rowChildren));
      if (i + 3 < _categories.length) {
        rows.add(const SizedBox(height: 16));
      }
    }
    return Column(children: rows);
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

  LinearGradient _getCategoryGradient(int index) {
    if (index % 2 == 0) {
      return LinearGradient(
        colors: [
          const Color(0xFFE63946).withOpacity(0.85),
          const Color(0xFFDC2F41).withOpacity(0.85),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [
          Colors.grey[600]!.withOpacity(0.85),
          Colors.grey[700]!.withOpacity(0.85),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Widget _buildCreatePostView() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _goBackToCategories,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black87,
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Create Post',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _createPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Upload',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // COMPETITION PARTNER REQUEST FORM (STUDENTS ONLY)
                      if (_isCompetitionRequest()) ...[
                        const Text(
                          'Find Competition Partners',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // COMPETITION TITLE
                        const Text(
                          'Competition Title',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _competitionTitleController,
                            decoration: InputDecoration(
                              hintText: "e.g., ICPC Regional Competition 2024",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // TEAM SIZE
                        const Text(
                          'Team Size',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _teamSizeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText:
                                  "How many members do you need? (e.g., 3)",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // NEEDED SKILLS
                        const Text(
                          'Needed Skills',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _neededSkillsController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  "e.g., Python, Data Structures, Algorithms",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // DESCRIPTION
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _descriptionController,
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText:
                                  "Describe what you're looking for in a teammate...",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ]
                      // CONDITIONAL LAYOUT BASED ON POST TYPE
                      else if (_postType == 'Announcement') ...[
                        // ... existing announcement code
                        // ============================================
                        // ANNOUNCEMENT LAYOUT
                        // ============================================
                        const Text(
                          'Schedule Announcement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // DATE PICKER
                        const Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate:
                                  _selectedDateTime ??
                                  DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFFE63946),
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black87,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (pickedDate != null) {
                              setState(() {
                                if (_selectedDateTime != null) {
                                  _selectedDateTime = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    _selectedDateTime!.hour,
                                    _selectedDateTime!.minute,
                                  );
                                } else {
                                  _selectedDateTime = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    9,
                                    0, // Default 9:00 AM
                                  );
                                }
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDateTime != null
                                      ? '${_selectedDateTime!.day}/${_selectedDateTime!.month}/${_selectedDateTime!.year}'
                                      : 'Select date',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _selectedDateTime != null
                                        ? Colors.black87
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // TIME PICKER
                        const Text(
                          'Select Time',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: _selectedDateTime != null
                                  ? TimeOfDay(
                                      hour: _selectedDateTime!.hour,
                                      minute: _selectedDateTime!.minute,
                                    )
                                  : TimeOfDay.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFFE63946),
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black87,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (pickedTime != null) {
                              setState(() {
                                final baseDate =
                                    _selectedDateTime ??
                                    DateTime.now().add(const Duration(days: 1));
                                _selectedDateTime = DateTime(
                                  baseDate.year,
                                  baseDate.month,
                                  baseDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDateTime != null
                                      ? '${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}'
                                      : 'Select time',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _selectedDateTime != null
                                        ? Colors.black87
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // DESCRIPTION FIELD
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _postController,
                            maxLines: 8,
                            decoration: InputDecoration(
                              hintText: "Enter announcement description...",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ] else ...[
                        // ============================================
                        // REGULAR POST LAYOUT
                        // ============================================
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _postController,
                                maxLines: null,
                                minLines: 4,
                                decoration: InputDecoration(
                                  hintText: "What's new?",
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 17,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.only(top: 8),
                                ),
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Image Previews
                        if (_selectedImages.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedImages.asMap().entries.map((
                              entry,
                            ) {
                              return FutureBuilder<Uint8List>(
                                future: entry.value.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFDC143C),
                                        ),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError || !snapshot.hasData) {
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.error),
                                    );
                                  }

                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          snapshot.data!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _removeImage(entry.key),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ],

                        // File Previews
                        if (_selectedFiles.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Column(
                            children: _selectedFiles.asMap().entries.map((
                              entry,
                            ) {
                              final file = entry.value;
                              final fileName = file.name;
                              final fileSize =
                                  file.bytes?.length ?? file.size ?? 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getFileIcon(fileName),
                                      color: const Color(0xFFE63946),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fileName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (fileSize > 0)
                                            Text(
                                              _formatFileSize(fileSize),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _removeFile(entry.key),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Controls
              // Bottom Controls (hide for competition requests)
              if (!_isCompetitionRequest())
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Selected Category Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              _selectedCategory?['name'] ?? 'Category',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Post Type Pill (Dropdown or Static)
                          if (_canShowPostTypeDropdown())
                            GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.white,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (context) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          title: const Text(
                                            'Post',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          trailing: _postType == 'Post'
                                              ? const Icon(
                                                  Icons.check,
                                                  color: Color(0xFFE63946),
                                                )
                                              : null,
                                          onTap: () {
                                            setState(() {
                                              _postType = 'Post';
                                              _selectedDateTime = null;
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        ListTile(
                                          title: const Text(
                                            'Announcement',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          trailing: _postType == 'Announcement'
                                              ? const Icon(
                                                  Icons.check,
                                                  color: Color(0xFFE63946),
                                                )
                                              : null,
                                          onTap: () {
                                            setState(() {
                                              _postType = 'Announcement';
                                              _selectedImages.clear();
                                              _selectedFiles.clear();
                                            });
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Attachments cleared. Announcements don\'t support media.',
                                                ),
                                                backgroundColor: Color(
                                                  0xFFE63946,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE63946),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _postType,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE63946),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _postType, // CHANGED FROM 'Post' to _postType
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          const Spacer(),

                          // Attachment Icons
                          if (_postType != 'Announcement') ...[
                            IconButton(
                              onPressed: _pickImages,
                              icon: Icon(
                                Icons.image_outlined,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                              tooltip: 'Add images',
                            ),
                            IconButton(
                              onPressed: _pickFiles,
                              icon: Icon(
                                Icons.attach_file,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                              tooltip: 'Attach files',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFE63946)),
                        SizedBox(height: 16),
                        Text(
                          'Uploading post...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Gradient gradient;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final int currentUserId;
  final String? currentUserName;
  final String? currentUserImage;

  const PostDetailsScreen({
    Key? key,
    required this.post,
    required this.currentUserId,
    this.currentUserName,
    this.currentUserImage,
  }) : super(key: key);

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  // Full list of comments from DB
  List<Map<String, dynamic>> allComments = [];
  // Filtered list of top-level comments (parents)
  List<Map<String, dynamic>> parentComments = [];

  bool isLoading = true;
  bool isPosting = false;

  // Reply logic
  int? replyingToCommentId;
  String? replyingToUserName;

  // Post interaction states
  bool isLiked = false;
  bool isReposted = false;
  int likeCount = 0;
  int commentCount = 0;
  int repostCount = 0;

  // Post Author Data
  String? postAuthorName;
  String? postAuthorImage;
  String? postAuthorRole;
  String? postAuthorDept;

  @override
  void initState() {
    super.initState();
    _loadPostAuthor();
    _loadComments();
    _loadPostInteractions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPostAuthor() async {
    try {
      final authorData = await supabase
          .from('users')
          .select('name, profile_image, role, department')
          .eq('user_id', widget.post['author_id'])
          .single();

      if (mounted) {
        setState(() {
          postAuthorName = authorData['name'];
          postAuthorImage = authorData['profile_image'];
          postAuthorRole = authorData['role'];
          postAuthorDept = authorData['department'];
        });
      }
    } catch (e) {
      print('Error loading post author: $e');
    }
  }

  Future<void> _loadPostInteractions() async {
    try {
      final postId = widget.post['post_id'];

      final responses = await Future.wait([
        // 0: Check Like
        supabase
            .from('likes')
            .select('like_id')
            .eq('user_id', widget.currentUserId)
            .eq('post_id', postId),
        // 1: Check Repost
        supabase
            .from('reposts')
            .select('id')
            .eq('user_id', widget.currentUserId)
            .eq('post_id', postId),
        // 2: Count Likes
        supabase.from('likes').select('like_id').eq('post_id', postId),
        // 3: Count Reposts
        supabase.from('reposts').select('id').eq('post_id', postId),
      ]);

      if (mounted) {
        setState(() {
          isLiked = (responses[0] as List).isNotEmpty;
          isReposted = (responses[1] as List).isNotEmpty;
          likeCount = (responses[2] as List).length;
          repostCount = (responses[3] as List).length;
        });
      }
    } catch (e) {
      print('Error loading interactions: $e');
    }
  }

  // --- MODIFIED TO WORK WITHOUT SQL FOREIGN KEYS & FIX THE ERROR ---
  Future<void> _loadComments() async {
    try {
      // 1. Fetch raw comments
      final commentsData = await supabase
          .from('comments')
          .select('*')
          .eq('post_id', widget.post['post_id'])
          .order('created_at', ascending: true);

      List<Map<String, dynamic>> loadedComments =
          List<Map<String, dynamic>>.from(commentsData);

      if (loadedComments.isNotEmpty) {
        // 2. Extract User IDs to fetch user info manually
        final userIds = loadedComments
            .map((c) => c['user_id'])
            .toSet()
            .toList();

        // 3. Fetch User Details (FIXED: Use .filter instead of .in_)
        final usersData = await supabase
            .from('users')
            .select('user_id, name, profile_image, role, department')
            .filter('user_id', 'in', userIds); // <--- THIS WAS THE FIX

        // 4. Create a Lookup Map for Users
        final userMap = {for (var u in usersData) u['user_id']: u};

        // 5. Merge User Data into Comments manually
        for (var comment in loadedComments) {
          // If user exists, attach data. If not, provide empty map to prevent crash
          comment['users'] =
              userMap[comment['user_id']] ??
              {
                'name': 'Unknown User',
                'profile_image': null,
                'role': null,
                'department': null,
              };
        }
      }

      if (mounted) {
        setState(() {
          allComments = loadedComments;
          // Filter parents
          parentComments = allComments
              .where((c) => c['parent_comment_id'] == null)
              .toList();
          commentCount = allComments.length;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => isPosting = true);

    try {
      // Logic to get next ID
      final lastComment = await supabase
          .from('comments')
          .select('comment_id')
          .order('comment_id', ascending: false)
          .limit(1);

      int nextCommentId = 1;
      if (lastComment.isNotEmpty) {
        nextCommentId = (lastComment[0]['comment_id'] as int) + 1;
      }

      await supabase.from('comments').insert({
        'comment_id': nextCommentId,
        'post_id': widget.post['post_id'],
        'user_id': widget.currentUserId,
        'content': _commentController.text.trim(),
        'parent_comment_id': replyingToCommentId,
        'created_at': DateTime.now().toIso8601String(),
      });

      _commentController.clear();

      setState(() {
        replyingToCommentId = null;
        replyingToUserName = null;
      });

      _commentFocusNode.unfocus();

      // IMPORTANT: Reload to see the new comment
      await _loadComments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted!'),
            backgroundColor: Color(0xFFDC143C),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      if (isLiked) {
        await supabase
            .from('likes')
            .delete()
            .eq('user_id', widget.currentUserId)
            .eq('post_id', widget.post['post_id']);
        setState(() {
          isLiked = false;
          likeCount = (likeCount - 1).clamp(0, 999999);
        });
      } else {
        final lastLike = await supabase
            .from('likes')
            .select('like_id')
            .order('like_id', ascending: false)
            .limit(1);
        int nextLikeId = 1;
        if (lastLike.isNotEmpty) {
          nextLikeId = (lastLike[0]['like_id'] as int) + 1;
        }

        await supabase.from('likes').insert({
          'user_id': widget.currentUserId,
          'post_id': widget.post['post_id'],
          'created_at': DateTime.now().toIso8601String(),
        });
        setState(() {
          isLiked = true;
          likeCount++;
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<void> _toggleRepost() async {
    try {
      if (isReposted) {
        await supabase
            .from('reposts')
            .delete()
            .eq('user_id', widget.currentUserId)
            .eq('post_id', widget.post['post_id']);
        setState(() {
          isReposted = false;
          repostCount = (repostCount - 1).clamp(0, 999999);
        });
      } else {
        final lastRepost = await supabase
            .from('reposts')
            .select('id')
            .order('id', ascending: false)
            .limit(1);
        int nextId = 1;
        if (lastRepost.isNotEmpty) {
          nextId = (lastRepost[0]['id'] as int) + 1;
        }

        await supabase.from('reposts').insert({
          'id': nextId,
          'user_id': widget.currentUserId,
          'post_id': widget.post['post_id'],
          'created_at': DateTime.now().toIso8601String(),
        });
        setState(() {
          isReposted = true;
          repostCount++;
        });
      }
    } catch (e) {
      print('Error toggling repost: $e');
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      // Cascading delete safety
      await supabase
          .from('comments')
          .delete()
          .eq('parent_comment_id', commentId);
      await supabase.from('comments').delete().eq('comment_id', commentId);

      await _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted'),
            backgroundColor: Color(0xFFDC143C),
          ),
        );
      }
    } catch (e) {
      print("Delete error: $e");
    }
  }

  Future<void> _editComment(int commentId, String currentContent) async {
    final controller = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await supabase
                    .from('comments')
                    .update({'content': controller.text.trim()})
                    .eq('comment_id', commentId);
                if (mounted) Navigator.pop(context);
                await _loadComments();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _replyToComment(int commentId, String userName) {
    setState(() {
      replyingToCommentId = commentId;
      replyingToUserName = userName;
    });
    _commentFocusNode.requestFocus();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Just now';
    try {
      // Parse as UTC and convert to local time
      final DateTime dt = DateTime.parse(date.toString()).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dt);

      // Handle future dates (clock skew)
      if (difference.isNegative) {
        return 'Just now';
      }

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (e) {
      print('Error formatting date: $e');
      return 'Just now';
    }
  }

  Future<bool> _isCommentLiked(int commentId) async {
    final result = await supabase
        .from('comment_likes')
        .select('comment_like_id')
        .eq('user_id', widget.currentUserId)
        .eq('comment_id', commentId);
    return result.isNotEmpty;
  }

  Future<int> _getCommentLikeCount(int commentId) async {
    final result = await supabase
        .from('comment_likes')
        .select('comment_like_id')
        .eq('comment_id', commentId);
    return result.length;
  }

  Future<void> _toggleCommentLike(int commentId) async {
    final isLiked = await _isCommentLiked(commentId);
    if (isLiked) {
      await supabase
          .from('comment_likes')
          .delete()
          .eq('user_id', widget.currentUserId)
          .eq('comment_id', commentId);
    } else {
      final last = await supabase
          .from('comment_likes')
          .select('comment_like_id')
          .order('comment_like_id', ascending: false)
          .limit(1);
      int nextId = 1;
      if (last.isNotEmpty) nextId = (last[0]['comment_like_id'] as int) + 1;

      await supabase.from('comment_likes').insert({
        'comment_like_id': nextId,
        'comment_id': commentId,
        'user_id': widget.currentUserId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    setState(() {}); // Trigger rebuild
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final user = comment['users'] ?? {};
    final userName = user['name'] ?? 'Unknown User';
    final userImage = user['profile_image'];
    final userRole = user['role'];
    final userDept = user['department'];
    final isMyComment = comment['user_id'] == widget.currentUserId;

    final replies = allComments
        .where((c) => c['parent_comment_id'] == comment['comment_id'])
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    (userImage != null && userImage.toString().isNotEmpty)
                    ? NetworkImage(userImage)
                    : null,
                child: (userImage == null || userImage.toString().isEmpty)
                    ? const Icon(Icons.person, size: 18, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (userRole != null || userDept != null)
                                Text(
                                  '${userRole ?? ''}${userRole != null && userDept != null ? ' | ' : ''}${userDept ?? ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          _formatDate(comment['created_at']),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment['content'] ?? '',
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FutureBuilder<int>(
                          future: _getCommentLikeCount(comment['comment_id']),
                          builder: (context, snap) {
                            if (!snap.hasData || snap.data == 0)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.thumb_up,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${snap.data}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () =>
                              _toggleCommentLike(comment['comment_id']),
                          child: FutureBuilder<bool>(
                            future: _isCommentLiked(comment['comment_id']),
                            builder: (context, snap) {
                              final liked = snap.data ?? false;
                              return Text(
                                'Like',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: liked
                                      ? const Color(0xFFDC143C)
                                      : Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () =>
                              _replyToComment(comment['comment_id'], userName),
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isMyComment)
                          InkWell(
                            onTap: () => _deleteComment(comment['comment_id']),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 12),
              child: Column(
                children: replies.map((reply) {
                  final rUser = reply['users'] ?? {};
                  final rName = rUser['name'] ?? 'Unknown';
                  final rImage = rUser['profile_image'];
                  final rIsMyComment = reply['user_id'] == widget.currentUserId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey[300],
                          backgroundImage:
                              (rImage != null && rImage.toString().isNotEmpty)
                              ? NetworkImage(rImage)
                              : null,
                          child: (rImage == null)
                              ? const Icon(Icons.person, size: 12)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    rName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(reply['created_at']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reply['content'],
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              if (rIsMyComment)
                                InkWell(
                                  onTap: () =>
                                      _deleteComment(reply['comment_id']),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
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
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  (postAuthorImage != null &&
                                      postAuthorImage!.isNotEmpty)
                                  ? NetworkImage(postAuthorImage!)
                                  : null,
                              child: (postAuthorImage == null)
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    postAuthorName ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(widget.post['created_at']),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.post['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.post['content'] ?? '',
                          style: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                        if (widget.post['media_url'] != null &&
                            widget.post['media_url'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.post['media_url'],
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              '$likeCount Likes',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$commentCount Comments',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$repostCount Reposts',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton.icon(
                              onPressed: _toggleLike,
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked
                                    ? const Color(0xFFDC143C)
                                    : Colors.grey,
                              ),
                              label: Text(
                                'Like',
                                style: TextStyle(
                                  color: isLiked
                                      ? const Color(0xFFDC143C)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _commentFocusNode.requestFocus(),
                              icon: const Icon(
                                Icons.comment_outlined,
                                color: Colors.grey,
                              ),
                              label: const Text(
                                'Comment',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _toggleRepost,
                              icon: Icon(
                                Icons.repeat,
                                color: isReposted
                                    ? const Color(0xFFDC143C)
                                    : Colors.grey,
                              ),
                              label: Text(
                                'Repost',
                                style: TextStyle(
                                  color: isReposted
                                      ? const Color(0xFFDC143C)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Comments',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFDC143C),
                              ),
                            ),
                          )
                        else if (allComments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No comments yet. Be the first!',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: parentComments.length,
                            itemBuilder: (context, index) {
                              return _buildCommentItem(parentComments[index]);
                            },
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (replyingToUserName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    color: Colors.grey[100],
                    child: Row(
                      children: [
                        Text(
                          'Replying to $replyingToUserName',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() {
                            replyingToCommentId = null;
                            replyingToUserName = null;
                          }),
                          child: const Icon(Icons.close, size: 14),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (widget.currentUserImage != null)
                          ? NetworkImage(widget.currentUserImage!)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          decoration: const InputDecoration(
                            hintText: 'Post a comment...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    isPosting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFDC143C),
                            ),
                          )
                        : IconButton(
                            onPressed: _postComment,
                            icon: const Icon(
                              Icons.send,
                              color: Color(0xFFDC143C),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
