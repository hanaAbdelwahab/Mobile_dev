import 'package:flutter/material.dart';
import 'send_post_dialog.dart';
import 'chat_room_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';


final supabase = Supabase.instance.client;

class OtherUserProfilePage extends StatefulWidget {
  final String userId;
  final String currentUserId;

  const OtherUserProfilePage({
    super.key,
    required this.userId,
    required this.currentUserId,
  });

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage>
    with TickerProviderStateMixin {
  
  // ✅ EXACT COLORS FROM MYPROFILE.DART
  static const Color primaryRed = Color(0xFFE63946);
  static const Color darkRed = Color(0xFFDC143C);
  Map<String, bool> savedPosts = {};
  bool isFollowing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
   late final String mockCurrentUserId;


  Map<String, dynamic>? user;
  List<Map<String, dynamic>> userPosts = [];
  List<Map<String, dynamic>> userComments = [];
  List<Map<String, dynamic>> userReposts = [];
  List<Map<String, dynamic>> allUserComments = [];
List<Map<String, dynamic>> allUserReposts = [];

  bool loading = true;
  int followerCount = 0;
  int followingCount = 0;

  // ✅ TAB CONTROLLER FOR ACTIVITY SECTION (EXACT FROM MYPROFILE)
  late TabController _activityTabController;
  int _selectedActivityTab = 0;

  // ✅ TRACK WHICH POSTS HAVE COMMENT SECTION OPEN
  Map<String, bool> showCommentInput = {};

  // Track endorsed skills
  Map<String, bool> endorsedSkills = {};

  // Current user data for notifications
  String? currentUsername;
  String? currentUserProfileUrl;

  @override
  void initState() {
    super.initState();
    mockCurrentUserId = widget.currentUserId;
    // ✅ INITIALIZE TAB CONTROLLER (EXACT FROM MYPROFILE)
    _activityTabController = TabController(length: 3, vsync: this);
    _activityTabController.addListener(() {
      if (_activityTabController.indexIsChanging) {
        setState(() => _selectedActivityTab = _activityTabController.index);
      }
    });
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _initializeData();
  }

  Future<void> _initializeData() async {
    await fetchCurrentUserData();
    await fetchUserAndPosts();
  }
Future<void> fetchCurrentUserData() async {
  try {
    // Check if using mock user
    if (mockCurrentUserId == "11111111-1111-1111-1111-111111111111") {
      setState(() {
        currentUsername = "Ibrahim";
        currentUserProfileUrl = null;
      });
      print('✅ Using mock user: $currentUsername');
      return;
    }

    // FIX: Use correct column names (name instead of username, user_id instead of id)
    final userData = await supabase
        .from('users')
        .select('name, profile_image') // Changed from username and profile_image_url
        .eq('user_id', int.parse(mockCurrentUserId)) // Changed from id to user_id
        .single();

    setState(() {
      currentUsername = userData['name'] ?? 'Someone'; // Changed from username to name
      currentUserProfileUrl = userData['profile_image']; // Changed from profile_image_url to profile_image
    });

    print('✅ Current user loaded: $currentUsername');
  } catch (e) {
    print('⚠️ Error fetching current user data: $e');
    setState(() {
      currentUsername = 'Someone';
    });
  }
}
  @override
  void dispose() {
    _activityTabController.dispose(); // ✅ DISPOSE TAB CONTROLLER
    _animationController.dispose();
    super.dispose();
  }

   Future<void> createNotification({
    required String type,
    required String title,
    required String message,
    required String icon,
    String? postId,
  }) async {
    try {
      final username = currentUsername ?? 'Someone';

      final notificationData = {
        'user_id': widget.userId,
        'actor_id': mockCurrentUserId,
        'type': type,
        'title': title,
        'message': message.replaceAll('null', username),
        'icon': icon,
        'is_read': false,
        'profile_url': currentUserProfileUrl,
      };

      if (type == 'follow_request') {
        notificationData['status'] = null;
      }

      await supabase.from('notifications').insert(notificationData);

      print('✅ Notification created: $type - $message');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  Future<void> checkIfFollowing() async {
    try {
      final response = await supabase
          .from('follows')
          .select()
          .eq('follower_id', mockCurrentUserId)
          .eq('following_id', widget.userId)
          .maybeSingle();

      setState(() {
        isFollowing = response != null;
      });
    } catch (e) {
      print("⚠️ Error checking follow status: $e");
      setState(() => isFollowing = false);
    }
  }

  Future<void> fetchFollowerCounts() async {
    try {
      final followersData = await supabase
          .from('follows')
          .select()
          .eq('following_id', widget.userId);

      final followingData = await supabase
          .from('follows')
          .select()
          .eq('follower_id', widget.userId);

      setState(() {
        followerCount = (followersData as List).length;
        followingCount = (followingData as List).length;
      });

      print('👥 Followers: $followerCount, Following: $followingCount');
    } catch (e) {
      print('⚠️ Error fetching follower counts: $e');
      setState(() {
        followerCount = 0;
        followingCount = 0;
      });
    }
  }

  Future<void> toggleFollow() async {
    try {
      if (isFollowing) {
        await supabase.from('follows').delete().match({
          'follower_id': mockCurrentUserId,
          'following_id': widget.userId,
        });
        print('✅ Unfollowed');
      } else {
        await supabase.from('follows').insert({
          'follower_id': mockCurrentUserId,
          'following_id': widget.userId,
        });

        final username = currentUsername ?? 'Someone';

        await createNotification(
          type: 'follow_request',
          title: 'New Follower',
          message: '$username started following you',
          icon: 'person',
        );

        print('✅ Followed');
      }

      setState(() {
        isFollowing = !isFollowing;
      });

      await fetchFollowerCounts();
    } catch (e) {
      print("❌ Error toggling follow: $e");
      setState(() => isFollowing = !isFollowing);
    }
  }

Future<void> fetchUserAndPosts() async {
  try {
    print('🔍 Fetching user: ${widget.userId}');

    // Fetch user basic info
    final fetchedUser = await supabase
        .from('users')
        .select('user_id,name,email,role,profile_image,cover_image,department,bio,academic_year')
        .eq('user_id', int.parse(widget.userId))
        .single();

    print('✅ User: ${fetchedUser['name']}');
    print('📝 Bio: ${fetchedUser['bio'] ?? "No bio"}');

    // ✅ Fetch experience from experiences table
    List<dynamic> experienceList = [];
    try {
      final expData = await supabase
          .from('experiences')
          .select('*')
          .eq('user_id', int.parse(widget.userId))
          .order('start_date', ascending: false);
      experienceList = expData as List;
      print('✅ Loaded ${experienceList.length} experiences');
    } catch (e) {
      print('⚠️ Error loading experiences: $e');
    }

    // ✅ Fetch skills from skills table
    List<dynamic> skillsList = [];
    try {
      final skillsData = await supabase
          .from('skills')
          .select('*')
          .eq('user_id', int.parse(widget.userId))
          .order('created_at', ascending: false);
      skillsList = skillsData as List;
      print('✅ Loaded ${skillsList.length} skills');
    } catch (e) {
      print('⚠️ Error loading skills: $e');
    }

    // ✅ LOAD POSTS
    await _loadUserPosts();

    // ✅ LOAD COMMENTS
    await _loadUserComments();

    // ✅ LOAD REPOSTS
    await _loadUserReposts();
    await _loadSavedPostsStatus();

    setState(() {
      allUserComments = [];
      allUserReposts = [];
      
      user = {
        ...fetchedUser,
        'experience': experienceList,
        'skills': skillsList,
      };
      loading = false;
    });

    await checkIfFollowing();
    await fetchFollowerCounts();

    // Load skill endorsements if skills exist
    if (skillsList.isNotEmpty) {
      final Map<String, bool> endorsementStatus = {};

      for (var skill in skillsList) {
        final skillName = skill['name'];
        if (skillName != null) {
          try {
            final endorsement = await supabase
                .from('skill_endorsements')
                .select()
                .eq('skill_name', skillName)
                .eq('endorsed_user_id', int.parse(widget.userId))
                .eq('endorser_user_id', int.parse(mockCurrentUserId))
                .maybeSingle();

            endorsementStatus[skillName] = endorsement != null;
          } catch (e) {
            print('⚠️ Error checking endorsement for $skillName: $e');
            endorsementStatus[skillName] = false;
          }
        }
      }

      setState(() {
        endorsedSkills = endorsementStatus;
      });

      print('✅ Loaded endorsement status: $endorsedSkills');
    }

    _animationController.forward();
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack: $stackTrace');

    setState(() {
      user = {
        "name": "Unknown",
        "role": "Unknown",
        "user_id": int.parse(widget.userId),
        "bio": null,
        "experience": [],
        "skills": [],
      };
      userPosts = [];
      userComments = [];
      userReposts = [];
      loading = false;
    });
  }
}// ✅ LOAD POSTS (EXACT FROM MYPROFILE)
 Future<void> _loadUserPosts() async {
  try {
    final postsResponse = await supabase
        .from('posts')
        .select('post_id, content, created_at, author_id') // Use correct column names
        .eq('author_id', int.parse(widget.userId)) // Parse to int
        .order('created_at', ascending: false);

    print('📊 Posts found: ${(postsResponse as List).length}');

    final List<Map<String, dynamic>> transformedPosts = [];

    for (var post in postsResponse) {
      final postId = post['post_id']; // Changed from id

      // Rest of your code...
      final likesData = await supabase.from('likes').select().eq('post_id', postId);
      final likeCount = (likesData as List).length;

      final userLike = await supabase
          .from('likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', int.parse(mockCurrentUserId)) // Parse to int
          .maybeSingle();

      final commentsData =
          await supabase.from('comments').select().eq('post_id', postId);
      final commentCount = (commentsData as List).length;

      final repostsData =
          await supabase.from('reposts').select().eq('post_id', postId);
      final repostCount = (repostsData as List).length;

      final userRepost = await supabase
          .from('reposts')
          .select()
          .eq('post_id', postId)
          .eq('user_id', int.parse(mockCurrentUserId)) // Parse to int
          .maybeSingle();

      transformedPosts.add({
        "id": postId,
        "text": post['content'] ?? 'No content',
        "image": false,
        "reposter": "",
        "comments": commentCount,
        "likes": likeCount,
        "reposts": repostCount,
        "isLiked": userLike != null,
        "isReposted": userRepost != null,
        "postComments": [],
        "created_at": post['created_at'],
      });
    }

    if (mounted) {
      setState(() {
        userPosts = transformedPosts;
      });
    }
  } catch (e) {
    print('❌ Error loading posts: $e');
    if (mounted) {
      setState(() {
        userPosts = [];
      });
    }
  }
}
  // ✅ NEW METHOD 1: Load ALL comments user made across platform

// ✅ NEW METHOD 2: Load ALL reposts user made across platform
Future<void> _loadAllUserReposts() async {
  try {
    final data = await supabase
        .from('reposts')
        .select('''
        id,
        created_at,
        user_id,
        post_id,
        posts!inner(id, content, user_id, created_at, users!inner(username))
      ''')
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        allUserReposts = List<Map<String, dynamic>>.from(data);
      });
      print('✅ Loaded ${allUserReposts.length} reposts across platform');
    }
  } catch (e) {
    print('❌ Error loading all reposts: $e');
    if (mounted) {
      setState(() {
        allUserReposts = [];
      });
    }
  }
}

