import 'package:flutter/material.dart';
import 'send_post_dialog.dart';
import 'chat_room_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

// Add these with other state variables (around line 40):
bool _showAllPosts = false;
bool _showAllComments = false;
bool _showAllReposts = false;
  Map<String, dynamic>? user;
  List<Map<String, dynamic>> userPosts = [];
  List<Map<String, dynamic>> userComments = [];
  List<Map<String, dynamic>> userReposts = [];
  List<Map<String, dynamic>> allUserComments = [];
List<Map<String, dynamic>> allUserReposts = [];

  bool loading = true;
  int followerCount = 0;
  int followingCount = 0;
  String? userRole; // ADD THIS LINE

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
  _activityTabController = TabController(length: 3, vsync: this);
  _activityTabController.addListener(() {
    if (_activityTabController.indexIsChanging) {
      setState(() {
        _selectedActivityTab = _activityTabController.index;
        // ✅ ADD THESE LINES: Reset "show all" states when switching tabs
        _showAllPosts = false;
        _showAllComments = false;
        _showAllReposts = false;
      });
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

    final userData = await supabase
        .from('users')
        .select('name, profile_image')
        .eq('user_id', int.parse(mockCurrentUserId))
        .single();

    setState(() {
      currentUsername = userData['name'] ?? 'Someone';
      currentUserProfileUrl = userData['profile_image'];
    });

    print('✅ Current user loaded: $currentUsername (ID: $mockCurrentUserId)');
  } catch (e) {
    print('⚠️ Error fetching current user data: $e');
    setState(() {
      currentUsername = 'Someone';
    });
  }
}@override
  void dispose() {
    _activityTabController.dispose(); // ✅ DISPOSE TAB CONTROLLER
    _animationController.dispose();
    super.dispose();
  }
Future<void> createNotification({
  required String type,
  required String title,
  required String message,
  String? postId,
}) async {
  try {
    final username = currentUsername ?? 'Someone';

    final notificationData = {
      'user_id': int.parse(widget.userId),
      'type': type,
      'title': title, // ✅ INCLUDE TITLE
      'body': message.replaceAll('null', username),
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
      'from_user_id': int.parse(mockCurrentUserId),
    };

    print('📤 Creating notification: $notificationData');
    
    final result = await supabase.from('notifications').insert(notificationData).select();

    print('✅ Notification created successfully: $result');
  } catch (e) {
    print('❌ Error creating notification: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}

Future<void> checkIfFollowing() async {
  try {
    // Check if there's a friendship record where current user is user_id and viewing user is friend_id
    final response1 = await supabase
        .from('friendships')
        .select()
        .eq('user_id', int.parse(mockCurrentUserId))
        .eq('friend_id', int.parse(widget.userId))
        .maybeSingle();

    // Or check the reverse (viewing user is user_id and current user is friend_id)
    final response2 = await supabase
        .from('friendships')
        .select()
        .eq('user_id', int.parse(widget.userId))
        .eq('friend_id', int.parse(mockCurrentUserId))
        .maybeSingle();

    setState(() {
      isFollowing = (response1 != null && response1['status'] == 'accepted') ||
                    (response2 != null && response2['status'] == 'accepted');
    });
  } catch (e) {
    print("⚠️ Error checking follow status: $e");
    setState(() => isFollowing = false);
  }
}

Future<void> fetchFollowerCounts() async {
  try {
    // Count followers: people who have accepted friendship with this user
    final followersData1 = await supabase
        .from('friendships')
        .select()
        .eq('friend_id', int.parse(widget.userId))
        .eq('status', 'accepted');

    final followersData2 = await supabase
        .from('friendships')
        .select()
        .eq('user_id', int.parse(widget.userId))
        .eq('status', 'accepted');

    // Use Set to avoid counting duplicates
    final allFollowers = {
      ...followersData1.map((f) => f['user_id']),
      ...followersData2.map((f) => f['friend_id']),
    };
    allFollowers.remove(int.parse(widget.userId)); // Remove self

    setState(() {
      followerCount = allFollowers.length;
      followingCount = 0; // ✅ REMOVE FOLLOWING COUNT
    });

    print('👥 Followers: $followerCount');
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
    print('🔄 Toggle follow called');
    
    // Check if already friends (accepted friendship)
    final existingFriendship = await supabase
        .from('friendships')
        .select()
        .or('and(user_id.eq.${int.parse(mockCurrentUserId)},friend_id.eq.${int.parse(widget.userId)}),and(user_id.eq.${int.parse(widget.userId)},friend_id.eq.${int.parse(mockCurrentUserId)})')
        .maybeSingle();

    if (existingFriendship != null) {
      print('✅ Already friends, unfollowing...');
      // Unfollow: delete the friendship
      await supabase
          .from('friendships')
          .delete()
          .or('and(user_id.eq.${int.parse(mockCurrentUserId)},friend_id.eq.${int.parse(widget.userId)}),and(user_id.eq.${int.parse(widget.userId)},friend_id.eq.${int.parse(mockCurrentUserId)})');
      
      setState(() => isFollowing = false);
      await fetchFollowerCounts();
      _showSuccess('Unfollowed successfully');
      return;
    }

    // Check for ANY existing request (regardless of status) sent by me
    final myExistingRequest = await supabase
        .from('friendship_requests')
        .select()
        .eq('requester_id', int.parse(mockCurrentUserId))
        .eq('receiver_id', int.parse(widget.userId))
        .maybeSingle();

    if (myExistingRequest != null) {
      print('📋 Found my existing request: ${myExistingRequest}');
      
      if (myExistingRequest['status'] == 'pending') {
        // Cancel pending request
        print('🚫 Cancelling my pending request...');
        await supabase
            .from('friendship_requests')
            .delete()
            .eq('request_id', myExistingRequest['request_id']);
        
        // Delete the notification
        await supabase
            .from('notifications')
            .delete()
            .eq('user_id', int.parse(widget.userId))
            .eq('from_user_id', int.parse(mockCurrentUserId))
            .eq('type', 'follow_request');
        
        setState(() {});
        _showSuccess('Request cancelled');
        return;
      } else {
        // If rejected or accepted, delete it so we can send a new one
        print('🔄 Deleting old request with status: ${myExistingRequest['status']}');
        await supabase
            .from('friendship_requests')
            .delete()
            .eq('request_id', myExistingRequest['request_id']);
        // Continue to send new request below
      }
    }

    // Check for request from them
    final theirRequest = await supabase
        .from('friendship_requests')
        .select()
        .eq('requester_id', int.parse(widget.userId))
        .eq('receiver_id', int.parse(mockCurrentUserId))
        .eq('status', 'pending')
        .maybeSingle();

    if (theirRequest != null) {
      print('✅ Accepting their request...');
      
      // Update request to accepted
      await supabase
          .from('friendship_requests')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('request_id', theirRequest['request_id']);
      
      // Add to friendships table
      await supabase.from('friendships').insert({
        'user_id': int.parse(mockCurrentUserId),
        'friend_id': int.parse(widget.userId),
        'status': 'accepted',
      });
      
      // Delete the request notification
      await supabase
          .from('notifications')
          .delete()
          .eq('user_id', int.parse(mockCurrentUserId))
          .eq('from_user_id', int.parse(widget.userId))
          .eq('type', 'follow_request');

      // Send acceptance notification
await supabase.from('notifications').insert({
  'user_id': int.parse(widget.userId),
  'type': 'follow_accepted',
  'title': 'Friend Request Accepted',
  'body': '${currentUsername ?? 'Someone'} accepted your follow request, you are now friends!!',
  'is_read': false,
  'from_user_id': int.parse(mockCurrentUserId),
});
      
      setState(() => isFollowing = true);
      await fetchFollowerCounts();
      _showSuccess('Friend request accepted!');
      return;
    }

    // No existing relationship - send new friend request
    print('📝 Creating new friend request from $mockCurrentUserId to ${widget.userId}');
    
   // Create friendship request
final insertedRequest = await supabase.from('friendship_requests').insert({
  'requester_id': int.parse(mockCurrentUserId),
  'receiver_id': int.parse(widget.userId),
  'status': 'pending',
}).select();

    print('✅ Request created: $insertedRequest');

    // Create notification
final insertedNotification = await supabase.from('notifications').insert({
  'user_id': int.parse(widget.userId),
  'type': 'follow_request',
  'title': 'New Follow Request',
  'body': '${currentUsername ?? 'Someone'} wants to follow you',
  'is_read': false,
  'from_user_id': int.parse(mockCurrentUserId),
}).select();

    print('✅ Notification created: $insertedNotification');

    setState(() {});
    _showSuccess('Follow request sent!');

  } catch (e) {
    print("❌ Error toggling follow: $e");
    print("Stack trace: ${StackTrace.current}");
    _showError('Failed to process request. Please try again.');
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

    // ✅ Fetch projects from projects table
    List<dynamic> projectsList = [];
    try {
      final projectsData = await supabase
          .from('projects')
          .select('*')
          .eq('user_id', int.parse(widget.userId))
          .order('start_date', ascending: false);
      projectsList = projectsData as List;
      print('✅ Loaded ${projectsList.length} projects');
    } catch (e) {
      print('⚠️ Error loading projects: $e');
    }

    // ✅ Fetch licenses from licenses table
    List<dynamic> licensesList = [];
    try {
      final licensesData = await supabase
          .from('licenses')
          .select('*')
          .eq('user_id', int.parse(widget.userId))
          .order('issue_date', ascending: false);
      licensesList = licensesData as List;
      print('✅ Loaded ${licensesList.length} licenses');
    } catch (e) {
      print('⚠️ Error loading licenses: $e');
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
        'projects': projectsList,
        'licenses': licensesList,
      };
      loading = false;
    });
    await checkIfFollowing();
    await fetchFollowerCounts();



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
}
Future<Map<String, dynamic>?> _checkFollowStatus() async {
  try {
    // Check if already friends
    final friendship = await supabase
        .from('friendships')
        .select()
        .or('and(user_id.eq.${int.parse(mockCurrentUserId)},friend_id.eq.${int.parse(widget.userId)}),and(user_id.eq.${int.parse(widget.userId)},friend_id.eq.${int.parse(mockCurrentUserId)})')
        .maybeSingle();

    if (friendship != null) {
      return {'status': 'accepted', 'type': 'friendship'};
    }

    // Check if I sent a request
    final myRequest = await supabase
        .from('friendship_requests')
        .select()
        .eq('requester_id', int.parse(mockCurrentUserId))
        .eq('receiver_id', int.parse(widget.userId))
        .eq('status', 'pending')
        .maybeSingle();

    if (myRequest != null) {
      return {
        'status': 'pending',
        'type': 'sent',
        'requester_id': int.parse(mockCurrentUserId)
      };
    }

    // Check if they sent a request
    final theirRequest = await supabase
        .from('friendship_requests')
        .select()
        .eq('requester_id', int.parse(widget.userId))
        .eq('receiver_id', int.parse(mockCurrentUserId))
        .eq('status', 'pending')
        .maybeSingle();

    if (theirRequest != null) {
      return {
        'status': 'pending',
        'type': 'received',
        'requester_id': int.parse(widget.userId)
      };
    }

    return null;
  } catch (e) {
    print('⚠️ Error checking follow status: $e');
    return null;
  }
}

Future<void> _loadUserPosts() async {
  try {
    List<Map<String, dynamic>> allUserPosts = [];

    // 1. Load regular posts from 'posts' table
    final regularPosts = await supabase
        .from('posts')
        .select('*, created_at')
        .eq('author_id', int.parse(widget.userId))
        .order('created_at', ascending: false);

    for (var post in regularPosts) {
      allUserPosts.add({
        ...post,
        'post_type': 'post',
        'original_table': 'posts',
      });
    }

    // 2. Load announcements - ONLY for non-Instructor/TA users
    if (userRole?.toLowerCase() != 'instructor' &&
        userRole?.toLowerCase() != 'ta') {
      final announcements = await supabase
          .from('announcement')
          .select('*, created_at')
          .eq('auth_id', int.parse(widget.userId))
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

    // 3. Load competition requests - ONLY for non-Instructor/TA users
    if (userRole?.toLowerCase() != 'instructor' &&
        userRole?.toLowerCase() != 'ta') {
      final competitionRequests = await supabase
          .from('competition_requests')
          .select('*, created_at')
          .eq('user_id', int.parse(widget.userId))
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

    // 4. Sort all posts by created_at
    allUserPosts.sort((a, b) {
      final aDate = DateTime.parse(a['created_at']);
      final bDate = DateTime.parse(b['created_at']);
      return bDate.compareTo(aDate);
    });

    if (mounted) {
      setState(() => userPosts = allUserPosts);
      print('✅ Loaded ${allUserPosts.length} posts for user ${widget.userId}');
    }
  } catch (e) {
    print('❌ Error loading user posts: $e');
    if (mounted) setState(() => userPosts = []);
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
        posts!inner(post_id, title, content, author_id)
      ''')
        .eq('user_id', int.parse(widget.userId))
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
        posts!inner(post_id, title, content, author_id, created_at, media_url)
      ''')
        .eq('user_id', int.parse(widget.userId))
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
                              gradient: user!['cover_image'] != null && 
                                  user!['cover_image'].toString().isNotEmpty
                                  ? null
                                  : LinearGradient(
                                      colors: [Colors.grey[800]!, Colors.grey[600]!],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              image: (user!['cover_image'] != null && 
                                  user!['cover_image'].toString().isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(user!['cover_image']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
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
                                backgroundColor: Colors.grey[200],
                                backgroundImage: (user!['profile_image'] != null && 
                                    user!['profile_image'].toString().isNotEmpty)
                                    ? NetworkImage(user!['profile_image'])
                                    : null,
                                child: (user!['profile_image'] == null || 
                                    user!['profile_image'].toString().isEmpty)
                                    ? const Icon(Icons.person, size: 60)
                                    : null,
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (user!['role'] != null)
                              Text(
                                user!['role'],
                                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                              ),
                            if (user!['department'] != null)
                              Text(
                                'Department: ${user!['department']}',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            if (user!['academic_year'] != null)
                              Text(
                                'Year: ${user!['academic_year']}',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            const SizedBox(height: 12),

                            // Connections count
                           // Connections count
Text(
  '$followerCount followers',
  style: const TextStyle(
    fontSize: 14,
    color: Color(0xFFDC143C),
    fontWeight: FontWeight.w600,
  ),
),

                            const SizedBox(height: 16),

// ✅ ACTION BUTTONS - Follow/Unfollow only (no message)
FutureBuilder<Map<String, dynamic>?>(
  future: _checkFollowStatus(),
  builder: (context, snapshot) {
    // Force rebuild when data changes
    if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          label: const Text('Loading...'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.grey[700],
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );
    }

final friendshipData = snapshot.data;
final String? status = friendshipData?['status'];
final String? type = friendshipData?['type'];

String buttonText = 'Follow';
IconData buttonIcon = Icons.person_add_outlined;
Color bgColor = const Color(0xFFDC143C);
Color fgColor = Colors.white;

if (status == 'accepted') {
  buttonText = 'Following';
  buttonIcon = Icons.check;
  bgColor = Colors.white;
  fgColor = const Color(0xFFDC143C);
} else if (status == 'pending' && type == 'sent') {
  buttonText = 'Pending';
  buttonIcon = Icons.schedule;
  bgColor = Colors.grey[300]!;
  fgColor = Colors.grey[700]!;
} else if (status == 'pending' && type == 'received') {
  buttonText = 'Accept Request';
  buttonIcon = Icons.person_add;
  bgColor = Colors.green;
  fgColor = Colors.white;
}

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await toggleFollow();
          // Force rebuild after action
          setState(() {});
        },
        icon: Icon(buttonIcon, size: 18),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: (status == 'accepted' || (status == 'pending' && type == 'sent'))
    ? BorderSide(color: fgColor == const Color(0xFFDC143C) ? const Color(0xFFDC143C) : Colors.grey[400]!, width: 1.5)
    : BorderSide.none,
          ),
        ),
      ),
    );
  },
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

                // ✅✅✅ ACTIVITY SECTION WITH TABS
                _buildActivityCard(),

                const SizedBox(height: 8),

                // Experience section
                if (user!['experience'] != null &&
                    (user!['experience'] as List).isNotEmpty)
                  _buildExperienceCard(),

                const SizedBox(height: 8),

                // Projects section
                if (user!['projects'] != null &&
                    (user!['projects'] as List).isNotEmpty)
                  _buildProjectsCard(),

                const SizedBox(height: 8),

                // Licenses section
                if (user!['licenses'] != null &&
                    (user!['licenses'] as List).isNotEmpty)
                  _buildLicensesCard(),

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
                  '${userPosts.length + userComments.length + userReposts.length} activities',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
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

        // Tab Content
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
            // ✅ Show only latest post or all posts
            ...(_showAllPosts ? userPosts : userPosts.take(1)).map((post) => _buildPostCardFromMyProfile(post)),
            
            // ✅ Show "View All" button if more than 1 post
            if (userPosts.length > 1)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: TextButton(
                    onPressed: () {
                      setState(() => _showAllPosts = !_showAllPosts);
                    },
                    child: Text(
                      _showAllPosts ? 'Show Less' : 'View All ${userPosts.length} Posts',
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
            // ✅ Show only latest comment or all comments
            ...(_showAllComments ? userComments : userComments.take(1)).map((comment) => _buildCommentCardFromMyProfile(comment)),
            
            // ✅ Show "View All" button if more than 1 comment
            if (userComments.length > 1)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: TextButton(
                    onPressed: () {
                      setState(() => _showAllComments = !_showAllComments);
                    },
                    child: Text(
                      _showAllComments ? 'Show Less' : 'View All ${userComments.length} Comments',
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
            // ✅ Show only latest repost or all reposts
            ...(_showAllReposts ? userReposts : userReposts.take(1)).map((repost) => _buildRepostCardFromMyProfile(repost)),
            
            // ✅ Show "View All" button if more than 1 repost
            if (userReposts.length > 1)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: TextButton(
                    onPressed: () {
                      setState(() => _showAllReposts = !_showAllReposts);
                    },
                    child: Text(
                      _showAllReposts ? 'Show Less' : 'View All ${userReposts.length} Reposts',
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
  // ✅ POST CARD - EXACT REPLICA FROM MYPROFILE
Widget _buildPostCardFromMyProfile(Map<String, dynamic> post) {
  final postType = post['post_type'] ?? 'post';
  
  if (postType == 'announcement') {
    return _buildAnnouncementPostCard(post);
  } else if (postType == 'competition_request') {
    return _buildCompetitionRequestCard(post);
  }

  return StatefulBuilder(
    builder: (context, setCardState) {
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
                        backgroundImage: (user!['profile_image'] != null && 
                            user!['profile_image'].toString().isNotEmpty)
                            ? NetworkImage(user!['profile_image'])
                            : null,
                        child: (user!['profile_image'] == null || 
                            user!['profile_image'].toString().isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user!['name'] ?? 'Unknown',
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
                    ],
                  ),
                  const SizedBox(height: 12),

                  // POST CONTENT
                  if (post['content'] != null && post['content'].toString().isNotEmpty)
                    Text(
                      post['content'],
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // POST IMAGE
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

                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey[300]),
                  const SizedBox(height: 8),

                  // INTERACTION STATS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (counts[0] > 0)
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
                        )
                      else
                        const SizedBox(),
                      Text(
                        '${counts[1]} comment${counts[1] != 1 ? 's' : ''} · ${counts[2]} repost${counts[2] != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Divider(height: 1, color: Colors.grey[300]),

                  // ACTION BUTTONS (Read-only for other users)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        onPressed: () {}, // Disabled for other users
                        icon: Icon(
                          Icons.favorite_border,
                          color: Colors.grey[700],
                          size: 20,
                        ),
                        label: Text(
                          'Like',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {}, // Disabled for other users
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
                      TextButton.icon(
                        onPressed: () {}, // Disabled for other users
                        icon: Icon(
                          Icons.repeat,
                          color: Colors.grey[700],
                          size: 20,
                        ),
                        label: Text(
                          'Repost',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
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

// ✅ HELPER METHODS FOR POST INTERACTIONS
Future<int> _getPostLikeCount(int postId) async {
  try {
    final result = await supabase
        .from('likes')
        .select('like_id')
        .eq('post_id', postId);
    return result.length;
  } catch (e) {
    print('Error getting like count: $e');
    return 0;
  }
}

Future<int> _getPostCommentCount(int postId) async {
  try {
    final result = await supabase
        .from('comments')
        .select('comment_id')
        .eq('post_id', postId);
    return result.length;
  } catch (e) {
    print('Error getting comment count: $e');
    return 0;
  }
}

Future<int> _getPostRepostCount(int postId) async {
  try {
    final result = await supabase
        .from('reposts')
        .select('id')
        .eq('post_id', postId);
    return result.length;
  } catch (e) {
    print('Error getting repost count: $e');
    return 0;
  }
}

// ✅ ANNOUNCEMENT CARD
Widget _buildAnnouncementPostCard(Map<String, dynamic> announcement) {
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

// ✅ COMPETITION REQUEST CARD
Widget _buildCompetitionRequestCard(Map<String, dynamic> request) {
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

// ✅ COMMENT CARD FROM MYPROFILE
Widget _buildCommentCardFromMyProfile(Map<String, dynamic> comment) {
  final post = comment['posts'];

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
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[200],
                backgroundImage: (user!['profile_image'] != null && 
                    user!['profile_image'].toString().isNotEmpty)
                    ? NetworkImage(user!['profile_image'])
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${user!['name'] ?? 'Unknown'} commented',
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
            ],
          ),
          const SizedBox(height: 12),
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
                    post['title'] ?? post['content'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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

// ✅ REPOST CARD FROM MYPROFILE
Widget _buildRepostCardFromMyProfile(Map<String, dynamic> repost) {
  final post = repost['posts'];

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
          Row(
            children: [
              const Icon(Icons.repeat, color: Color(0xFFDC143C), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${user!['name'] ?? 'Unknown'} reposted this',
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
                        post['title'] ?? post['content'] ?? '',
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
  future: loadPostComments(postData['id']),
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
Future<List<Map<String, dynamic>>> loadPostComments(int postId) async {
  try {
    final data = await supabase
        .from('comments')
        .select('''
        comment_id,
        content,
        created_at,
        user_id,
        users:user_id (
          name,
          profile_image,
          role,
          department
        )
      ''')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  } catch (e) {
    print('❌ Error loading comments: $e');
    return [];
  }
}
  // ✅ BUILD COMMENT ITEM (EXACT STYLE FROM SCREENSHOT)
  Widget _buildCommentItem(Map<String, dynamic> comment) {
final userData = comment['users'];
final String username = userData != null ? (userData['name'] ?? 'Unknown') : 'Unknown';
final String? userProfileImage = userData != null ? userData['profile_image'] : null;
final String? userRole = userData != null ? userData['role'] : null;
final String? userDept = userData != null ? userData['department'] : null;
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
  backgroundImage: userProfileImage != null && userProfileImage.isNotEmpty
      ? NetworkImage(userProfileImage)
      : null,
  child: userProfileImage == null || userProfileImage.isEmpty
      ? Text(
          username.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        )
      : null,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exp['title'] ?? '',
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
                          '${exp['company'] ?? ''}${exp['employment_type'] != null ? ' · ${exp['employment_type']}' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.2,
                          ),
                        ),
                        if (dateRange.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            dateRange,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.2,
                            ),
                          ),
                        ],
                        if (exp['location'] != null && exp['location'].toString().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            exp['location'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.2,
                            ),
                          ),
                        ],
                        if (exp['description'] != null && exp['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            exp['description'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (exp['skills'] != null && exp['skills'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
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
Widget _buildProjectsCard() {
  final projects = user!['projects'] as List? ?? [];
  
  if (projects.isEmpty) return const SizedBox.shrink();

  return Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Projects',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        ...projects.asMap().entries.map((entry) {
          final index = entry.key;
          final project = entry.value;

          String dateRange = '';
          if (project['start_date'] != null) {
            final startDate = DateTime.parse(project['start_date']);
            final startFormatted = DateFormat('MMM yyyy').format(startDate);
            
            if (project['is_current'] == true) {
              dateRange = '$startFormatted - Present';
            } else if (project['end_date'] != null) {
              final endDate = DateTime.parse(project['end_date']);
              final endFormatted = DateFormat('MMM yyyy').format(endDate);
              dateRange = '$startFormatted - $endFormatted';
            } else {
              dateRange = startFormatted;
            }
          }

          final hasUrl = project['project_url'] != null && project['project_url'].toString().isNotEmpty;

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
                                  fontSize: 16,
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
                        if (dateRange.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                dateRange,
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
                        ],
                        if (project['description'] != null && project['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            project['description'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (project['skills'] != null && project['skills'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: project['skills'].toString().split(',').map((skill) =>
                              Container(
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
                            ).toList(),
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

// Add helper method for opening URLs
Future<void> _openFile(String? url) async {
  if (url == null || url.isEmpty) {
    _showError("Invalid file link");
    return;
  }

  final Uri uri = Uri.parse(url);
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError("Could not open the file");
    }
  } catch (e) {
    print("Error launching URL: $e");
    _showError("Error opening attachment");
  }
}
Widget _buildLicensesCard() {
  final licenses = user!['licenses'] as List? ?? [];
  
  if (licenses.isEmpty) return const SizedBox.shrink();

  return Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Licenses & certifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        ...licenses.asMap().entries.map((entry) {
          final index = entry.key;
          final license = entry.value;

          String issuedDate = '';
          if (license['issue_date'] != null) {
            final date = DateTime.parse(license['issue_date']);
            issuedDate = 'Issued ${DateFormat('MMM yyyy').format(date)}';
          }

          return Column(
            children: [
              if (index > 0) ...[
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey[300]),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.workspace_premium_outlined,
                      size: 22,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          license['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            height: 1.3,
                          ),
                        ),
                        if (license['issuing_organization'] != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            license['issuing_organization'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (issuedDate.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            issuedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.3,
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
    skill['name'] ?? 'Skill', 
    skill['endorsement_info']),
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
Widget _buildSkillItem(String skillName, String? endorsementInfo) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        skillName,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (endorsementInfo != null && endorsementInfo.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.verified, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                endorsementInfo,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );
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
  
  return _buildSkillItem(
    skill['name'] ?? 'Skill',
    skill['endorsement_info'],
  );
},
            ),
          ),
        ],
      ),
    ),
  );
}

}