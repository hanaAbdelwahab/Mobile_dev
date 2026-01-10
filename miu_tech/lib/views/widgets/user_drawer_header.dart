import 'package:flutter/material.dart';
import '../screens/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/calender_screen.dart';
import '../screens/SavedPostsPage.dart'; // ✅ Add this import
import '../screens/saved_freelance_projects_page.dart'; 
import '../screens/settings_page.dart'; // Add this line
// Add this import
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

                  
                ListTile(// ========= DRAWER MENU ITEMS =========
                 leading: const Icon(Icons.bookmark, color: Colors.red),
                    title: const Text("Saved Posts"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SavedPostsPage(currentUserId: widget.userId),
                        ),
                      );
                    },
                  ),
                  
                  ListTile(
                    leading: const Icon(Icons.work, color: Colors.orange),
                    title: const Text("Saved Projects"),
                    subtitle: const Text(
                      "Freelancing opportunities",
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SavedFreelanceProjectsPage(),
                        ),
                      );
                    },
                  ),
                  
                  const Divider(),
                  
                  ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.blue),
                    title: const Text("Calendar"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CalendarScreen(userId: widget.userId),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.settings, color: Colors.grey),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsPage(userId: widget.userId),
                        ),
                      );
                    },
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Show confirmation dialog
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Log Out'),
                            content: const Text('Are you sure you want to log out?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text(
  'Log Out',
  style: TextStyle(color: Colors.white),
),

                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          try {
                            await Supabase.instance.client.auth.signOut();
                            if (mounted) {
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error logging out: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
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