  // ✅ LOAD COMMENTS (EXACT FROM MYPROFILE)
  Future<void> _loadUserComments() async {
    try {
      final data = await supabase
          .from('comments')
          .select('''
          *,
          posts!inner(id, content, user_id)
        ''')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          userComments = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) {
        setState(() {
          userComments = [];
        });
      }
    }
  }

  // ✅ LOAD REPOSTS (EXACT FROM MYPROFILE)
  Future<void> _loadUserReposts() async {
    try {
      final data = await supabase
          .from('reposts')
          .select('''
          *,
          posts!inner(id, content, user_id, created_at)
        ''')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          userReposts = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Error loading reposts: $e');
      if (mounted) {
        setState(() {
          userReposts = [];
        });
      }
    }
  }

  Future<void> _handleLike(int postIndex) async {
    final post = userPosts[postIndex];
    final postId = post['id'];
    final isCurrentlyLiked = post['isLiked'];

    try {
      if (isCurrentlyLiked) {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', mockCurrentUserId);

        setState(() {
          userPosts[postIndex]['isLiked'] = false;
          userPosts[postIndex]['likes'] = (userPosts[postIndex]['likes'] as int) - 1;
        });
      } else {
        await supabase.from('likes').insert({
          'post_id': postId,
          'user_id': mockCurrentUserId,
        });

        final username = currentUsername ?? 'Someone';

        await createNotification(
          type: 'like',
          title: 'New Like',
          message: '$username liked your post',
          icon: 'favorite',
          postId: postId,
        );

        setState(() {
          userPosts[postIndex]['isLiked'] = true;
          userPosts[postIndex]['likes'] = (userPosts[postIndex]['likes'] as int) + 1;
        });
      }
    } catch (e) {
      print('❌ Error toggling like: $e');
    }
  }

  Future<void> _handleRepost(int postIndex) async {
    final post = userPosts[postIndex];
    final postId = post['id'];
    final isCurrentlyReposted = post['isReposted'];

    try {
      if (isCurrentlyReposted) {
        await supabase
            .from('reposts')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', mockCurrentUserId);

        setState(() {
          userPosts[postIndex]['isReposted'] = false;
          userPosts[postIndex]['reposts'] = (userPosts[postIndex]['reposts'] as int) - 1;
        });
      } else {
        await supabase.from('reposts').insert({
          'post_id': postId,
          'user_id': mockCurrentUserId,
        });

        final username = currentUsername ?? 'Someone';

        await createNotification(
          type: 'repost',
          title: 'New Repost',
          message: '$username reposted your post',
          icon: 'repeat',
          postId: postId,
        );

        setState(() {
          userPosts[postIndex]['isReposted'] = true;
          userPosts[postIndex]['reposts'] = (userPosts[postIndex]['reposts'] as int) + 1;
        });
      }
      
      // Reload reposts
      await _loadUserReposts();
    } catch (e) {
      print('❌ Error toggling repost: $e');
    }
  }

  Future<void> _handleSendPost(Map<String, dynamic> postData) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SendPostDialog(
        postId: postData['id'],
        postContent: postData['text'],
      ),
    );

    if (result == true) {
      print('✅ Post sent successfully');
    }
  }
  Future<bool> _isPostSaved(String postId) async {
  try {
    final result = await supabase
        .from('saved_posts')
        .select('id')
        .eq('user_id', mockCurrentUserId)
        .eq('post_id', postId)
        .maybeSingle();
    
    return result != null;
  } catch (e) {
    print('❌ Error checking if post is saved: $e');
    return false;
  }
}
/// Load saved status for all posts
Future<void> _loadSavedPostsStatus() async {
  try {
    for (var post in userPosts) {
      final postId = post['id'];
      final isSaved = await _isPostSaved(postId);
      setState(() {
        savedPosts[postId] = isSaved;
      });
    }
  } catch (e) {
    print('❌ Error loading saved posts status: $e');
  }
}
Future<void> _toggleSavePost(String postId) async {
  try {
    final isSaved = savedPosts[postId] ?? false;
    
    if (isSaved) {
      // Unsave the post
      await supabase
          .from('saved_posts')
          .delete()
          .eq('user_id', mockCurrentUserId)
          .eq('post_id', postId);
      
      setState(() {
        savedPosts[postId] = false;
      });
      
      _showSuccess('Post removed from saved');
      print('✅ Post unsaved: $postId');
    } else {
      // Save the post
      await supabase.from('saved_posts').insert({
        'user_id': mockCurrentUserId,
        'post_id': postId,
      });
      
      setState(() {
        savedPosts[postId] = true;
      });
      
      _showSuccess('Post saved successfully');
      print('✅ Post saved: $postId');
    }
  } catch (e) {
    print('❌ Error toggling save post: $e');
    _showError('Failed to save post: $e');
  }
}

