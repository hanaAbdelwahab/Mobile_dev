import 'package:flutter/material.dart';
import '../screens/AddPostScreen.dart';
import '../screens/My_Profile.dart';
import '../screens/messaging_page.dart';
import '../screens/notifications_page.dart';
import '../screens/calender_screen.dart';

class BottomNavbar extends StatelessWidget {
  final int? currentUserId;
  final int currentIndex;

  const BottomNavbar({
    super.key,
    this.currentUserId,
    this.currentIndex = 0,
  });

  void _onItemTapped(BuildContext context, int index) {
    // Don't navigate if already on that page
    if (index == currentIndex) return;

    // Handle navigation based on index
    switch (index) {
      case 0: // HOME
        if (currentIndex != 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        break;

      case 1: // CHAT
        if (currentUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatsListPage(currentUserId: currentUserId!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to access chat')),
          );
        }
        break;

      case 2: // NOTIFICATIONS (or CALENDAR depending on your needs)
        if (currentUserId != null) {
          // You can choose between NotificationsPage or CalendarScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: currentUserId!),
              // Or use: builder: (_) => CalendarScreen(userId: currentUserId!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to access notifications')),
          );
        }
        break;

      case 3: // PROFILE
        if (currentUserId != null) {
          if (currentIndex != 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyProfile(userId: currentUserId!),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to access profile')),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 85,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bottom Navigation Bar Container
          Container(
            height: 75,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // HOME
                _NavItem(
                  icon: Icons.home,
                  label: "Home",
                  selected: currentIndex == 0,
                  onTap: () => _onItemTapped(context, 0),
                ),
                
                // CHAT
                _NavItem(
                  icon: Icons.chat,
                  label: "Chat",
                  selected: currentIndex == 1,
                  onTap: () => _onItemTapped(context, 1),
                ),
                
                // Empty space for floating button
                const SizedBox(width: 55),
                
                // NOTIFICATIONS
                _NavItem(
                  icon: Icons.notifications,
                  label: "Notifications",
                  selected: currentIndex == 2,
                  onTap: () => _onItemTapped(context, 2),
                ),
                
                // PROFILE
                _NavItem(
                  icon: Icons.person,
                  label: "Profile",
                  selected: currentIndex == 3,
                  onTap: () => _onItemTapped(context, 3),
                ),
              ],
            ),
          ),
          
          // Floating Add Button
          Positioned(
            top: -20,
            left: 0,
            right: 25,
            child: Center(
              child: Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    // Navigate to Add Post Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPostScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 36,
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

// ============================================================
// Bottom Nav Item Widget
// ============================================================
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: selected ? Colors.red : Colors.grey,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}