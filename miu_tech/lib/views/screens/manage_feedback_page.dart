import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageFeedbackPage extends StatefulWidget {
  const ManageFeedbackPage({Key? key}) : super(key: key);

  @override
  State<ManageFeedbackPage> createState() => _ManageFeedbackPageState();
}

class _ManageFeedbackPageState extends State<ManageFeedbackPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> feedbackList = [];
  List<Map<String, dynamic>> reportsList = [];
  List<Map<String, dynamic>> notificationsList = [];
  
  bool isLoading = true;
  String selectedFeedbackFilter = 'all'; // all, pending, reviewed, resolved
  String selectedReportFilter = 'all'; // all, pending, investigating, resolved

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _loadFeedback(),
      _loadReports(),
      _loadNotifications(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> _loadFeedback() async {
    try {
      // Build query based on filter
      PostgrestFilterBuilder query;
      
      if (selectedFeedbackFilter == 'all') {
        query = supabase
            .from('feedback')
            .select('''
              *,
              users:user_id(user_id, name, email, role)
            ''');
      } else {
        query = supabase
            .from('feedback')
            .select('''
              *,
              users:user_id(user_id, name, email, role)
            ''')
            .eq('status', selectedFeedbackFilter);
      }

      final data = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          feedbackList = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Error loading feedback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feedback: $e')),
        );
      }
    }
  }

  Future<void> _loadReports() async {
    try {
      // Build query based on filter
      PostgrestFilterBuilder query;
      
      if (selectedReportFilter == 'all') {
        query = supabase
            .from('problem_reports')
            .select('''
              *,
              users:user_id(user_id, name, email, role)
            ''');
      } else {
        query = supabase
            .from('problem_reports')
            .select('''
              *,
              users:user_id(user_id, name, email, role)
            ''')
            .eq('status', selectedReportFilter);
      }

      final data = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          reportsList = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Error loading reports: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await supabase
          .from('admin_notifications')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);
      
      if (mounted) {
        setState(() {
          notificationsList = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  Future<void> _updateFeedbackStatus(int feedbackId, String status) async {
    try {
      await supabase.from('feedback').update({
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('feedback_id', feedbackId);

      await _loadFeedback();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback status updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateReportStatus(
    int reportId,
    String status, {
    String? priority,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
      };
      
      if (priority != null) {
        updates['priority'] = priority;
      }

      await supabase
          .from('problem_reports')
          .update(updates)
          .eq('report_id', reportId);

      await _loadReports();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report status updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markNotificationRead(int notificationId) async {
    try {
      await supabase.from('admin_notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('notification_id', notificationId);

      await _loadNotifications();
    } catch (e) {
      print('Error marking notification read: $e');
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('MMM d, y • h:mm a').format(dt);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
      case 'investigating':
        return Colors.blue;
      case 'resolved':
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Feedback & Reports'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Feedback (${feedbackList.length})',
              icon: const Icon(Icons.feedback_outlined, size: 20),
            ),
            Tab(
              text: 'Reports (${reportsList.length})',
              icon: const Icon(Icons.bug_report_outlined, size: 20),
            ),
            Tab(
              text: 'Notifications (${notificationsList.where((n) => n['is_read'] == false).length})',
              icon: const Icon(Icons.notifications_outlined, size: 20),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFeedbackTab(),
                _buildReportsTab(),
                _buildNotificationsTab(),
              ],
            ),
    );
  }

  Widget _buildFeedbackTab() {
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', selectedFeedbackFilter, (value) {
                  setState(() => selectedFeedbackFilter = value);
                  _loadFeedback();
                }),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Pending',
                  'pending',
                  selectedFeedbackFilter,
                  (value) {
                    setState(() => selectedFeedbackFilter = value);
                    _loadFeedback();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Reviewed',
                  'reviewed',
                  selectedFeedbackFilter,
                  (value) {
                    setState(() => selectedFeedbackFilter = value);
                    _loadFeedback();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Resolved',
                  'resolved',
                  selectedFeedbackFilter,
                  (value) {
                    setState(() => selectedFeedbackFilter = value);
                    _loadFeedback();
                  },
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: feedbackList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No feedback found',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFeedback,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: feedbackList.length,
                    itemBuilder: (context, index) {
                      final feedback = feedbackList[index];
                      return _buildFeedbackCard(feedback);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', selectedReportFilter, (value) {
                  setState(() => selectedReportFilter = value);
                  _loadReports();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending', selectedReportFilter, (value) {
                  setState(() => selectedReportFilter = value);
                  _loadReports();
                }),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Investigating',
                  'investigating',
                  selectedReportFilter,
                  (value) {
                    setState(() => selectedReportFilter = value);
                    _loadReports();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip('Resolved', 'resolved', selectedReportFilter, (value) {
                  setState(() => selectedReportFilter = value);
                  _loadReports();
                }),
              ],
            ),
          ),
        ),

        Expanded(
          child: reportsList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No reports found',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: reportsList.length,
                    itemBuilder: (context, index) {
                      final report = reportsList[index];
                      return _buildReportCard(report);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    return notificationsList.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notificationsList.length,
              itemBuilder: (context, index) {
                final notification = notificationsList[index];
                return _buildNotificationCard(notification);
              },
            ),
          );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    Function(String) onSelected,
  ) {
    final isSelected = selectedValue == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: Colors.red[100],
      checkmarkColor: Colors.red,
      labelStyle: TextStyle(
        color: isSelected ? Colors.red[800] : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final user = feedback['users'] ?? {};
    final status = feedback['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        user['email'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              feedback['content'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatDate(feedback['created_at']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                if (status == 'pending') ...[
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _updateFeedbackStatus(
                          feedback['feedback_id'],
                          'reviewed',
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Reviewed'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _updateFeedbackStatus(
                          feedback['feedback_id'],
                          'resolved',
                        ),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Resolve'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ] else if (status == 'reviewed') ...[
                  TextButton.icon(
                    onPressed: () => _updateFeedbackStatus(
                      feedback['feedback_id'],
                      'resolved',
                    ),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Resolve'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final user = report['users'] ?? {};
    final status = report['status'] ?? 'pending';
    final priority = report['priority'] ?? 'medium';
    final problemType = report['problem_type'] ?? 'Other';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.red[100],
                  child: Text(
                    user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              problemType,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(priority).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getPriorityColor(priority),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report['description'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(report['created_at']),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value.startsWith('status:')) {
                      final newStatus = value.replaceFirst('status:', '');
                      _updateReportStatus(report['report_id'], newStatus);
                    } else if (value.startsWith('priority:')) {
                      final newPriority = value.replaceFirst('priority:', '');
                      _updateReportStatus(
                        report['report_id'],
                        status,
                        priority: newPriority,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'status:investigating',
                      child: Text('Mark Investigating'),
                    ),
                    const PopupMenuItem(
                      value: 'status:resolved',
                      child: Text('Mark Resolved'),
                    ),
                    const PopupMenuItem(
                      value: 'status:closed',
                      child: Text('Close'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'priority:low',
                      child: Text('Priority: Low'),
                    ),
                    const PopupMenuItem(
                      value: 'priority:medium',
                      child: Text('Priority: Medium'),
                    ),
                    const PopupMenuItem(
                      value: 'priority:high',
                      child: Text('Priority: High'),
                    ),
                    const PopupMenuItem(
                      value: 'priority:critical',
                      child: Text('Priority: Critical'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Actions',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRead ? Colors.grey[300] : Colors.blue[100],
          child: Icon(
            type == 'feedback' ? Icons.feedback : Icons.bug_report,
            color: isRead ? Colors.grey[600] : Colors.blue[800],
          ),
        ),
        title: Text(
          notification['title'] ?? '',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message'] ?? ''),
            const SizedBox(height: 4),
            Text(
              _formatDate(notification['created_at']),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: !isRead
            ? IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => _markNotificationRead(
                  notification['notification_id'],
                ),
                tooltip: 'Mark as read',
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}