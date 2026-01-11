import 'package:flutter/material.dart';
import '../screens/AddPostScreen.dart';
import '../screens/My_Profile.dart';
import '../screens/messaging_page.dart';
import '../screens/notifications_page.dart';
import '../screens/calender_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/message_provider.dart';

class BottomNavbar extends StatelessWidget {
  final int? currentUserId;
  final int currentIndex;

  const BottomNavbar({
    super.key,
    this.currentUserId,
    this.currentIndex = 0,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0: // HOME
        if (currentIndex != 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        break;

      case 1: // CHAT
        if (currentUserId != null) {
          // ✅ NEW: Reload unread count before navigating to chat
          final messageProvider = Provider.of<MessageProvider>(context, listen: false);
          messageProvider.loadUnreadCount(currentUserId!);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatsListPage(currentUserId: currentUserId!),
            ),
          ).then((_) {
            // ✅ NEW: Reload count when returning from chat page
            messageProvider.loadUnreadCount(currentUserId!);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to access chat')),
          );
        }
        break;

      case 2: // NOTIFICATIONS
        if (currentUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: currentUserId!),
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
    // ✅ NEW: Initialize MessageProvider when navbar is built
    if (currentUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messageProvider = Provider.of<MessageProvider>(context, listen: false);
        if (!messageProvider.isInitialized) {
          messageProvider.initialize(currentUserId!);
        }
      });
    }

    return SizedBox(
      height: 85,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
                Expanded(
                  child: _NavItem(
                    icon: Icons.home,
                    label: "Home",
                    selected: currentIndex == 0,
                    onTap: () => _onItemTapped(context, 0),
                  ),
                ),
                
                // ✅ CHAT WITH DYNAMIC UNREAD BADGE
                Expanded(
                  child: Consumer<MessageProvider>(
                    builder: (context, messageProvider, child) {
                      // ✅ Get the actual unread count from provider
                      final unreadCount = messageProvider.unreadCount;
                      
                      return _NavItemWithBadge(
                        icon: Icons.chat,
                        label: "Chat",
                        selected: currentIndex == 1,
                        badgeCount: unreadCount, // ✅ Use dynamic count
                        onTap: () => _onItemTapped(context, 1),
                      );
                    },
                  ),
                ),
                
                const SizedBox(width: 55),
                
                Expanded(
                  child: _NavItem(
                    icon: Icons.notifications,
                    label: "Notifications",
                    selected: currentIndex == 2,
                    onTap: () => _onItemTapped(context, 2),
                  ),
                ),
                
                Expanded(
                  child: _NavItem(
                    icon: Icons.person,
                    label: "Profile",
                    selected: currentIndex == 3,
                    onTap: () => _onItemTapped(context, 3),
                  ),
                ),
              ],
            ),
          ),
          
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
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback? onTap;

  const _NavItemWithBadge({
    required this.icon,
    required this.label,
    this.selected = false,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: selected ? Colors.red : Colors.grey,
                  ),
                  
                  // ✅ ONLY SHOW BADGE IF COUNT > 0
                  if (badgeCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.red : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}