import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../controllers/FreelancingHubController.dart';

enum SortOption { date, score }

class ManageApplicationsPage extends StatefulWidget {
  const ManageApplicationsPage({super.key});

  @override
  State<ManageApplicationsPage> createState() => _ManageApplicationsPageState();
}

class _ManageApplicationsPageState extends State<ManageApplicationsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String? _errorMessage;
  SortOption _currentSort = SortOption.date;
  final Map<String, bool> _recalculatingApps = {};

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
      final applicationsData = await _supabase
          .from('freelance_applications')
          .select(
            'application_id, project_id, applicant_id, applicant_uuid, applicant_email, applicant_name, introduction, status, applied_at, match_score, ai_feedback',
          )
          .order(
            _currentSort == SortOption.score ? 'match_score' : 'applied_at',
            ascending: false,
          );

      debugPrint('✅ Found ${(applicationsData as List).length} applications');

      List<Map<String, dynamic>> processedApplications = [];

      for (var app in applicationsData) {
        debugPrint('📊 Processing application: ${app['application_id']}');
        debugPrint('📧 Applicant email from DB: ${app['applicant_email']}');
        debugPrint('👤 Applicant name from DB: ${app['applicant_name']}');
        
        try {
          // Fetch project details
          final projectData = await _supabase
              .from('freelance_projects')
              .select('title, company_name, company_logo, skills_needed')
              .eq('project_id', app['project_id'])
              .maybeSingle();

          // AI Feature: Calculate Score
          double aiScore = 0.0;
          String aiFeedback = '';

          // Prefer saved DB score if available
          if (app['match_score'] != null) {
            aiScore = (app['match_score'] as num).toDouble();
            aiFeedback = app['ai_feedback'] ?? '';
          } else if (projectData != null &&
              projectData['skills_needed'] != null) {
            // Fallback to local calculation
            final skillsNeeded = List<String>.from(
              projectData['skills_needed'],
            );
            // Use the numeric ID (applicant_id) not UUID for checking skills table
            final numericId = app['applicant_id']?.toString() ?? '0';
            aiScore =
                await FreelancingHubController.calculateSkillMatchScoreWithoutAI(
                  numericId,
                  skillsNeeded,
                );
          }

          // Fetch user email from the application itself (stored during submission)
          String userEmail = app['applicant_email'] ?? 'Unknown Email';
          String userName = app['applicant_name'] ?? 'Unknown User';
          final applicantUuid = app['applicant_uuid'];

          // If email/name not stored, try to look it up
          if (userEmail == 'Unknown Email' && applicantUuid != null) {
            try {
              final userData = await _supabase
                  .from('users')
                  .select('email, full_name')
                  .eq('user_id', applicantUuid)
                  .maybeSingle();

              if (userData != null) {
                userEmail = userData['email'] ?? userEmail;
                userName = userData['full_name'] ?? userName;
              }
            } catch (e) {
              debugPrint('⚠️ Error fetching user data: $e');
            }
          }

          processedApplications.add({
            'application_id': app['application_id'],
            'project_id': app['project_id'],
            'applicant_id':
                applicantUuid ?? app['applicant_id']?.toString() ?? 'Unknown',
            'applicant_email': userEmail,
            'applicant_name': userName,
            'introduction': app['introduction'],
            'status': app['status'],
            'applied_at': app['applied_at'],
            'project_title': projectData?['title'] ?? 'Unknown Project',
            'company_name': projectData?['company_name'] ?? 'Unknown Company',
            'company_logo': projectData?['company_logo'],
            'ai_score': aiScore,
            'ai_feedback': aiFeedback,
          });
        } catch (e) {
          debugPrint('⚠️ Error loading project for application: $e');
          processedApplications.add({
            'application_id': app['application_id'],
            'project_id': app['project_id'],
            'applicant_id':
                app['applicant_uuid'] ??
                app['applicant_id']?.toString() ??
                'Unknown',
            'applicant_email': 'Unknown Email',
            'applicant_name': 'Unknown User',
            'introduction': app['introduction'],
            'status': app['status'],
            'applied_at': app['applied_at'],
            'project_title': 'Unknown Project',
            'company_name': 'Unknown Company',
            'company_logo': null,
            'ai_score': 0.0,
            'ai_feedback': '',
          });
        }
      }

      setState(() {
        _applications = processedApplications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      debugPrint('❌ Error loading applications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('View Applications'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (SortOption result) {
              setState(() {
                _currentSort = result;
              });
              _loadApplications();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(
                value: SortOption.date,
                child: Text('Sort by Date'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.score,
                child: Text('Sort by AI Score'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More Actions',
            onSelected: (String value) {
              if (value == 'batch_analyze') {
                _runBatchAnalysis();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'batch_analyze',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Analyze All Pending'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading applications',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadApplications,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _applications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No applications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
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

  Future<void> _runBatchAnalysis() async {
    // 1. Identify candidates: Pending AND (Score is 0 OR Score > 5 i.e. legacy)
    final candidates = _applications.where((app) {
      final status = app['status']?.toString().toLowerCase() ?? 'pending';
      final score = (app['ai_score'] as num?)?.toDouble() ?? 0.0;
      return status == 'pending' && (score == 0 || score > 5.0);
    }).toList();

    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pending applications need analysis'),
          ),
        );
      }
      return;
    }

    // 2. Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batch Analysis'),
        content: Text(
          'Found ${candidates.length} applications to analyze.\n'
          'This uses OpenAI and may take a moment.\n\n'
          'Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // 3. Process loop with Progress Dialog
    ValueNotifier<int> progressNotifier = ValueNotifier(0);
    int total = candidates.length;

    // Show persistent progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: ValueListenableBuilder<int>(
          valueListenable: progressNotifier,
          builder: (ctx, val, _) => AlertDialog(
            title: const Text('Analyzing...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: total > 0 ? val / total : 0,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                ),
                const SizedBox(height: 16),
                Text(
                  'Processing $val of $total',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Do not close the app',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    int completed = 0;

    // Process in chunks of 5 to allow parallelism without hitting rate limits instantly
    const int batchSize = 5;
    for (var i = 0; i < candidates.length; i += batchSize) {
      if (!mounted) break;

      final end = (i + batchSize < candidates.length)
          ? i + batchSize
          : candidates.length;
      final batch = candidates.sublist(i, end);

      // Run this batch in parallel
      await Future.wait(
        batch.map((app) async {
          if (!mounted) return;
          final appId = app['application_id'] as String;

          try {
            final result =
                await FreelancingHubController.recalculateApplicationScore(
                  appId,
                  app['project_id'],
                  app['applicant_id'].toString(),
                  app['introduction'],
                );

            if (result != null) {
              // Update local list silently
              final index = _applications.indexWhere(
                (element) => element['application_id'] == appId,
              );
              if (index != -1) {
                _applications[index]['ai_score'] = result['score'];
                _applications[index]['ai_feedback'] = result['feedback'];
              }
            }
          } catch (e) {
            debugPrint('Batch error for $appId: $e');
          } finally {
            // Update progress
            completed++;
            if (mounted) {
              progressNotifier.value = completed;
            }
          }
        }),
      );
    }

    if (mounted) {
      Navigator.pop(context); // Close dialog
      setState(() {}); // Refresh UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch analysis completed for $completed applications'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleRecalculate(
    String appId,
    Map<String, dynamic> app,
  ) async {
    setState(() {
      _recalculatingApps[appId] = true;
    });

    try {
      final result = await FreelancingHubController.recalculateApplicationScore(
        appId,
        app['project_id'],
        app['applicant_id']
            .toString(), // Treating fallback ID as UUID string if needed
        app['introduction'],
      );

      if (result != null) {
        setState(() {
          // Update the local list directly so UI reflects change immediately
          final index = _applications.indexWhere(
            (element) => element['application_id'] == appId,
          );
          if (index != -1) {
            _applications[index]['ai_score'] = result['score'];
            _applications[index]['ai_feedback'] = result['feedback'];
          }
        });
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
      setState(() {
        _recalculatingApps[appId] = false;
      });
    }
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final applicationId = application['application_id'] as String;
    final status = application['status'] as String? ?? 'pending';
    final appliedAtStr = application['applied_at'] as String?;
    final introduction =
        application['introduction'] as String? ?? 'No introduction provided';
    final applicantId = application['applicant_id'] as String? ?? 'Unknown';
    final applicantEmail =
        application['applicant_email'] as String? ?? 'Unknown Email';
    final applicantName =
        application['applicant_name'] as String? ?? 'Unknown User';
    final projectTitle =
        application['project_title'] as String? ?? 'Unknown Project';
    final companyName =
        application['company_name'] as String? ?? 'Unknown Company';
    final companyLogo = application['company_logo'] as String?;
    final double aiScore = application['ai_score'] as double? ?? 0.0;
    final String? aiFeedback = application['ai_feedback'] as String?;

    DateTime appliedAt;
    try {
      appliedAt = appliedAtStr != null
          ? DateTime.parse(appliedAtStr)
          : DateTime.now();
    } catch (e) {
      appliedAt = DateTime.now();
    }

    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'withdrawn':
        statusColor = Colors.grey;
        statusIcon = Icons.remove_circle;
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
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: companyLogo != null && companyLogo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            companyLogo,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.business,
                                color: Colors.red,
                                size: 24,
                              );
                            },
                          ),
                        )
                      : const Icon(Icons.business, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        companyName,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                      Icon(statusIcon, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: Text(
                        applicantName.isNotEmpty
                            ? applicantName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicantName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            applicantEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Always show the score container, even if 0
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: aiScore >= 3.5
                                ? Colors.green.withOpacity(0.1)
                                : (aiScore >= 2.0
                                      ? Colors.orange.withOpacity(0.1)
                                      : (aiScore > 0
                                            ? Colors.red.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1))),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: aiScore >= 3.5
                                  ? Colors.green
                                  : (aiScore >= 2.0
                                        ? Colors.orange
                                        : (aiScore > 0
                                              ? Colors.red
                                              : Colors.grey)),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color: aiScore >= 3.5
                                    ? Colors.green
                                    : (aiScore >= 2.0
                                          ? Colors.orange
                                          : (aiScore > 0
                                                ? Colors.red
                                                : Colors.grey)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${aiScore.toStringAsFixed(1)} / 5.0',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: aiScore >= 3.5
                                      ? Colors.green
                                      : (aiScore >= 2.0
                                            ? Colors.orange
                                            : (aiScore > 0
                                                  ? Colors.red
                                                  : Colors.grey)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'AI Rating',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Applied ${_timeAgo(appliedAt)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Introduction:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    introduction,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
                if (aiFeedback != null && aiFeedback.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'AI Feedback:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Text(
                      aiFeedback,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[800],
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: (_recalculatingApps[applicationId] == true)
                        ? null
                        : () => _handleRecalculate(applicationId, application),
                    icon: (_recalculatingApps[applicationId] == true)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(
                      (_recalculatingApps[applicationId] == true)
                          ? 'Analyzing...'
                          : 'Recalculate Ai Score',
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
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
