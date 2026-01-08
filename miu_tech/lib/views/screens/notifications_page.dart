import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/image_picker_helper.dart';
import '../../services/profile_image_service.dart';


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
    final data = await supabase
        .from('notifications')
        .select()
        .eq('user_id', widget.userId) // ✅ Filter by current user
        .order('created_at', ascending: false);
    print('Supabase notifications: $data');

    setState(() {
      notifications = data;
      loading = false;
    });
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

  Future<void> acceptFollow(String actorId) async {
    await supabase.from('followers').insert({
      'user_id': widget.userId, // ✅ Use widget.userId
      'follower_id': actorId,
    });

    await supabase.from('notifications')
        .update({'is_read': true})
        .eq('actor_id', actorId)
        .eq('user_id', widget.userId); // ✅ Use widget.userId
  }

  Future<void> rejectFollow(String actorId) async {
    await supabase.from('notifications')
        .update({'is_read': true})
        .eq('actor_id', actorId)
        .eq('user_id', widget.userId); // ✅ Use widget.userId
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
              ? const Center(child: Text("No notifications"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
  final n = notifications[index];

  return _buildNotificationItem(
    title: n['title'] ?? 'Notification', // ✅ Handle null
    message: n['message'] ?? '', // ✅ Handle null
    time: n['created_at'] != null 
        ? formatTime(n['created_at']) 
        : 'Just now', // ✅ Handle null
    isRead: n['is_read'] ?? false, // ✅ Handle null
    type: n['type'], // Can be null
    actorId: n['actor_id'], // Can be null
    index: index,
    profileUrl: n['profile_url'], // Can be null
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
    String? actorId,
    required int index,
    String? profileUrl,
  }) {
    String? status = notifications[index]['status']; // local status

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CircleAvatar for user image
          CircleAvatar(
            radius: 20,
            backgroundImage: profileUrl != null
                ? NetworkImage(profileUrl)
                : const AssetImage('assets/men1.jpg') as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 6),
                Text(message),
                const SizedBox(height: 8),
                Text(time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    )),
                if (type == 'follow_request') ...[
                  const SizedBox(height: 8),
                  if (status == null)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (actorId == null) return;
                              await acceptFollow(actorId);
                              setState(() {
                                notifications[index]['is_read'] = true;
                                notifications[index]['status'] = 'accepted';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Follow request accepted!")),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Accept"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              if (actorId == null) return;
                              await rejectFollow(actorId);
                              setState(() {
                                notifications[index]['is_read'] = true;
                                notifications[index]['status'] = 'rejected';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Follow request rejected")),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text("Reject"),
                          ),
                        ),
                      ],
                    )
                  else if (status == 'accepted')
                    const Text("✅ Accepted",
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                  else if (status == 'rejected')
                    const Text("❌ Rejected",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
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
    );
  }
}