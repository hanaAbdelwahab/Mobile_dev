import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'manage_users_page.dart';
import 'manage_posts_by_category_page.dart';
import 'manage_announcements_page.dart';  // ✅ Announcement table
import 'manage_freelancing_page.dart';
import 'manage_feedback_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalFreelanceProjects = 0;
  int _totalAnnouncements = 0;
  int _pendingFeedback = 0;
  int _pendingReports = 0;
  int _unreadNotifications = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Users count
      int usersCount = 0;
      try {
        final usersData = await Supabase.instance.client
            .from('users')
            .select('user_id');
        usersCount = (usersData as List).length;
        debugPrint('✅ Users count: $usersCount');
      } catch (e) {
        debugPrint('❌ Error counting users: $e');
      }

      // Posts count
      int postsCount = 0;
      try {
        final postsData = await Supabase.instance.client
            .from('posts')
            .select('post_id');
        postsCount = (postsData as List).length;
        debugPrint('✅ Posts count: $postsCount');
      } catch (e) {
        debugPrint('❌ Error counting posts: $e');
      }

      // Events count
      // Announcements count
int announcementsCount = 0;
try {
  final announcementsData = await Supabase.instance.client
      .from('announcement') // ✅ your announcements table
      .select('ann_id');
  announcementsCount = (announcementsData as List).length;
  debugPrint('✅ Announcements count: $announcementsCount');
} catch (e) {
  debugPrint('❌ Error counting announcements: $e');
}


      // Freelance projects count
      int freelanceCount = 0;
      try {
        final freelanceData = await Supabase.instance.client
            .from('freelance_projects')
            .select('project_id');
        freelanceCount = (freelanceData as List).length;
        debugPrint('✅ Freelance count: $freelanceCount');
      } catch (e) {
        debugPrint('❌ Error counting freelance projects: $e');
      }

      // Count pending feedback
      int feedbackCount = 0;
      try {
        final feedbackData = await Supabase.instance.client
            .from('feedback')
            .select('feedback_id')
            .eq('status', 'pending');
        feedbackCount = (feedbackData as List).length;
        debugPrint('✅ Pending feedback count: $feedbackCount');
      } catch (e) {
        debugPrint('❌ Error counting feedback: $e');
      }

      // Count pending reports
      int reportsCount = 0;
      try {
        final reportsData = await Supabase.instance.client
            .from('problem_reports')
            .select('report_id')
            .eq('status', 'pending');
        reportsCount = (reportsData as List).length;
        debugPrint('✅ Pending reports count: $reportsCount');
      } catch (e) {
        debugPrint('❌ Error counting reports: $e');
      }

      // Count unread notifications
      int notificationsCount = 0;
      try {
        final notificationsData = await Supabase.instance.client
            .from('admin_notifications')
            .select('notification_id')
            .eq('is_read', false);
        notificationsCount = (notificationsData as List).length;
        debugPrint('✅ Unread notifications count: $notificationsCount');
      } catch (e) {
        debugPrint('❌ Error counting notifications: $e');
      }

      setState(() {
        _totalUsers = usersCount;
        _totalPosts = postsCount;
        _totalFreelanceProjects = freelanceCount;
        _totalAnnouncements = announcementsCount;
        _pendingFeedback = feedbackCount;
        _pendingReports = reportsCount;
        _unreadNotifications = notificationsCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading stats: $e');
      setState(() {
        _errorMessage = 'Failed to load statistics';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Notifications badge
          if (_unreadNotifications > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageFeedbackPage(),
                      ),
                    );
                    _loadStats();
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotifications > 99 
                          ? '99+' 
                          : _unreadNotifications.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'Logout',
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
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Alerts Section (if there are pending items)
                    if (_pendingFeedback > 0 || _pendingReports > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange[400]!, Colors.orange[600]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pending Review',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_pendingFeedback feedback • $_pendingReports reports',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ManageFeedbackPage(),
                                  ),
                                );
                                _loadStats();
                              },
                              icon: const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Users',
                            _totalUsers.toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Posts',
                            _totalPosts.toString(),
                            Icons.article,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Freelance',
                            _totalFreelanceProjects.toString(),
                            Icons.work,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                       Expanded(
  child: _buildStatCard(
    'Announcements',
    _totalAnnouncements.toString(),
    Icons.campaign,
    Colors.purple,
  ),
),
],
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      'Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Feedback & Reports Management (placed first for priority)
                    _buildManagementOption(
                      'Feedback & Reports',
                      '$_pendingFeedback pending feedback • $_pendingReports pending reports',
                      Icons.feedback_outlined,
                      Colors.amber,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageFeedbackPage(),
                          ),
                        );
                        _loadStats();
                      },
                      badge: _pendingFeedback + _pendingReports,
                    ),
                    const SizedBox(height: 12),

                    _buildManagementOption(
                      'Manage Users',
                      'View and manage all registered users',
                      Icons.people_outline,
                      Colors.blue,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageUsersPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    _buildManagementOption(
                      'Manage Posts by Category',
                      'View and moderate posts organized by category',
                      Icons.article_outlined,
                      Colors.green,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManagePostsByCategoryPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    _buildManagementOption(
                      'Manage Freelancing Hub',
                      'Post projects and view applications',
                      Icons.work_outline,
                      Colors.red,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageFreelancingPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    _buildManagementOption(
                      'Manage Announcements',
                      'Schedule and manage events & announcements',
                      Icons.campaign_outlined,
                      Colors.purple,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageAnnouncementsPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Future<void> Function() onTap, {
    int? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: badge != null && badge > 0 
                ? Colors.orange[300]! 
                : Colors.grey[200]!,
            width: badge != null && badge > 0 ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                if (badge != null && badge > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      child: Text(
                        badge > 99 ? '99+' : badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }
}