/// Show menu when 3 dots are clicked
void _showPostMenu(BuildContext context, String postId) {
  final isSaved = savedPosts[postId] ?? false;
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Save/Unsave option
          ListTile(
            leading: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: const Color(0xFFE63946), // Using exact color instead of primaryRed
            ),
            title: Text(
              isSaved ? 'Unsave post' : 'Save post',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleSavePost(postId);
            },
          ),
          
          // Report option
          
          
          // Cancel button
          const SizedBox(height: 8),
          const Divider(),
          ListTile(
            title: const Text(
              'Cancel',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
  
}


  void _onBackTapped(BuildContext context) => Navigator.of(context).pop();

  Future<void> _onMessageTapped() async {
    try {
      print('💬 Starting chat with user: ${widget.userId}');

      final existingConversations = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', mockCurrentUserId);

      String? conversationId;

      for (var conv in existingConversations) {
        final otherParticipants = await supabase
            .from('conversation_participants')
            .select()
            .eq('conversation_id', conv['conversation_id'])
            .eq('user_id', widget.userId)
            .maybeSingle();

        if (otherParticipants != null) {
          conversationId = conv['conversation_id'];
          print('✅ Found existing conversation: $conversationId');
          break;
        }
      }

      if (conversationId == null) {
        print('📝 Creating new conversation...');

        final newConversation =
            await supabase.from('conversations').insert({}).select().single();

        conversationId = newConversation['id'];

        await supabase.from('conversation_participants').insert([
          {
            'conversation_id': conversationId,
            'user_id': mockCurrentUserId,
          },
          {
            'conversation_id': conversationId,
            'user_id': widget.userId,
          },
        ]);

        print('✅ New conversation created: $conversationId');
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              conversationId: conversationId!,
              otherUserName: user!['name'] ?? 'Unknown',
              otherUserId: widget.userId,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error starting chat: $e');
      if (mounted) {
        _showError('Error starting chat: $e');
      }
    }
  }

  // ✅ COPIED FROM MYPROFILE - Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ✅ COPIED FROM MYPROFILE - Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ✅ COPIED FROM MYPROFILE - Format date
  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m';
      if (difference.inHours < 24) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}d';
      if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w';

      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return '';
    }
  }

  // ✅ Helper method to combine and sort comments/reposts
