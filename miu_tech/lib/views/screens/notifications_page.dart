import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/friendship_provider.dart';


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

    // Fetch sender details for each notification
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
        } catch (e) {
          print('⚠️ Error fetching sender data: $e');
        }
      } else {
        print('⚠️ Notification has null from_user_id: ${notification}');
      }
    }

    setState(() {
      notifications = data;
      loading = false;
    });
    
    print('✅ Total notifications loaded: ${notifications.length}');
    print('✅ Follow request notifications: ${notifications.where((n) => n['type'] == 'follow_request').length}');
  } catch (e) {
    print('❌ Error fetching notifications: $e');
    print('Stack trace: ${StackTrace.current}');
    setState(() {
      loading = false;
    });
  }
}

String formatTime(String? time) { // ✅ Make parameter nullable
  if (time == null) return 'Just now';
  
  try {
    final date = DateTime.parse(time);
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 60) return "${diff.inMinutes} minutes ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    return "${diff.inDays} days ago";
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
              ? const Center(child: Text("No notifications"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  itemCount: notifications.length,
itemBuilder: (context, index) {
  final n = notifications[index];

  return _buildNotificationItem(
    title: n['title'] ?? 'Notification',
    message: n['body'] ?? '',
    time: n['created_at'] != null 
        ? formatTime(n['created_at']) 
        : 'Just now',
    isRead: n['is_read'] ?? false,
    type: n['type'],
    fromUserId: n['from_user_id'],
    index: index,
    profileUrl: null,
  );
},
                ),
    );
  }

Widget _buildNotificationItem({
  required String title,
  required String message,
  required String time,
  required bool isRead,
  String? type,
  int? fromUserId,
  required int index,
  String? profileUrl,
}) {
  final senderData = notifications[index]['sender_data'];
  final String senderName = senderData != null ? (senderData['name'] ?? 'Unknown') : 'Unknown';
  final String? senderProfileImage = senderData != null ? senderData['profile_image'] : null;
  final String? senderRole = senderData != null ? senderData['role'] : null;
  final String? senderDept = senderData != null ? senderData['department'] : null;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isRead ? Colors.white : const Color(0xFFF0F0F0),
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
            // CircleAvatar for user image
           CircleAvatar(
            radius: 24,
            backgroundImage: senderProfileImage != null && senderProfileImage.isNotEmpty
           ? NetworkImage(senderProfileImage)
          : null,
           backgroundColor: Colors.red[700],
           child: senderProfileImage == null || senderProfileImage.isEmpty
          ? Text(
           senderName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
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
  senderName,
  style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
),
if (senderRole != null) ...[
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
                  Text(message),
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
        
        if (type == 'follow_request') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
  if (fromUserId == null) return;
  await acceptFollow(fromUserId, senderName);
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
        ],
      ],
    ),
  );
}

}