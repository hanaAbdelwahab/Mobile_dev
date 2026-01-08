import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SendPostDialog extends StatefulWidget {
  final String postId;
  final String postContent;

  const SendPostDialog({
    super.key,
    required this.postId,
    required this.postContent,
  });

  @override
  State<SendPostDialog> createState() => _SendPostDialogState();
}

class _SendPostDialogState extends State<SendPostDialog> {
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  Set<String> selectedUserIds = {};
  bool loading = true;
  final TextEditingController searchController = TextEditingController();
  
  // Mock current user ID (same as in other files)
  final String mockCurrentUserId = "11111111-1111-1111-1111-111111111111";

  @override
  void initState() {
    super.initState();
    fetchUsers();
    searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchUsers() async {
    try {
      print('🔍 Fetching users for send dialog');
      
      final response = await supabase
          .from('users')
          .select('id, username, role')
          .neq('id', mockCurrentUserId) // Exclude current user
          .order('username', ascending: true);

      print('✅ Users fetched: ${(response as List).length}');

      setState(() {
        users = (response as List).map((user) {
          return {
            'id': user['id'],
            'username': user['username'] ?? 'Unknown',
            'role': user['role'] ?? 'No Role',
          };
        }).toList();
        filteredUsers = users;
        loading = false;
      });
    } catch (e) {
      print('❌ Error fetching users: $e');
      setState(() {
        users = [];
        filteredUsers = [];
        loading = false;
      });
    }
  }

  void _filterUsers() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredUsers = users;
      } else {
        filteredUsers = users.where((user) {
          final username = user['username'].toString().toLowerCase();
          final role = user['role'].toString().toLowerCase();
          return username.contains(query) || role.contains(query);
        }).toList();
      }
    });
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (selectedUserIds.contains(userId)) {
        selectedUserIds.remove(userId);
      } else {
        selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _sendToSelectedUsers() async {
    if (selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please select at least one recipient',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    try {
      print('📤 Sending post to ${selectedUserIds.length} users');
      
      // Insert shared posts into database
      final List<Map<String, dynamic>> shares = selectedUserIds.map((userId) {
        return {
          'post_id': widget.postId,
          'sender_id': mockCurrentUserId,
          'receiver_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await supabase.from('shared_posts').insert(shares);

      print('✅ Post sent successfully');

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedUserIds.length == 1
                        ? 'Post shared successfully'
                        : 'Post shared with ${selectedUserIds.length} recipients',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error sending post: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending post: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Send Post',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.black54,
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Post preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                widget.postContent.length > 100
                    ? '${widget.postContent.substring(0, 100)}...'
                    : widget.postContent,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            
            // Search bar
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            
            // Selected count
            if (selectedUserIds.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Text(
                      selectedUserIds.length == 1
                          ? '1 recipient selected'
                          : '${selectedUserIds.length} recipients selected',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            
            if (selectedUserIds.isNotEmpty) const SizedBox(height: 12),
            
            // Users list
            Expanded(
              child: loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Colors.red[700],
                      ),
                    )
                  : filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchController.text.isEmpty
                                    ? 'No users available'
                                    : 'No users found',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredUsers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final userId = user['id'];
                            final username = user['username'];
                            final role = user['role'];
                            final isSelected = selectedUserIds.contains(userId);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isSelected
                                        ? [Colors.red[700]!, Colors.red[500]!]
                                        : [Colors.grey[600]!, Colors.grey[500]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    username
                                        .split(' ')
                                        .map((e) => e.isNotEmpty ? e[0] : '')
                                        .take(2)
                                        .join()
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                role,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleUserSelection(userId),
                                activeColor: Colors.red[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onTap: () => _toggleUserSelection(userId),
                            );
                          },
                        ),
            ),
            
            const SizedBox(height: 16),
            
            // Send button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: selectedUserIds.isEmpty ? null : _sendToSelectedUsers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      selectedUserIds.isEmpty
                          ? 'Select Recipients'
                          : selectedUserIds.length == 1
                              ? 'Send Post'
                              : 'Send to ${selectedUserIds.length} Recipients',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}