List<Widget> _buildCombinedActivity() {
  List<Map<String, dynamic>> combinedActivity = [];
  
  // Add all comments with type indicator
  for (var comment in allUserComments) {
    combinedActivity.add({
      'type': 'comment',
      'data': comment,
      'created_at': comment['created_at'],
    });
  }
  
  // Add all reposts with type indicator
  for (var repost in allUserReposts) {
    combinedActivity.add({
      'type': 'repost',
      'data': repost,
      'created_at': repost['created_at'],
    });
  }
  
  // Sort by date (most recent first)
  combinedActivity.sort((a, b) {
    final aDate = DateTime.parse(a['created_at']);
    final bDate = DateTime.parse(b['created_at']);
    return bDate.compareTo(aDate);
  });

  return combinedActivity.map((activity) {
    if (activity['type'] == 'comment') {
      return _buildAllCommentItem(activity['data']);
    } else {
      return _buildAllRepostItem(activity['data']);
    }
  }).toList();
}

// ✅ Display individual comment item
Widget _buildAllCommentItem(Map<String, dynamic> comment) {
  final post = comment['posts'];
  final postContent = post?['content'] ?? 'Post not available';
  final postAuthor = post?['users']?['username'] ?? 'Unknown';
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: primaryRed.withOpacity(0.1),
              child: Icon(Icons.comment, size: 16, color: primaryRed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Commented on ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      Text('$postAuthor\'s post', style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text(_formatDate(comment['created_at']), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(comment['content'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.article_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(postContent, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ✅ Display individual repost item
Widget _buildAllRepostItem(Map<String, dynamic> repost) {
  final post = repost['posts'];
  final postContent = post?['content'] ?? 'Post not available';
  final postAuthor = post?['users']?['username'] ?? 'Unknown';
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green.withOpacity(0.1),
              child: Icon(Icons.repeat, size: 16, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Reposted ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      Text('$postAuthor\'s post', style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text(_formatDate(repost['created_at']), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.green,
                    child: Text(postAuthor[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(postAuthor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Text(postContent, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F2EF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: primaryRed,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2EF),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // ✅ COPIED APPBAR STYLE
            SliverAppBar(
              pinned: false,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
                onPressed: () => _onBackTapped(context),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                children: [
                  // ✅ COPIED PROFILE HEADER CARD STYLE
                  Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        // ✅ Cover area with gradient (EXACT STYLE FROM MYPROFILE)
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Cover image with gradient
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primaryRed.withOpacity(0.85),
                                    darkRed,
                                  ],
                                ),
                              ),
                            ),
                            // Avatar positioned at bottom of cover
                            Positioned(
                              left: 16,
                              bottom: -50,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: primaryRed,
                                  child: Text(
                                    (user!['name'] ?? 'U') // Changed from username
      .split(' ')
      .map((e) => e.isNotEmpty ? e[0] : '')
      .take(2)
      .join()
      .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 56),

                        // User info section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name and headline
                              Text(
                                user!['name'] ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user!['role'] ?? 'No Role',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Connections count
                              InkWell(
                                onTap: () {
                                  print(
                                      '👥 Followers: $followerCount, Following: $followingCount');
                                },
                                child: Text(
                                  followerCount == 0
                                      ? "No connections"
                                      : "$followerCount connection${followerCount != 1 ? 's' : ''}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ✅ ACTION BUTTONS - EXACT STYLE FROM MYPROFILE
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: toggleFollow,
                                      icon: Icon(
                                        isFollowing
                                            ? Icons.check
                                            : Icons.person_add_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                          isFollowing ? "Following" : "Connect"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing
                                            ? Colors.white
                                            : primaryRed,
                                        foregroundColor:
                                            isFollowing ? primaryRed : Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          side: isFollowing
                                              ? BorderSide(
                                                  color: primaryRed, width: 1.5)
                                              : BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _onMessageTapped,
                                      icon: const Icon(Icons.mail_outline,
                                          size: 18),
                                      label: const Text("Message"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryRed,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        side:
                                            BorderSide(color: primaryRed, width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // About section card
                 if (user!['bio'] != null && (user!['bio'] as String).isNotEmpty)
  _buildAboutCard(),

const SizedBox(height: 8),

// ✅✅✅ NEW: ALL COMMENTS AND REPOSTS SECTION
_buildAllActivityCard(),

const SizedBox(height: 8),

// ✅✅✅ ACTIVITY SECTION WITH TABS
_buildActivityCard(),

                  const SizedBox(height: 8),

                  // Experience section
                  if (user!['experience'] != null &&
                      (user!['experience'] as List).isNotEmpty)
                    _buildExperienceCard(),


                  const SizedBox(height: 8),

                  // Skills section
                  if (user!['skills'] != null &&
                      (user!['skills'] as List).isNotEmpty)
                    _buildSkillsCard(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ EXACT CARD STYLE FROM MYPROFILE
  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user!['bio'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ✅✅✅ EXACT ACTIVITY CARD WITH TABS FROM MYPROFILE ✅✅✅
  Widget _buildActivityCard() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${followerCount} followers',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // ✅ TAB BAR (EXACT FROM MYPROFILE)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: TabBar(
              controller: _activityTabController,
              indicatorColor: primaryRed,
              indicatorWeight: 3,
              labelColor: primaryRed,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Posts'),
                Tab(text: 'Comments'),
                Tab(text: 'Reposts'),
              ],
            ),
          ),

          // ✅ TAB CONTENT (EXACT FROM MYPROFILE)
          SizedBox(
            height: 400, // Fixed height for tab content
            child: TabBarView(
              controller: _activityTabController,
              children: [
                // Posts Tab
                _buildPostsTab(),
                // Comments Tab
                _buildCommentsTab(),
                // Reposts Tab
                _buildRepostsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ POSTS TAB (EXACT FROM MYPROFILE)
  Widget _buildPostsTab() {
    if (userPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                "No posts yet",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: userPosts.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
      itemBuilder: (context, index) {
        return _buildPostCard(userPosts[index], index);
      },
    );
  }

  // ✅ COMMENTS TAB (EXACT FROM MYPROFILE)
  Widget _buildCommentsTab() {
    if (userComments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.comment_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                "No comments yet",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: userComments.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
      itemBuilder: (context, index) {
        final comment = userComments[index];
        return _buildCommentCard(comment);
      },
    );
  }

  // ✅ REPOSTS TAB (EXACT FROM MYPROFILE)
  Widget _buildRepostsTab() {
    if (userReposts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.repeat,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                "No reposts yet",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: userReposts.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
      itemBuilder: (context, index) {
        final repost = userReposts[index];
        return _buildRepostCard(repost);
      },
    );
  }

  // ✅ COMMENT CARD (EXACT FROM MYPROFILE)
  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final post = comment['posts'];
    final postContent = post?['content'] ?? 'Post not available';
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryRed,
                child: Text(
                  (user!['name'] ?? 'U') // Changed from username
      .split(' ')
      .map((e) => e.isNotEmpty ? e[0] : '')
      .take(2)
      .join()
      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user!['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      _formatDate(comment['created_at']),
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
          
          // Comment content
          Text(
            comment['content'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Original post reference
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.article_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    postContent,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ REPOST CARD (EXACT FROM MYPROFILE)
  Widget _buildRepostCard(Map<String, dynamic> repost) {
    final post = repost['posts'];
    final postContent = post?['content'] ?? 'Post not available';
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repost indicator
          Row(
            children: [
              Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${user!['name']} reposted',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(repost['created_at']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Original post
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: primaryRed,
                      child: Text(
                        'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Original Author',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  postContent,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ POST CARD WITH INLINE COMMENTS (NO SEPARATE PAGE)
  Widget _buildPostCard(Map<String, dynamic> postData, int postIndex) {
    final String postText = postData['text'] ?? 'No content';
    final int displayedLikeCount = postData['likes'] ?? 0;
    final int displayedRepostCount = postData['reposts'] ?? 0;
    final int displayedCommentCount = postData['comments'] ?? 0;
    final bool isPostLiked = postData['isLiked'] ?? false;
    final bool isPostReposted = postData['isReposted'] ?? false;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // POST HEADER
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryRed,
                  child: Text(
                    (user!['name'] ?? 'U')
                        .split(' ')
                        .map((e) => e.isNotEmpty ? e[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user!['name'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        user!['role'] ?? 'Member',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  color: Colors.grey[600],
                   onPressed: () => _showPostMenu(context, postData['id']),
                ),
              ],
            ),
          ),

          // POST CONTENT
          if (postText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                postText,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ✅ SQUARE POST IMAGE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: postData['image'] != null && postData['image'] != false
                    ? Image.network(
                        postData['image'],
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(
                            Icons.article_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ STATS BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(
                    '$displayedLikeCount Like${displayedLikeCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$displayedCommentCount Comment${displayedCommentCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$displayedRepostCount Repost${displayedRepostCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ✅ ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: isPostLiked ? Icons.favorite : Icons.favorite_border,
                  label: "Like",
                  onTap: () => _handleLike(postIndex),
                  isActive: isPostLiked,
                ),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: "Comment",
                  onTap: () {
                    // ✅ TOGGLE COMMENT INPUT BOX
                    setState(() {
                      showCommentInput[postData['id']] = 
                          !(showCommentInput[postData['id']] ?? false);
                    });
                  },
                  isActive: false,
                ),
                _buildActionButton(
                  icon: Icons.repeat,
                  label: "Repost",
                  onTap: () => _handleRepost(postIndex),
                  isActive: isPostReposted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ✅✅✅ COMMENTS SECTION DIRECTLY BELOW POST ✅✅✅
          FutureBuilder<List<Map<String, dynamic>>>(
  future: _loadPostComments(postData['id']),
  builder: (context, snapshot) {
    final comments = snapshot.data ?? [];
    final hasComments = comments.isNotEmpty;
    final shouldShowInput = showCommentInput[postData['id']] ?? false;

    // 🔹 LIMIT COMMENTS
    final int maxCommentsToShow = 2;
    final limitedComments = comments.take(maxCommentsToShow).toList();

    // HIDE IF: No comments AND user hasn't clicked Comment button
    if (!hasComments && !shouldShowInput) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comments header
          if (hasComments)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Comments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),

          // LIMITED Comments list
          ...limitedComments.map((comment) {
            return _buildCommentItem(comment);
          }).toList(),

          // View more comments text
          if (comments.length > maxCommentsToShow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'View more comments...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),

          // Comment input
          _buildCommentInput(postData['id']),
        ],
      ),
    );
  },
),

        ],
      ),
    );
  }

  // ✅ LOAD COMMENTS FOR A SPECIFIC POST
  Future<List<Map<String, dynamic>>> _loadPostComments(String postId) async {
    try {
      final response = await supabase
          .from('comments')
          .select('id, content, created_at, user_id, users(username)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (response as List).map((comment) {
        return {
          'id': comment['id'],
          'content': comment['content'],
          'created_at': comment['created_at'],
          'user_id': comment['user_id'],
          'username': comment['users']['username'] ?? 'Unknown',
        };
      }).toList();
    } catch (e) {
      print('❌ Error loading comments: $e');
      return [];
    }
  }

  // ✅ BUILD COMMENT ITEM (EXACT STYLE FROM SCREENSHOT)
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final String username = comment['username'];
    final String content = comment['content'];
    final String commentId = comment['id'];
    final String userId = comment['user_id'];
    final String timestamp = comment['created_at'] ?? '';
    final bool isMyComment = userId == mockCurrentUserId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: isMyComment ? primaryRed : Colors.green,
            child: Text(
              username.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and timestamp
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'Student | cs',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDate(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Comment content
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                // ✅ LIKE AND REPLY BUTTONS (NOW FUNCTIONAL)
                Row(
                  children: [
                    // ✅ LIKE BUTTON WITH COUNT
                    FutureBuilder<Map<String, dynamic>>(
                      future: _getCommentLikeStatus(commentId),
                      builder: (context, snapshot) {
                        final isLiked = snapshot.data?['isLiked'] ?? false;
                        final likeCount = snapshot.data?['count'] ?? 0;
                        
                        return Row(
                          children: [
                            InkWell(
                              onTap: () async {
                                await _toggleCommentLike(commentId);
                                setState(() {}); // Refresh to show new like status
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      size: 16,
                                      color: isLiked ? primaryRed : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Like',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isLiked ? primaryRed : Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (likeCount > 0) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '($likeCount)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    // ✅ REPLY BUTTON
                    InkWell(
                      onTap: () {
                        _showReplyDialog(commentId, username);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (isMyComment) ...[
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[600]),
                        onPressed: () {
                          _deleteComment(commentId);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ GET COMMENT LIKE STATUS AND COUNT
  Future<Map<String, dynamic>> _getCommentLikeStatus(String commentId) async {
    try {
      // Get total like count
      final likesData = await supabase
          .from('comment_likes')
          .select('id')
          .eq('comment_id', commentId);
      
      final count = (likesData as List).length;

      // Check if current user liked it
      final userLike = await supabase
          .from('comment_likes')
          .select('id')
          .eq('comment_id', commentId)
          .eq('user_id', mockCurrentUserId)
          .maybeSingle();

      return {
        'isLiked': userLike != null,
        'count': count,
      };
    } catch (e) {
      print('❌ Error getting comment like status: $e');
      return {'isLiked': false, 'count': 0};
    }
  }

  // ✅ TOGGLE COMMENT LIKE
  Future<void> _toggleCommentLike(String commentId) async {
    try {
      // Check if already liked
      final existingLike = await supabase
          .from('comment_likes')
          .select('id')
          .eq('comment_id', commentId)
          .eq('user_id', mockCurrentUserId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike
        await supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', mockCurrentUserId);
        
        print('❤️ Unliked comment');
      } else {
        // Like
        await supabase.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': mockCurrentUserId,
        });
        
        print('❤️ Liked comment');
        _showSuccess('Liked!');
      }
    } catch (e) {
      print('❌ Error toggling comment like: $e');
      _showError('Failed to like comment');
    }
  }

  // ✅ SHOW REPLY DIALOG
  void _showReplyDialog(String parentCommentId, String replyingTo) {
    final TextEditingController replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reply to $replyingTo',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: replyController,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Write your reply...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryRed, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) return;

              try {
                // ✅ Get the post_id from the parent comment
                final parentComment = await supabase
                    .from('comments')
                    .select('post_id')
                    .eq('id', parentCommentId)
                    .single();

                // ✅ Add reply as a regular comment with @mention
                await supabase.from('comments').insert({
                  'post_id': parentComment['post_id'],
                  'user_id': mockCurrentUserId,
                  'content': '@$replyingTo ${replyController.text.trim()}',
                });

                Navigator.pop(context);
                setState(() {}); // Refresh
                _showSuccess('Reply posted!');
              } catch (e) {
                print('❌ Reply error: $e');
                Navigator.pop(context);
                _showError('Failed to post reply');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Reply',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ COMMENT INPUT BOX (EXACT STYLE FROM SCREENSHOT)
  Widget _buildCommentInput(String postId) {
    final TextEditingController controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: primaryRed,
            child: Text(
              (user!['name'] ?? 'U')
                  .split(' ')
                  .map((e) => e.isNotEmpty ? e[0] : '')
                  .take(2)
                  .join()
                  .toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: TextStyle(color: Colors.black45, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, size: 20, color: primaryRed),
                    onPressed: () async {
                      if (controller.text.trim().isEmpty) return;

                      try {
                        await supabase.from('comments').insert({
                          'post_id': postId,
                          'user_id': mockCurrentUserId,
                          'content': controller.text.trim(),
                        });

                        controller.clear();
                        setState(() {}); // Refresh to show new comment
                        _showSuccess('Comment posted!');
                      } catch (e) {
                        _showError('Failed to post comment: $e');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ DELETE COMMENT
  Future<void> _deleteComment(String commentId) async {
    try {
      await supabase.from('comments').delete().eq('id', commentId);
      setState(() {}); // Refresh
      _showSuccess('Comment deleted');
    } catch (e) {
      _showError('Failed to delete comment: $e');
    }
  }

  // ✅ EXACT ACTION BUTTON STYLE FROM MYPROFILE
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final color = isActive ? primaryRed : Colors.grey[600];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildExperienceCard() {
  final experiences = user!['experience'] as List;

  return Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Experience',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        ...experiences.asMap().entries.map((entry) {
          final index = entry.key;
          final exp = entry.value;

          // Format dates
          String dateRange = '';
          if (exp['start_date'] != null) {
            final startDate = DateTime.parse(exp['start_date']);
            final startFormatted = DateFormat('MMM yyyy').format(startDate);
            
            if (exp['is_current'] == true) {
              dateRange = '$startFormatted - Present';
            } else if (exp['end_date'] != null) {
              final endDate = DateTime.parse(exp['end_date']);
              final endFormatted = DateFormat('MMM yyyy').format(endDate);
              dateRange = '$startFormatted - $endFormatted';
            } else {
              dateRange = startFormatted;
            }
          }

          return Column(
            children: [
              if (index > 0) const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Icon(
                      Icons.business_outlined,
                      size: 22,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dateRange.isNotEmpty) ...[
                          Text(
                            dateRange,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (exp['description'] != null && exp['description'].toString().isNotEmpty) ...[
                          Text(
                            exp['description'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (exp['skills'] != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.auto_awesome_outlined, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  exp['skills'].toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ],
    ),
  );
}
 Widget _buildEducationCard() {
  final education = user!['education'] as List;

  return Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Education',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        ...education.asMap().entries.map((entry) {
          final index = entry.key;
          final edu = entry.value;

          return Column(
            children: [
              if (index > 0) const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 22,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          edu['school'] ?? 'University',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            height: 1.2,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          edu['degree'] ?? 'Degree',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${edu['startYear'] ?? ''} - ${edu['endYear'] ?? 'Present'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.2,
                          ),
                        ),
                        if (edu['description'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            edu['description'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ],
    ),
  );
}

 Widget _buildSkillsCard() {
  final skills = user!['skills'] as List;
  final displayedSkills = skills.take(3).toList();
  final hasMore = skills.length > 3;

  return Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Skills',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        ...displayedSkills.asMap().entries.map((entry) {
          final index = entry.key;
          final skill = entry.value;
          final endorsements = skill['endorsements'] ?? 0;

          return Column(
            children: [
              if (index > 0) ...[
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey[300]),
                const SizedBox(height: 16),
              ],
              _buildSkillItem(
                  skill['name'] ?? 'Skill', skill['description'], endorsements),
            ],
          );
        }).toList(),
        if (hasMore) ...[
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.grey[300]),
          InkWell(
            onTap: () {
              _showAllSkills();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Show all ${skills.length} skills',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
  // ✅ EXACT SKILL ITEM STYLE FROM MYPROFILE WITH ENDORSE BUTTON
Widget _buildSkillItem(
    String skillName, String? proficiencyLevel, int endorsements) {
  final isEndorsed = endorsedSkills[skillName] ?? false;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        skillName,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
          height: 1.3,
        ),
      ),
      if (proficiencyLevel != null && proficiencyLevel.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          'Proficiency: $proficiencyLevel',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await _toggleSkillEndorsement(skillName);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isEndorsed ? primaryRed : Colors.transparent,
                border: Border.all(
                  color: isEndorsed ? primaryRed : Colors.grey[500]!,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEndorsed ? Icons.check : Icons.add,
                    size: 16,
                    color: isEndorsed ? Colors.white : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEndorsed ? 'Endorsed' : 'Endorse',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isEndorsed ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
  Future<void> _toggleSkillEndorsement(String skillName) async {
    setState(() {
      endorsedSkills[skillName] = !(endorsedSkills[skillName] ?? false);
    });

    try {
      final isCurrentlyEndorsed = endorsedSkills[skillName] ?? false;

      if (!isCurrentlyEndorsed) {
        await supabase
            .from('skill_endorsements')
            .delete()
            .eq('skill_name', skillName)
            .eq('endorsed_user_id', widget.userId)
            .eq('endorser_user_id', mockCurrentUserId);

        print('✅ Removed endorsement for: $skillName');

        if (mounted) {
          _showSuccess('Removed endorsement for $skillName');
        }
      } else {
        await supabase.from('skill_endorsements').insert({
          'skill_name': skillName,
          'endorsed_user_id': widget.userId,
          'endorser_user_id': mockCurrentUserId,
        });

        final username = currentUsername ?? 'Someone';

        await createNotification(
          type: 'skill_endorsement',
          title: 'New Skill Endorsement',
          message: '$username endorsed your skill: $skillName',
          icon: 'verified',
        );

        print('✅ Endorsed: $skillName');

        if (mounted) {
          _showSuccess('Endorsed $skillName');
        }
      }
    } catch (e) {
      print('❌ Error toggling endorsement: $e');

      setState(() {
        endorsedSkills[skillName] = !(endorsedSkills[skillName] ?? false);
      });

      if (mounted) {
        _showError('Error: $e');
      }
    }
  }

  // ✅ EXACT MODAL STYLE FROM MYPROFILE
void _showAllSkills() {
  final skills = user!['skills'] as List;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Skills (${skills.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: skills.length,
              separatorBuilder: (context, index) => Column(
                children: [
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                ],
              ),
              itemBuilder: (context, index) {
                final skill = skills[index];
                
                int endorsements = 0;
                if (skill['endorsement_info'] != null) {
                  try {
                    endorsements = skill['endorsement_info'] is int 
                        ? skill['endorsement_info'] 
                        : 0;
                  } catch (e) {
                    print('⚠️ Error parsing endorsement_info: $e');
                  }
                }
                
                return _buildSkillItem(
                  skill['name'] ?? 'Skill',
                  skill['proficiency_level'],
                  endorsements,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
 Widget _buildAllActivityCard() {
  if (allUserComments.isEmpty && allUserReposts.isEmpty) {
    return const SizedBox.shrink();
  }

  return Container(
    width: double.infinity,
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Comments & Reposts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
              const SizedBox(height: 4),
              Text('${allUserComments.length + allUserReposts.length} total interactions', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        const Divider(height: 1),
        ..._buildCombinedActivity(),
      ],
    ),
  );
  
}
}