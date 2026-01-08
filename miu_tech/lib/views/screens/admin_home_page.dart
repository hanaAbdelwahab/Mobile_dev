import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'manage_users_page.dart';
import 'manage_posts_page.dart';
import 'manage_projects_page.dart';
import 'manage_events_page.dart';
import 'manage_opportunities_page.dart';
import 'admin_reports_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalProjects = 0;
  int _totalEvents = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Get users count
      final usersResponse = await Supabase.instance.client
          .from('users')
          .select('*')
          .count();

      setState(() {
        _totalUsers = usersResponse.count ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _isLoading = false);
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
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats Cards
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
                            'Projects',
                            _totalProjects.toString(),
                            Icons.work,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Events',
                            _totalEvents.toString(),
                            Icons.event,
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

                    // Management Options
                    _buildManagementOption(
                      'Manage Users',
                      'View and manage all registered users',
                      Icons.people_outline,
                      Colors.blue,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageUsersPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Manage Posts',
                      'Moderate and manage user posts',
                      Icons.article_outlined,
                      Colors.green,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManagePostsPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Manage Projects',
                      'Oversee graduation projects',
                      Icons.work_outline,
                      Colors.orange,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageProjectsPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Manage Events',
                      'Create and manage events',
                      Icons.event_outlined,
                      Colors.purple,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageEventsPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Manage Opportunities',
                      'Job and internship postings',
                      Icons.business_center_outlined,
                      Colors.teal,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageOpportunitiesPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Admin Reports',
                      'View analytics and reports',
                      Icons.assessment_outlined,
                      Colors.red,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminReportsPage(),
                        ),
                      ),
                    ),
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
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
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