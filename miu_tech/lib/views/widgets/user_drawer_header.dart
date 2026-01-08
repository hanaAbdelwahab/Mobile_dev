import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/calender_screen.dart';
import '../screens/SavedPostsPage.dart'; // ✅ Add this import

class UserDrawerContent extends StatefulWidget {
  final int userId;

  const UserDrawerContent({
    super.key,
    required this.userId,
  });

  @override
  State<UserDrawerContent> createState() => _UserDrawerContentState();
}

class _UserDrawerContentState extends State<UserDrawerContent> {
  String? fullName;
  String? role;
  String? location;
  String? imageUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;

      final userData = await supabase
          .from('users')
          .select('name, role, location, profile_image')
          .eq('user_id', widget.userId)
          .single();

      setState(() {
        fullName = userData['name'];
        role = userData['role'];
        location = userData['location'];
        imageUrl = userData['profile_image'];
        isLoading = false;
      });
    } catch (e) {
      print("Error loading drawer user data: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ========= USER HEADER =========
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            (imageUrl != null && imageUrl!.isNotEmpty)
                                ? NetworkImage(imageUrl!)
                                : null,
                        child: (imageUrl == null || imageUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 35)
                            : null,
                      ),
                      const SizedBox(width: 15),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName ?? "Unknown User",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "$role student",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                            Text(
                              location ?? "",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),

                  // ========= DRAWER MENU ITEMS =========
                  ListTile(
                    leading: const Icon(Icons.bookmark),
                    title: const Text("Saved Posts"),
                    onTap: () {
                      Navigator.pop(context); // ✅ Close the drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SavedPostsPage(currentUserId: widget.userId), // ✅ Navigate to saved posts
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text("Calendar"),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CalendarScreen(userId: widget.userId),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Settings"),
                    onTap: () {},
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        "Log Out",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }
}