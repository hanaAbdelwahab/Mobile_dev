import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/friendship_provider.dart';
import 'package:miu_tech/views/screens/comments_page.dart';
import '../screens/calender_screen.dart'; // or calendar_screen.dart depending on your file name

final supabase = Supabase.instance.client;

class NotificationsPage extends StatefulWidget {
  final int userId;

  const NotificationsPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    
  }

  Future<void> fetchNotifications() async {
    try {
      print('🔍 Fetching notifications for user_id: ${widget.userId}');

      final data = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      print('✅ Fetched ${data.length} notifications');
      print('📋 Notifications data: $data');

      // Fetch sender details and additional like info for each notification
      for (var notification in data) {
        if (notification['from_user_id'] != null) {
          try {
            final senderData = await supabase
                .from('users')
                .select('name, profile_image, role, department')
                .eq('user_id', notification['from_user_id'])
                .maybeSingle();

            notification['sender_data'] = senderData;
            print('✅ Loaded sender: ${senderData?['name']} for notification type: ${notification['type']}');

            // For like notifications, fetch all likers if it's a grouped notification
            if (notification['type'] == 'like' && notification['post_id'] != null) {
              final likersData = await supabase
                  .from('likes')
                  .select('user_id')
                  .eq('post_id', notification['post_id']);
              
              notification['like_count'] = likersData.length;
              print('✅ Like count for post ${notification['post_id']}: ${likersData.length}');
              
              // Dynamically update the notification body based on current count
              if (likersData.length > 1) {
                notification['body'] = '${senderData?['name'] ?? 'Someone'} and ${likersData.length - 1} others liked your post';
              } else {
                notification['body'] = '${senderData?['name'] ?? 'Someone'} liked your post';
              }
            }
            
            // For comment notifications, fetch all commenters
            if (notification['type'] == 'comment' && notification['post_id'] != null) {
              final commentsData = await supabase
                  .from('comments')
                  .select('comment_id')
                  .eq('post_id', notification['post_id']);
              
              notification['comment_count'] = commentsData.length;
              print('✅ Comment count for post ${notification['post_id']}: ${commentsData.length}');
              
              // Dynamically update the notification body based on current count
              if (commentsData.length > 1) {
                notification['body'] = '${senderData?['name'] ?? 'Someone'} and ${commentsData.length - 1} others commented on your post';
              } else {
                notification['body'] = '${senderData?['name'] ?? 'Someone'} commented on your post';
              }
            }
            
            // For repost notifications, fetch all reposters
            if (notification['type'] == 'repost' && notification['post_id'] != null) {
              final repostsData = await supabase
                  .from('reposts')
                  .select('id')
                  .eq('post_id', notification['post_id']);
              
              notification['repost_count'] = repostsData.length;
              print('✅ Repost count for post ${notification['post_id']}: ${repostsData.length}');
              
              // Dynamically update the notification body based on current count
              if (repostsData.length > 1) {
                notification['body'] = '${senderData?['name'] ?? 'Someone'} and ${repostsData.length - 1} others reposted your post';
              } else {
                notification['body'] = '${senderData?['name'] ?? 'Someone'} reposted your post';
              }
            }
            
            // For reminder notifications, fetch announcement details
            // For reminder notifications, fetch announcement details
if (notification['type'] == 'reminder' && notification['announcement_id'] != null) {
   try {
    final announcementData = await supabase
        .from('announcement')
        .select('title, description, date, time')
        .eq('ann_id', notification['announcement_id'])
        .maybeSingle();
    
    if (announcementData != null) {
      // Parse the announcement date
      try {
        final announcementDate = DateTime.parse(announcementData['date']);
        final today = DateTime.now();
        
        // Reset time to compare only dates (ignore hours/minutes)
        final announcementDateOnly = DateTime(announcementDate.year, announcementDate.month, announcementDate.day);
        final todayDateOnly = DateTime(today.year, today.month, today.day);
        
        // Check if the announcement is EXACTLY for today
        final isToday = announcementDateOnly.isAtSameMomentAs(todayDateOnly);
        
        if (isToday) {
          // Only keep this notification if it's for today
          notification['announcement_data'] = announcementData;
          print('✅ Loaded announcement: ${announcementData['title']} for today (${announcementData['date']})');
        } else {
          // Mark this notification to be removed (not for today - either past or future)
          notification['should_remove'] = true;
          final dateStatus = announcementDateOnly.isBefore(todayDateOnly) ? 'PAST' : 'FUTURE';
          print('⚠️ Removing $dateStatus reminder: ${announcementData['title']} - Date: ${announcementData['date']} (Today is ${today.toString().split(' ')[0]})');
        }
      } catch (dateError) {
        print('⚠️ Error parsing date for announcement: $dateError');
        notification['should_remove'] = true;
      }
    } else {
      // No announcement data found, mark for removal
      notification['should_remove'] = true;
      print('⚠️ No announcement data found for reminder');
    }
   } catch (e) {
    print('⚠️ Error fetching announcement data: $e');
    notification['should_remove'] = true;
  }
}
          } catch (e) {
            print('⚠️ Error fetching sender data: $e');
          }
        } else {
          print('⚠️ Notification has null from_user_id: ${notification}');
        }
      }
     
// Filter out reminder notifications that are not for today
// Filter out reminder notifications that are not for today
final filteredData = data.where((notification) {
  return notification['should_remove'] != true;
}).toList();

// Delete the filtered-out reminder notifications from database
for (var notification in data) {
  if (notification['should_remove'] == true && notification['type'] == 'reminder') {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('notification_id', notification['notification_id']);
      print('🗑️ Deleted old reminder notification: ${notification['notification_id']}');
    } catch (e) {
      print('⚠️ Error deleting reminder: $e');
    }
  }
}

setState(() {
  notifications = filteredData;
  loading = false;
});

      print('✅ Total notifications loaded: ${notifications.length}');
      print('✅ Follow request notifications: ${notifications.where((n) => n['type'] == 'follow_request').length}');
      print('✅ Like notifications: ${notifications.where((n) => n['type'] == 'like').length}');
      print('✅ Comment notifications: ${notifications.where((n) => n['type'] == 'comment').length}');
      print('✅ Repost notifications: ${notifications.where((n) => n['type'] == 'repost').length}');
      print('✅ Reminder notifications: ${notifications.where((n) => n['type'] == 'reminder').length}');
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        loading = false;
      });
    }
  }

  String formatTime(String? time) {
    if (time == null) return 'Just now';

    try {
      final date = DateTime.parse(time);
      final diff = DateTime.now().difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return "${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago";
      if (diff.inHours < 24) return "${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago";
      if (diff.inDays < 7) return "${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago";
      if (diff.inDays < 30) return "${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() > 1 ? 's' : ''} ago";
      return "${(diff.inDays / 30).floor()} month${(diff.inDays / 30).floor() > 1 ? 's' : ''} ago";
    } catch (e) {
      print('Error parsing time: $e');
      return 'Recently';
    }
  }

  Future<void> acceptFollow(int fromUserId, String senderName) async {
    try {
      print('🔄 Accepting follow request from: $fromUserId');

      // 1. Update friendship_request to accepted
      await supabase
          .from('friendship_requests')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('requester_id', fromUserId)
          .eq('receiver_id', widget.userId)
          .eq('status', 'pending');

      // 2. Add to friendships table
      await supabase.from('friendships').insert({
        'user_id': widget.userId,
        'friend_id': fromUserId,
        'status': 'accepted',
      });

      // 3. Delete the follow_request notification
      await supabase
          .from('notifications')
          .delete()
          .eq('from_user_id', fromUserId)
          .eq('user_id', widget.userId)
          .eq('type', 'follow_request');

      // 4. Send acceptance notification to the requester
      final currentUserData = await supabase
          .from('users')
          .select('name, profile_image')
          .eq('user_id', widget.userId)
          .single();

      final currentUserName = currentUserData['name'] ?? 'Someone';

      await supabase.from('notifications').insert({
        'user_id': fromUserId,
        'type': 'follow_accepted',
        'title': 'Friend Request Accepted',
        'body': '$currentUserName accepted your follow request, you are now friends!!',
        'is_read': false,
        'from_user_id': widget.userId,
      });

      // 5. Update provider to sync across all pages
      if (mounted) {
        final provider = Provider.of<FriendshipProvider>(context, listen: false);
        provider.updateStatus(fromUserId, {'status': 'accepted', 'type': 'friendship'});
      }

      print('✅ Follow request accepted and notification sent');

      // Refresh notifications list
      await fetchNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Follow request accepted! You are now friends!!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error accepting follow: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error accepting request: $e")),
        );
      }
    }
  }

  Future<void> rejectFollow(int fromUserId) async {
    try {
      print('🔄 Rejecting follow request from: $fromUserId');

      // 1. Update friendship_request to rejected
      await supabase
          .from('friendship_requests')
          .update({'status': 'rejected', 'updated_at': DateTime.now().toIso8601String()})
          .eq('requester_id', fromUserId)
          .eq('receiver_id', widget.userId)
          .eq('status', 'pending');

      // 2. Delete the notification
      await supabase
          .from('notifications')
          .delete()
          .eq('from_user_id', fromUserId)
          .eq('user_id', widget.userId)
          .eq('type', 'follow_request');

      // 3. Update provider to sync across all pages
      if (mounted) {
        final provider = Provider.of<FriendshipProvider>(context, listen: false);
        provider.updateStatus(fromUserId, null);
      }

      print('✅ Follow request rejected');

      // Refresh notifications list
      await fetchNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Friend request rejected"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error rejecting follow: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error rejecting request: $e")),
        );
      }
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);

      // Update local state
      setState(() {
        final index = notifications.indexWhere((n) => n['notification_id'] == notificationId);
        if (index != -1) {
          notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  Future<void> viewLikers(int postId) async {
    try {
      // Fetch all users who liked this post
      final likersData = await supabase
          .from('likes')
          .select('user_id, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> likers = [];
      for (var like in likersData) {
        final userData = await supabase
            .from('users')
            .select('name, profile_image, role, department')
            .eq('user_id', like['user_id'])
            .single();
        
        likers.add({
          ...userData,
          'liked_at': like['created_at'],
        });
      }

      if (!mounted) return;

      // Show bottom sheet with all likers
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.red[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Liked by ${likers.length} ${likers.length == 1 ? 'person' : 'people'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Likers list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: likers.length,
                  itemBuilder: (context, index) {
                    final liker = likers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: liker['profile_image'] != null && liker['profile_image'].isNotEmpty
                            ? NetworkImage(liker['profile_image'])
                            : null,
                        backgroundColor: Colors.red[700],
                        child: liker['profile_image'] == null || liker['profile_image'].isEmpty
                            ? Text(
                                liker['name'].split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        liker['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        '${liker['role'] ?? 'User'}${liker['department'] != null ? ' | ${liker['department']}' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: Text(
                        formatTime(liker['liked_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Error fetching likers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error loading likes")),
        );
      }
    }
  }

  Future<void> viewCommenters(int postId) async {
    try {
      // Fetch all users who commented on this post
      final commentsData = await supabase
          .from('comments')
          .select('user_id, created_at, content')
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> commenters = [];
      for (var comment in commentsData) {
        final userData = await supabase
            .from('users')
            .select('name, profile_image, role, department')
            .eq('user_id', comment['user_id'])
            .single();
        
        commenters.add({
          ...userData,
          'commented_at': comment['created_at'],
          'comment_preview': comment['content'],
        });
      }

      if (!mounted) return;

      // Show bottom sheet with all commenters
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.comment, color: Colors.red[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '${commenters.length} ${commenters.length == 1 ? 'comment' : 'comments'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Commenters list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: commenters.length,
                  itemBuilder: (context, index) {
                    final commenter = commenters[index];
                    final preview = commenter['comment_preview'] ?? '';
                    final shortPreview = preview.length > 50 
                        ? '${preview.substring(0, 50)}...' 
                        : preview;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: commenter['profile_image'] != null && commenter['profile_image'].isNotEmpty
                            ? NetworkImage(commenter['profile_image'])
                            : null,
                        backgroundColor: Colors.red[700],
                        child: commenter['profile_image'] == null || commenter['profile_image'].isEmpty
                            ? Text(
                                commenter['name'].split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        commenter['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${commenter['role'] ?? 'User'}${commenter['department'] != null ? ' | ${commenter['department']}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shortPreview,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: Text(
                        formatTime(commenter['commented_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Error fetching commenters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error loading comments")),
        );
      }
    }
  }

  Future<void> viewReposters(int postId) async {
    try {
      // Fetch all users who reposted this post
      final repostsData = await supabase
          .from('reposts')
          .select('user_id, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> reposters = [];
      for (var repost in repostsData) {
        final userData = await supabase
            .from('users')
            .select('name, profile_image, role, department')
            .eq('user_id', repost['user_id'])
            .single();
        
        reposters.add({
          ...userData,
          'reposted_at': repost['created_at'],
        });
      }

      if (!mounted) return;

      // Show bottom sheet with all reposters
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.repeat, color: Colors.red[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Reposted by ${reposters.length} ${reposters.length == 1 ? 'person' : 'people'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Reposters list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: reposters.length,
                  itemBuilder: (context, index) {
                    final reposter = reposters[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: reposter['profile_image'] != null && reposter['profile_image'].isNotEmpty
                            ? NetworkImage(reposter['profile_image'])
                            : null,
                        backgroundColor: Colors.red[700],
                        child: reposter['profile_image'] == null || reposter['profile_image'].isEmpty
                            ? Text(
                                reposter['name'].split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        reposter['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        '${reposter['role'] ?? 'User'}${reposter['department'] != null ? ' | ${reposter['department']}' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: Text(
                        formatTime(reposter['reposted_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Error fetching reposters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error loading reposts")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.red[700],
        elevation: 3,
        centerTitle: true,
        title: Text(
          "Notifications",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.red[700],
          ),
        ),
        shape: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No notifications",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchNotifications,
                  color: Colors.red[700],
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];

                      return _buildNotificationItem(
                        notificationId: n['notification_id'],
                        title: n['title'] ?? 'Notification',
                        message: n['body'] ?? '',
                        time: n['created_at'] != null ? formatTime(n['created_at']) : 'Just now',
                        isRead: n['is_read'] ?? false,
                        type: n['type'],
                        fromUserId: n['from_user_id'],
                        postId: n['post_id'],
                        index: index,
                        profileUrl: null,
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> navigateToPost(int postId) async {
    try {
      print('🚀 navigateToPost called with postId: $postId');
      if (!mounted) {
        print('⚠️ Widget not mounted, cannot navigate');
        return;
      }

      print('📱 Pushing CommentsPage for post: $postId, userId: ${widget.userId}');
      // Navigate to CommentsPage which shows the post with comments
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CommentsPage(
            postId: postId,
            currentUserId: widget.userId,
          ),
        ),
      );

      print('🔙 Returned from CommentsPage, refreshing notifications');
      // Refresh notifications when user returns from comments page
      // This will update the comment counts
      if (mounted) {
        await fetchNotifications();
      }
    } catch (e) {
      print('❌ Error navigating to post: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error loading post")),
        );
      }
    }
  }

  Widget _buildNotificationItem({
    required int? notificationId,
    required String title,
    required String message,
    required String time,
    required bool isRead,
    String? type,
    int? fromUserId,
    int? postId,
    required int index,
    String? profileUrl,
  }) {
   final senderData = notifications[index]['sender_data'];
final announcementData = notifications[index]['announcement_data'];

// For reminders, use announcement title; for others, use sender name
final String displayName = type == 'reminder' 
    ? (announcementData?['title'] ?? 'Event Reminder')
    : (senderData != null ? (senderData['name'] ?? 'Unknown') : 'Unknown');

final String? senderProfileImage = senderData != null ? senderData['profile_image'] : null;
final String? senderRole = senderData != null ? senderData['role'] : null;
final String? senderDept = senderData != null ? senderData['department'] : null;
final int? likeCount = notifications[index]['like_count'];
final int? commentCount = notifications[index]['comment_count'];
final int? repostCount = notifications[index]['repost_count'];

// For reminders, create a formatted message from announcement data
String displayMessage = message;
if (type == 'reminder' && announcementData != null) {
  final description = announcementData['description'] ?? '';
  final date = announcementData['date'] ?? '';
  final eventTime = announcementData['time'] ?? '';
  displayMessage = '$description\nScheduled for $date at $eventTime';
}

    // Debug logging
    print('📊 Building notification:');
    print('   Type: $type');
    print('   Like count: $likeCount');
    print('   Comment count: $commentCount');
    print('   Repost count: $repostCount');
    print('   Should hide role?: ${type != 'like' && type != 'comment' && type != 'repost'}');

   return GestureDetector(
  onTap: () {
    print('🔔 Notification tapped - Type: $type, PostId: $postId');
    if (!isRead && notificationId != null) {
      markAsRead(notificationId);
    }
    // Navigate to post for like, comment, and repost notifications
    if ((type == 'like' || type == 'comment' || type == 'repost') && postId != null) {
      print('📍 Navigating to post: $postId');
      navigateToPost(postId);
    } else if (type == 'reminder') {
      print('📅 Reminder notification tapped - navigating to calendar');
      // Navigate to calendar page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalendarScreen(userId: widget.userId),
        ),
      );
    } else {
      print('⚠️ Navigation blocked - Type: $type, PostId: $postId');
    }
  },  // <-- This closing brace and comma were missing!
  child: Container(
    // ... rest of your widget code
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isRead ? Colors.grey[300]! : Colors.red[200]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CircleAvatar for user image (or stacked avatars for multiple likes/comments)
                if (type == 'like' && likeCount != null && likeCount > 1)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      children: [
                        Positioned(
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundImage: senderProfileImage != null && senderProfileImage.isNotEmpty
                                  ? NetworkImage(senderProfileImage)
                                  : null,
                              backgroundColor: Colors.red[700],
                              child: senderProfileImage == null || senderProfileImage.isEmpty
                                  ? Text(
                                     displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(1).join().toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[400],
                              child: Text(
                                '+${likeCount - 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (type == 'comment' && commentCount != null && commentCount > 1)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      children: [
                        Positioned(
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundImage: senderProfileImage != null && senderProfileImage.isNotEmpty
                                  ? NetworkImage(senderProfileImage)
                                  : null,
                              backgroundColor: Colors.red[700],
                              child: senderProfileImage == null || senderProfileImage.isEmpty
                                  ? Text(
                                     displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(1).join().toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[400],
                              child: Text(
                                '+${commentCount - 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (type == 'repost' && repostCount != null && repostCount > 1)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      children: [
                        Positioned(
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundImage: senderProfileImage != null && senderProfileImage.isNotEmpty
                                  ? NetworkImage(senderProfileImage)
                                  : null,
                              backgroundColor: Colors.red[700],
                              child: senderProfileImage == null || senderProfileImage.isEmpty
                                  ? Text(
                                     displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(1).join().toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[400],
                              child: Text(
                                '+${repostCount - 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Default avatar or calendar icon for reminders
                  type == 'reminder'
                    ? CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.red[700],
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                    : CircleAvatar(
                        radius: 24,
                        backgroundImage: senderProfileImage != null && senderProfileImage.isNotEmpty
                            ? NetworkImage(senderProfileImage)
                            : null,
                        backgroundColor: Colors.red[700],
                        child: senderProfileImage == null || senderProfileImage.isEmpty
                            ? Text(
                               displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(1).join().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
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
                       displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (senderRole != null && type != 'like' && type != 'comment' && type != 'repost') ...[
                        const SizedBox(height: 2),
                        Text(
                          '${senderRole}${senderDept != null ? ' | $senderDept' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                       displayMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),

            // Action buttons based on notification type
            if (type == 'follow_request') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (fromUserId == null) return;
                        await acceptFollow(fromUserId, displayName,);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Accept", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        if (fromUserId == null) return;
                        await rejectFollow(fromUserId);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ] else if (type == 'follow_accepted') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You are now friends!!",
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (type == 'like') ...[
              const SizedBox(height: 12),
              // Only show "View Likes" button for grouped notifications
              if (message.contains('others') || message.contains('other'))
                InkWell(
                  onTap: postId != null ? () => viewLikers(postId) : null,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite, color: Colors.red[700], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'View all likes',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // For single likes, show a simple indicator
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite, color: Colors.red[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to view post',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else if (type == 'comment') ...[
              const SizedBox(height: 12),
              // Only show "View Comments" button for grouped notifications
              if (message.contains('others') || message.contains('other'))
                InkWell(
                  onTap: postId != null ? () => viewCommenters(postId) : null,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.comment, color: Colors.red[700], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'View all comments',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // For single comments, show a simple indicator
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.comment, color: Colors.red[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to view post',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else if (type == 'repost') ...[
              const SizedBox(height: 12),
              // Only show "View Reposts" button for grouped notifications
              if (message.contains('others') || message.contains('other'))
                InkWell(
                  onTap: postId != null ? () => viewReposters(postId) : null,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.repeat, color: Colors.red[700], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'View all reposts',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // For single reposts, show a simple indicator
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.repeat, color: Colors.red[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to view post',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else if (type == 'reminder') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                 color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                     Icon(Icons.calendar_today, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Tap to view in calendar",
                        style: TextStyle(
                          color: Colors.red[700], 
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}