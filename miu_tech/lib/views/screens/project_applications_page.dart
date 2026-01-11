import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/FreelanceProjectModel.dart';
import 'package:intl/intl.dart';
import '../../controllers/FreelancingHubController.dart';

class ProjectApplicationsPage extends StatefulWidget {
  final FreelanceProjectModel project;

  const ProjectApplicationsPage({super.key, required this.project});

  @override
  State<ProjectApplicationsPage> createState() =>
      _ProjectApplicationsPageState();
}

class _ProjectApplicationsPageState extends State<ProjectApplicationsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, bool> _recalculating =
      {}; // track per-application recalc state

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint(
        '📥 Loading applications for project: ${widget.project.projectId}',
      );

      // ✅ Use JOIN to get user data directly
      final applicationsData = await _supabase
          .from('freelance_applications')
          .select('''
            *,
            users!applicant_id (
              user_id,
              name,
              email,
              profile_image,
              role
            )
          ''')
          .eq('project_id', widget.project.projectId)
          .order('applied_at', ascending: false);

      debugPrint('✅ Found ${applicationsData.length} applications');

      List<Map<String, dynamic>> processedApplications = [];

      for (var app in applicationsData) {
        // Extract user data from JOIN
        final userData = app['users'];

        final String userName =
            userData?['name'] ??
            app['applicant_name'] ??
            app['applicant_email'] ??
            'Unknown User';

        final String? userEmail = userData?['email'] ?? app['applicant_email'];
        final String? userImage = userData?['profile_image'];
        final String? userRole = userData?['role'];
        // Fetch AI fields
        final double? matchScore = app['match_score'] != null
            ? (app['match_score'] as num).toDouble()
            : null;
        final String? aiFeedback = app['ai_feedback']?.toString();

        processedApplications.add({
          'application_id': app['application_id'],
          'project_id': app['project_id'],
          'applicant_id': app['applicant_id'],
          'introduction': app['introduction'],
          'status': app['status'],
          'applied_at': app['applied_at'],
          'user_name': userName,
          'user_email': userEmail,
          'user_image': userImage,
          'user_role': userRole,
          'match_score': matchScore,
          'ai_feedback': aiFeedback,
        });

        debugPrint('  ✅ Application: $userName ($userEmail)');
      }

      setState(() {
        _applications = processedApplications;
        _isLoading = false;
      });

      debugPrint(
        '✅ Loaded ${_applications.length} applications with user data',
      );
    } catch (e) {
      debugPrint('❌ Error loading applications: $e');
      setState(() {
        _errorMessage = 'Failed to load applications';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateApplicationStatus(
    int applicationId,
    String newStatus,
  ) async {
    try {
      await _supabase
          .from('freelance_applications')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('application_id', applicationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'accepted'
                  ? '✅ Application accepted'
                  : '❌ Application rejected',
            ),
            backgroundColor: newStatus == 'accepted'
                ? Colors.green
                : Colors.red,
          ),
        );
      }

      _loadApplications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _batchRecalculateAIScores() async {
    if (_applications.isEmpty) return;

    // 1. Confirmation Dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batch AI Analysis'),
        content: Text(
          'Recalculate scores for ${_applications.length} applications in "${widget.project.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Analysis'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int successCount = 0;
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _BatchProgressDialog(
          total: _applications.length,
          process: (updateProgress) async {
            // ====================================================
            // 🚀 FAST BATCH LOGIC (5 at a time)
            // ====================================================
            int batchSize = 5;

            // Notice: i increments by 5 (batchSize), not 1
            for (var i = 0; i < _applications.length; i += batchSize) {
              // 1. Grab the next 5 applications
              int end = (i + batchSize < _applications.length)
                  ? i + batchSize
                  : _applications.length;

              var currentBatch = _applications.sublist(i, end);

              // 2. Fire all 5 requests AT THE SAME TIME
              await Future.wait(
                currentBatch.map((app) async {
                  // Safety check inside the parallel loop
                  if (app['project_id'].toString() != widget.project.projectId)
                    return;

                  try {
                    final result =
                        await FreelancingHubController.recalculateApplicationScore(
                          app['application_id'].toString(),
                          app['project_id'].toString(),
                          (app['applicant_uuid'] ?? app['applicant_id'])
                              .toString(),
                          app['introduction'] ?? '',
                        );

                    if (result != null) {
                      app['match_score'] =
                          (result['score'] as num?)?.toDouble() ?? 0.0;
                      app['ai_feedback'] = result['feedback']?.toString() ?? '';
                      successCount++;
                    }
                  } catch (e) {
                    debugPrint('Error in batch item: $e');
                  }
                }),
              );

              // 3. Update progress only after the whole batch finishes
              updateProgress(end);

              // Tiny delay to prevent UI freezing between batches
              await Future.delayed(const Duration(milliseconds: 50));
            }
          },
        );
      },
    );

    if (mounted) {
      setState(() {}); // Refresh UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Updated $successCount/${_applications.length} applications.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleRecalculate(
    String applicationId,
    Map<String, dynamic> app,
  ) async {
    // mark busy
    setState(() {
      _recalculating[applicationId] = true;
    });

    try {
      final projectId = app['project_id'].toString();
      final applicantUuid = app['applicant_id'].toString();
      final introduction = app['introduction'] ?? '';

      final result = await FreelancingHubController.recalculateApplicationScore(
        applicationId,
        projectId,
        applicantUuid,
        introduction,
      );

      if (result != null) {
        // Update local list so UI reflects change immediately
        final index = _applications.indexWhere(
          (element) =>
              element['application_id'].toString() == applicationId.toString(),
        );
        if (index != -1) {
          setState(() {
            _applications[index]['match_score'] =
                (result['score'] as num?)?.toDouble() ??
                _applications[index]['match_score'];
            _applications[index]['ai_feedback'] =
                result['feedback']?.toString() ??
                _applications[index]['ai_feedback'];
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Score updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to recalculate: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _recalculating[applicationId] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Applications', style: TextStyle(fontSize: 18)),
            Text(
              widget.project.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Batch Recalculate AI Scores',
            onPressed: _batchRecalculateAIScores,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadApplications,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _applications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No applications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Applications will appear here when users apply',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadApplications,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _applications.length,
                itemBuilder: (context, index) {
                  final app = _applications[index];
                  return _buildApplicationCard(app);
                },
              ),
            ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final applicationId = application['application_id'].toString();
    final status = application['status'] as String;
    final userName = application['user_name'] as String;
    final userEmail = application['user_email'] as String?;
    final userImage = application['user_image'] as String?;
    final userRole = application['user_role'] as String?;
    final introduction = application['introduction'] as String;
    final appliedAt = DateTime.parse(application['applied_at']);
    final double? matchScore = application['match_score'] as double?;
    final String? aiFeedback = application['ai_feedback'] as String?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.redAccent[100],
                  backgroundImage: userImage != null
                      ? NetworkImage(userImage)
                      : null,
                  child: userImage == null
                      ? Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
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
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (userEmail != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (userRole != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            userRole,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Introduction',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  introduction,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                if (matchScore != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'AI Match Score: ${matchScore.toStringAsFixed(2)} / 5.0',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
                if (aiFeedback != null && aiFeedback.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          aiFeedback,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Applied ${_timeAgo(appliedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: (_recalculating[applicationId] == true)
                        ? null
                        : () => _handleRecalculate(applicationId, application),
                    icon: (_recalculating[applicationId] == true)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(
                      (_recalculating[applicationId] == true)
                          ? 'Analyzing...'
                          : 'Recalculate AI Score',
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (status == 'pending')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateApplicationStatus(
                        application['application_id'],
                        'rejected',
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateApplicationStatus(
                        application['application_id'],
                        'accepted',
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

class _BatchProgressDialog extends StatefulWidget {
  final int total;
  final Future<void> Function(void Function(int)) process;
  const _BatchProgressDialog({required this.total, required this.process});
  @override
  State<_BatchProgressDialog> createState() => _BatchProgressDialogState();
}

class _BatchProgressDialogState extends State<_BatchProgressDialog> {
  int _current = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.process((progress) {
        setState(() {
          _current = progress;
        });
      });
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    double progress = widget.total == 0 ? 0 : _current / widget.total;
    return AlertDialog(
      title: const Text('Batch AI Analysis Progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Recalculating AI scores for all applications...'),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text('Processed $_current of ${widget.total}'),
        ],
      ),
    );
  }
}
